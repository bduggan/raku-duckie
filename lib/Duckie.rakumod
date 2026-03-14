use Duckie::DuckDB::Native;
use Duckie::Result;
use Log::Async;
use NativeCall;

# ---------------------------------------------------------------------------
# User-defined function registry
#
# DuckDB callbacks are plain C function pointers; they cannot carry closure
# state.  We therefore keep a module-level registry of all registered
# functions and pass the registry index as the `extra_info` void* pointer.
# ---------------------------------------------------------------------------

class _TableFuncDef {
    has Str  $.name;
    has      @.columns;     # list of [col-name, type-str] pairs
    has      @.param-types; # list of type-name strings for SQL parameters
    has      &.function;    # user Raku callable: (*@params --> Iterable)
}

class _TableBindData {
    has Int  $.def-id;
    has      @.params;      # parameter values as strings
}

class _TableInitData {
    has Bool $.done    is rw = False;
    has      @.rows    is rw;
    has Int  $.offset  is rw = 0;
}

class _ScalarFuncDef {
    has Str  $.name;
    has      @.param-types; # list of type-name strings
    has Str  $.return-type;
    has      &.function;    # user Raku callable: (*@row-values --> Any)
}

my _TableFuncDef  @_tf_registry;
my _TableBindData @_tf_bind_data;
my _TableInitData @_tf_init_data;
my _ScalarFuncDef @_sf_registry;

# ---------------------------------------------------------------------------
# Type name ↔ DuckDB type-id helpers
# ---------------------------------------------------------------------------

sub _type-id(Str $name --> uint32) {
    given $name.uc {
        when 'VARCHAR' | 'TEXT' | 'STRING' { +DUCKDB_TYPE_VARCHAR }
        when 'INTEGER' | 'INT' | 'INT32'   { +DUCKDB_TYPE_INTEGER }
        when 'BIGINT'  | 'INT64'           { +DUCKDB_TYPE_BIGINT  }
        when 'DOUBLE'  | 'FLOAT8'          { +DUCKDB_TYPE_DOUBLE  }
        when 'FLOAT'   | 'FLOAT4'          { +DUCKDB_TYPE_FLOAT   }
        when 'BOOLEAN' | 'BOOL'            { +DUCKDB_TYPE_BOOLEAN }
        default                            { +DUCKDB_TYPE_VARCHAR }
    }
}

sub _make-logical-type(Str $name --> DuckDB::Native::LogicalType) {
    duckdb_create_logical_type(_type-id($name))
}

# ---------------------------------------------------------------------------
# Writing a single value into a DuckVector at row index $i
# ---------------------------------------------------------------------------

sub _write-vec(DuckDB::Native::DuckVector $vec, Int $i, Str $type, $val) {
    given $type.uc {
        when 'VARCHAR' | 'TEXT' | 'STRING' {
            duckdb_vector_assign_string_element($vec, $i, ~$val);
        }
        when 'INTEGER' | 'INT' | 'INT32' {
            my $arr = nativecast(CArray[int32], duckdb_vector_get_data($vec));
            $arr[$i] = $val.Int;
        }
        when 'BIGINT' | 'INT64' {
            my $arr = nativecast(CArray[int64], duckdb_vector_get_data($vec));
            $arr[$i] = $val.Int;
        }
        when 'DOUBLE' | 'FLOAT8' {
            my $arr = nativecast(CArray[num64], duckdb_vector_get_data($vec));
            $arr[$i] = $val.Num;
        }
        when 'FLOAT' | 'FLOAT4' {
            my $arr = nativecast(CArray[num32], duckdb_vector_get_data($vec));
            $arr[$i] = $val.Num;
        }
        when 'BOOLEAN' | 'BOOL' {
            my $arr = nativecast(CArray[uint8], duckdb_vector_get_data($vec));
            $arr[$i] = $val ?? 1 !! 0;
        }
    }
}

# ---------------------------------------------------------------------------
# Reading a single value from a DuckVector at row index $i.
# VARCHAR vectors use DuckDB's duckdb_string_t layout (16 bytes/element):
#   bytes 0-3  : uint32 length
#   if len ≤ 12: bytes 4-15 contain the inlined string
#   if len > 12: bytes 8-15 contain a char* pointer to the full string
# ---------------------------------------------------------------------------

sub _read-vec(DuckDB::Native::DuckVector $vec, Int $i, Str $type) {
    my $ptr = duckdb_vector_get_data($vec);
    given $type.uc {
        when 'VARCHAR' | 'TEXT' | 'STRING' {
            my $raw = nativecast(CArray[uint8], $ptr);
            my $off = $i * 16;
            my $len = $raw[$off]
                   +| ($raw[$off+1] +< 8)
                   +| ($raw[$off+2] +< 16)
                   +| ($raw[$off+3] +< 24);
            if $len <= 12 {
                Buf.new((^$len).map({ $raw[$off+4+$_] })).decode
            } else {
                # pointer stored little-endian in bytes 8-15
                my $pval = [+] (^8).map: { $raw[$off+8+$_].Int +< ($_ * 8) };
                my $sraw = nativecast(CArray[uint8], Pointer.new($pval));
                Buf.new((^$len).map({ $sraw[$_] })).decode
            }
        }
        when 'INTEGER' | 'INT' | 'INT32' {
            nativecast(CArray[int32], $ptr)[$i]
        }
        when 'BIGINT' | 'INT64' {
            nativecast(CArray[int64], $ptr)[$i]
        }
        when 'DOUBLE' | 'FLOAT8' {
            nativecast(CArray[num64], $ptr)[$i]
        }
        when 'FLOAT' | 'FLOAT4' {
            nativecast(CArray[num32], $ptr)[$i]
        }
        when 'BOOLEAN' | 'BOOL' {
            nativecast(CArray[uint8], $ptr)[$i] != 0
        }
        default {
            nativecast(CArray[int64], $ptr)[$i]
        }
    }
}

# ---------------------------------------------------------------------------
# Table function C callbacks (must not throw exceptions)
# ---------------------------------------------------------------------------

sub _tf-bind-cb(DuckDB::Native::BindInfo $info) {
    CATCH { default { note "Duckie table-func bind error: $_" } }
    my $def-id = +duckdb_bind_get_extra_info($info);
    my $def    = @_tf_registry[$def-id];

    for $def.columns -> [$col-name, $type-str] {
        my $lt = _make-logical-type($type-str);
        duckdb_bind_add_result_column($info, $col-name, $lt);
        duckdb_destroy_logical_type($lt);
    }

    my $nparams = duckdb_bind_get_parameter_count($info);
    my @params;
    for ^$nparams -> $i {
        my $v   = duckdb_bind_get_parameter($info, $i);
        my $str = duckdb_get_varchar($v);
        duckdb_destroy_value($v);
        @params.push($str);
    }

    @_tf_bind_data.push(_TableBindData.new(:$def-id, :@params));
    duckdb_bind_set_bind_data($info, Pointer.new(@_tf_bind_data.elems - 1), Pointer);
}

sub _tf-init-cb(DuckDB::Native::InitInfo $info) {
    CATCH { default { note "Duckie table-func init error: $_" } }
    my $bd-id = +duckdb_init_get_bind_data($info);
    my $bd    = @_tf_bind_data[$bd-id];
    my $def   = @_tf_registry[$bd.def-id];

    my @rows = $def.function.(|$bd.params).Array;

    @_tf_init_data.push(_TableInitData.new(:@rows));
    duckdb_init_set_init_data($info, Pointer.new(@_tf_init_data.elems - 1), Pointer);
}

sub _tf-func-cb(DuckDB::Native::FunctionInfo $info, DuckDB::Native::DataChunk $output) {
    CATCH { default { note "Duckie table-func exec error: $_"; duckdb_data_chunk_set_size($output, 0) } }
    my $id-id = +duckdb_function_get_init_data($info);
    my $state = @_tf_init_data[$id-id];

    if $state.done {
        duckdb_data_chunk_set_size($output, 0);
        return;
    }

    my $bd-id = +duckdb_function_get_bind_data($info);
    my $bd    = @_tf_bind_data[$bd-id];
    my $def   = @_tf_registry[$bd.def-id];

    my $vsz  = duckdb_vector_size();
    my $rem  = $state.rows.elems - $state.offset;
    my $take = $rem min $vsz;

    for ^$take -> $ri {
        my @row = @($state.rows[$state.offset + $ri]);
        for ^$def.columns.elems -> $ci {
            my $vec  = duckdb_data_chunk_get_vector($output, $ci);
            my $type = $def.columns[$ci][1];
            _write-vec($vec, $ri, $type, @row[$ci]);
        }
    }

    duckdb_data_chunk_set_size($output, $take);
    $state.offset += $take;
    $state.done    = True if $state.offset >= $state.rows.elems;
}

# ---------------------------------------------------------------------------
# Scalar function C callback
# ---------------------------------------------------------------------------

sub _sf-func-cb(DuckDB::Native::FunctionInfo $info,
                DuckDB::Native::DataChunk    $input,
                DuckDB::Native::DuckVector   $output) {
    CATCH { default { duckdb_scalar_function_set_error($info, ~$_) } }
    my $def-id = +duckdb_scalar_function_get_extra_info($info);
    my $def    = @_sf_registry[$def-id];

    my $nrows = duckdb_data_chunk_get_size($input);
    for ^$nrows -> $i {
        my @args = $def.param-types.kv.map: -> $ci, $t {
            _read-vec(duckdb_data_chunk_get_vector($input, $ci), $i, $t)
        };
        my $result = $def.function.(|@args);
        _write-vec($output, $i, $def.return-type, $result);
    }
}

# ---------------------------------------------------------------------------
# Duckie::PreparedStatement class
# ---------------------------------------------------------------------------

class Duckie::PreparedStatement {
  has DuckDB::Native::PreparedStatement $.stmt .= new;

  submethod DESTROY { duckdb_destroy_prepare($!stmt) }

  method !bind-value(Int $idx, $val) {
    my $rc = do given $val {
      when !.defined  { duckdb_bind_null($!stmt, $idx) }
      when Bool       { duckdb_bind_boolean($!stmt, $idx, $val ?? 1 !! 0) }
      when Int        { duckdb_bind_int64($!stmt, $idx, $val) }
      when Rat | Num  { duckdb_bind_double($!stmt, $idx, $val.Num) }
      when Str        { duckdb_bind_varchar($!stmt, $idx, $val) }
      when Blob       { duckdb_bind_blob($!stmt, $idx, CArray[uint8].new($val), $val.elems) }
      default         { duckdb_bind_varchar($!stmt, $idx, ~$val) }
    };
    fail "Failed to bind parameter at index $idx" unless $rc == DUCKDB_SUCCESS;
  }

  multi method execute(--> Duckie::Result) {
    my $res = DuckDB::Native::Result.new;
    unless duckdb_execute_prepared($!stmt, $res) == DUCKDB_SUCCESS {
      fail duckdb_result_error($res);
    }
    Duckie::Result.new(:$res);
  }

  multi method execute(*@params where @params > 0 --> Duckie::Result) {
    for @params.kv -> $i, $val {
      self!bind-value($i + 1, $val);
    }
    self.execute;
  }

  multi method execute(*%named where %named.keys > 0 --> Duckie::Result) {
    for %named.kv -> $name, $val {
      my uint64 $idx = 0;
      unless duckdb_bind_parameter_index($!stmt, $idx, $name) == DUCKDB_SUCCESS {
        fail "Unknown bind parameter: \$$name";
      }
      self!bind-value($idx, $val);
    }
    self.execute;
  }
}

# ---------------------------------------------------------------------------
# Duckie class
# ---------------------------------------------------------------------------

class Duckie {

=begin pod

=head1 NAME

Duckie - A wrapper and native bindings for DuckDB

=head1 SYNOPSIS

=begin code

use Duckie;
Duckie.new.query('select name from META6.json').rows[0]
# {name => Duckie}

my $db = Duckie.new;
say $db.query("select 1 as the_loneliest_number").column-data(0);
# [1]

with $db.query("select 1 as the_loneliest_number") -> $result {
  say $result.column-data('the_loneliest_number'); # [1]
} else {
  # Errors are soft failures
  say "Failed to run query: $_";
}

# DuckDB can query or import data from CSV or JSON files, HTTP URLs,
# PostgreSQL, MySQL, SQLite databases and more.
my @cols = $db.query('select * from data.csv').columns;
my @rows = $db.query('select * from data.json').rows;

$db.query: q[ attach 'postgres://secret:pw@localhost/dbname' as pg (type postgres)]
$res = $db.query: "select * from pg.my_table"

$db.query("install httpfs");
$db.query("load httpfs");
$res = $db.query: "select * from 'http://example.com/data.csv'";

# Joins between different types are also possible.
$res = $db.query: q:to/SQL/
select *
from pg.my_table one
inner join 'http://example.com/data.csv' csv_data on one.id = csv_data.id
inner join 'data.json' json_data on one.id = json_data.id
SQL

=end code

=head1 DESCRIPTION

This module provides Raku bindings for L<DuckDB|https://duckdb.org/>.  DuckDB is
a "fast in-process analytical database".  It provides an SQL interface for a variety
of data sources.  Result sets are column-oriented, with a rich set of types
that are either inferred, preserved, or explicitly defined.  C<Duckie> also
provides a row-oriented API.

This module provides two sets of classes.

=item C<Duckie::DuckDB::Native> is a low-level interface that directly
maps to the L<C API|https://duckdb.org/docs/api/c/api.html>.  Note that
a number of the function calls there are either deprecated or scheduled
for deprecation, so the implementation of the Raku interface favors the
more recent mechanisms where possible.

=item C<Duckie> provides a high level interface that handles things like
memory management and native typecasting.  While the Raku language
supports native types, the results from C<Duckie> do not currently expose them,
preferring, for instance to return Integers instead of uint8s, int64s, etc, and
using Rats for decimals, and Nums for floats.  A future interface may expose
native types.

=head1 INSTALLATION

Since Duckie depends on the C API, follow the instructions L<here|https://duckdb.org/docs/stable/clients/c/overview>
for installation of libduckdb before installing this module.  For instance, the "C/C++"
section of L<this page|https://duckdb.org/install/?environment=c> has a link
to a .zip file, which will need to be extracted and placed in a location
that is included in a standard locations, or one included in `DYLD_LIBRARY_PATH` for os/x,
or a similar `LD_LIBRARY_PATH` location for linux.

=head1 EXPORTS

If an argument to C<use Duckie> is provided, a new C<Duckie> object is
created and returned.  Also "-debug" will enable debug output.  e.g.

  use Duckie;                 # no exports
  use Duckie '$db';           # creates and exports "$db"
  use Duckie '$db', '-debug'; # creates and exports "$db" with debug output

=begin code

use Duckie 'db';
db.query("select 1 as the_loneliest_number").column-data(0);

=end code

=head1 METHODS

=head3 method new

=begin code

method new(
  :$file = ':memory:'
) returns Duckie

=end code

Create a new Duckie object.  The optional C<:file> parameter specifies the
path to a file to use as a database.  If not specified, an in-memory database
is used.  The database is opened and connected to when the object is created.

=end pod

logger.untapped-ok = True;

if %*ENV<DUCKIE_DEBUG> {
  logger.send-to($*ERR)
}

has $.logger = logger;
has DuckDB::Native::Database $.dbh .= new;
has DuckDB::Native::Connection $.conn .= new;
has Str $.file = ':memory:';
has Bool $!single-threaded = False;

submethod TWEAK {
  duckdb_open($!file, $!dbh) == +DUCKDB_SUCCESS or fail "Failed to open database $!file";
  duckdb_connect($!dbh, $!conn) == +DUCKDB_SUCCESS or fail "Failed to connect to database";
}

=begin pod

=head3 method query

=begin code

multi method query(Str $sql --> Duckie::Result)
multi method query(Str $sql, *@params --> Duckie::Result)
multi method query(Str $sql, *%named --> Duckie::Result)

=end code

Run a query and return a C<Duckie::Result>.  If the query fails, a soft failure is thrown.

Use C<?> as positional placeholders and C<$name> for named placeholders.

=begin code

$db.query("select 1 as n").rows;
$db.query('select ? as n', 42);
$db.query('select $x + $y as sum', x => 1, y => 2);

=end code

=end pod

multi method query(Str $sql --> Duckie::Result) {
  trace "Running query: $sql";
  my $res = DuckDB::Native::Result.new;
  unless (duckdb_query($!conn, $sql, $res) == DUCKDB_SUCCESS) {
     fail duckdb_result_error($res);
  }
  return Duckie::Result.new(:$res);
}

=begin pod

=head3 method prepare

=begin code

method prepare(Str $sql --> Duckie::PreparedStatement)

=end code

Prepare a statement.  Returns a C<Duckie::PreparedStatement>.
Use C<?> for positional parameters or C<$name> for named parameters.

The returned C<Duckie::PreparedStatement> has an C<execute> method:

=begin code

multi method execute(--> Duckie::Result)
multi method execute(*@params --> Duckie::Result)
multi method execute(*%named --> Duckie::Result)

=end code

Execute the prepared statement, optionally binding positional (C<?>) or named (C<$name>) parameters.

=begin code

my $stmt = $db.prepare('select ? as n, ? as s');
$stmt.execute(42, 'hello').rows;
# [{n => 42, s => hello}]

my $stmt2 = $db.prepare('select $x + $y as sum');
$stmt2.execute(x => 1, y => 2).rows;

=end code

=end pod

method prepare(Str $sql --> Duckie::PreparedStatement) {
  trace "Preparing query: $sql";
  my $ps = Duckie::PreparedStatement.new;
  unless duckdb_prepare($!conn, $sql, $ps.stmt) == DUCKDB_SUCCESS {
    fail duckdb_prepare_error($ps.stmt);
  }
  $ps;
}

multi method query(Str $sql, *@params where @params > 0 --> Duckie::Result) {
  trace "Running prepared query: $sql";
  self.prepare($sql).execute(|@params);
}

multi method query(Str $sql, *%named where %named.keys > 0 --> Duckie::Result) {
  self.prepare($sql).execute(|%named);
}

=begin pod

=head3 method register-table-function

=begin code

method register-table-function(
  Str     $name,
  :@columns,      # required: list of Pairs  name => 'TYPE'
  :@params = [],  # optional: list of SQL parameter type names
  :&function!,    # required: callable (*@params --> Iterable of arrays)
) returns Duckie

=end code

Register a user-defined table function that calls a Raku subroutine.

C<@columns> is a list of C<Pair> objects mapping column name to DuckDB type
string (e.g. C<'n' =E<gt> 'INTEGER'>).  Supported types: C<VARCHAR>, C<INTEGER>,
C<BIGINT>, C<DOUBLE>, C<FLOAT>, C<BOOLEAN>.

C<@params> declares the SQL parameter types accepted at the call site.

C<&function> is called once per query execution with the SQL arguments
(as strings) and must return an iterable of arrays, one per output row.

=begin code

$db.register-table-function('squares',
  columns  => ['n' => 'INTEGER', 'sq' => 'INTEGER'],
  params   => ['INTEGER'],
  function => sub ($n) { (1..$n.Int).map(-> $i { [$i, $i*$i] }) },
);
$db.query('SELECT * FROM squares(4)').rows;
# [{n => 1, sq => 1}, {n => 2, sq => 4}, ...]

=end code

=end pod

# MoarVM NativeCall callbacks are bound to the thread that created them.
# DuckDB's worker threads are not MoarVM threads, so any UDF callback
# invoked from a worker thread causes "native callback ran on thread unknown
# to MoarVM".  Limiting DuckDB to one thread keeps all callbacks on the
# thread that issued the query.
method !ensure-single-threaded {
  return if $!single-threaded;
  $!single-threaded = True;
  my $r = DuckDB::Native::Result.new;
  duckdb_query($!conn, "SET threads=1", $r);
}

method register-table-function(Str $name, :@columns!, :@params = [], :&function!) {
  self!ensure-single-threaded;
  my @cols = @columns.map: {
      $_ ~~ Pair ?? [$_.key, $_.value] !! $_
  };

  @_tf_registry.push: _TableFuncDef.new(
      :$name,
      columns     => @cols,
      param-types => @params,
      :&function,
  );
  my $def-id = @_tf_registry.elems - 1;

  my $tf = duckdb_create_table_function();
  LEAVE duckdb_destroy_table_function($tf);

  duckdb_table_function_set_name($tf, $name);
  duckdb_table_function_set_extra_info($tf, Pointer.new($def-id), Pointer);
  duckdb_table_function_set_bind($tf, &_tf-bind-cb);
  duckdb_table_function_set_init($tf, &_tf-init-cb);
  duckdb_table_function_set_function($tf, &_tf-func-cb);

  for @params -> $type-str {
      my $lt = _make-logical-type($type-str);
      duckdb_table_function_add_parameter($tf, $lt);
      duckdb_destroy_logical_type($lt);
  }

  duckdb_register_table_function($!conn, $tf) == +DUCKDB_SUCCESS
      or fail "Failed to register table function '$name'";
  self
}

=begin pod

=head3 method register-scalar-function

=begin code

method register-scalar-function(
  Str     $name,
  :@params!,      # required: list of SQL parameter type names
  :$returns!,     # required: return type name
  :&function!,    # required: callable (*@row-values --> Any)
) returns Duckie

=end code

Register a user-defined scalar function that calls a Raku subroutine
once per input row.

C<&function> receives one argument per declared parameter and must return
a single value of the declared return type.

=begin code

$db.register-scalar-function('raku-upper',
  params   => ['VARCHAR'],
  returns  => 'VARCHAR',
  function => sub ($s) { $s.uc },
);
$db.query("SELECT raku_upper('hello world')").column-data(0);
# ['HELLO WORLD']

=end code

=end pod

method register-scalar-function(Str $name, :@params!, :$returns!, :&function!) {
  self!ensure-single-threaded;
  @_sf_registry.push: _ScalarFuncDef.new(
      :$name,
      param-types => @params,
      return-type => $returns,
      :&function,
  );
  my $def-id = @_sf_registry.elems - 1;

  my $sf = duckdb_create_scalar_function();
  LEAVE duckdb_destroy_scalar_function($sf);

  duckdb_scalar_function_set_name($sf, $name);
  duckdb_scalar_function_set_extra_info($sf, Pointer.new($def-id), Pointer);

  for @params -> $type-str {
      my $lt = _make-logical-type($type-str);
      duckdb_scalar_function_add_parameter($sf, $lt);
      duckdb_destroy_logical_type($lt);
  }

  my $ret-lt = _make-logical-type($returns);
  duckdb_scalar_function_set_return_type($sf, $ret-lt);
  duckdb_destroy_logical_type($ret-lt);

  duckdb_scalar_function_set_function($sf, &_sf-func-cb);

  duckdb_register_scalar_function($!conn, $sf) == +DUCKDB_SUCCESS
      or fail "Failed to register scalar function '$name'";
  self
}

=begin pod

=head3 method DESTROY

Close the database connection and free resources.

=end pod

method DESTROY {
  duckdb_disconnect($!conn);
  $!conn = Nil;
  duckdb_close($!dbh);
  $!dbh = Nil;
}

=begin pod

=head1 SEE ALSO

=item L<Duckie::Result|https://github.com/bduggan/raku-duckie/blob/main/docs/lib/Duckie/Result.md>

=item L<Duckie::DuckDB::Native|https://github.com/bduggan/raku-duckie/blob/main/docs/lib/Duckie/DuckDB/Native.md>

=head1 ENVIRONMENT

Set C<DUCKIE_DEBUG> to a true value to enable logging to C<STDERR>.

=head1 AUTHOR

Brian Duggan

=end pod

}

sub EXPORT($name = Nil, *@args) {
  return %( ) without $name;
  my $obj = Duckie.new;
  $obj.logger.send-to: $*ERR if @args.first: * eq '-debug';
  %( $name => $obj );
}
