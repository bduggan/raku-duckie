[![Actions Status](https://github.com/bduggan/raku-duckie/actions/workflows/linux.yml/badge.svg)](https://github.com/bduggan/raku-duckie/actions/workflows/linux.yml)
[![Actions Status](https://github.com/bduggan/raku-duckie/actions/workflows/macos.yml/badge.svg)](https://github.com/bduggan/raku-duckie/actions/workflows/macos.yml)

NAME
====

Duckie - A wrapper and native bindings for DuckDB

SYNOPSIS
========

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

DESCRIPTION
===========

This module provides Raku bindings for [DuckDB](https://duckdb.org/). DuckDB is a "fast in-process analytical database". It provides an SQL interface for a variety of data sources. Result sets are column-oriented, with a rich set of types that are either inferred, preserved, or explicitly defined. `Duckie` also provides a row-oriented API.

This module provides two sets of classes.

  * `Duckie::DuckDB::Native` is a low-level interface that directly maps to the [C API](https://duckdb.org/docs/api/c/api.html). Note that a number of the function calls there are either deprecated or scheduled for deprecation, so the implementation of the Raku interface favors the more recent mechanisms where possible.

  * `Duckie` provides a high level interface that handles things like memory management and native typecasting. While the Raku language supports native types, the results from `Duckie` do not currently expose them, preferring, for instance to return Integers instead of uint8s, int64s, etc, and using Rats for decimals, and Nums for floats. A future interface may expose native types.

INSTALLATION
============

Since Duckie depends on the C API, follow the instructions [here](https://duckdb.org/docs/stable/clients/c/overview) for installation of libduckdb before installing this module. For instance, the "C/C++" section of [this page](https://duckdb.org/install/?environment=c) has a link to a .zip file, which will need to be extracted and placed in a location that is included in a standard locations, or one included in `DYLD_LIBRARY_PATH` for os/x, or a similar `LD_LIBRARY_PATH` location for linux.

EXPORTS
=======

If an argument to `use Duckie` is provided, a new `Duckie` object is created and returned. Also "-debug" will enable debug output. e.g.

    use Duckie;                 # no exports
    use Duckie '$db';           # creates and exports "$db"
    use Duckie '$db', '-debug'; # creates and exports "$db" with debug output

By default, duckdb-version is exported, so `duckdb-version()` is always available.

    use Duckie 'db';
    db.query("select 1 as the_loneliest_number").column-data(0);

METHODS
=======

### method new

    method new(
      :$file = ':memory:'
    ) returns Duckie

Create a new Duckie object. The optional `:file` parameter specifies the path to a file to use as a database. If not specified, an in-memory database is used. The database is opened and connected to when the object is created.

### method query

    multi method query(Str $sql --> Duckie::Result)
    multi method query(Str $sql, *@params --> Duckie::Result)
    multi method query(Str $sql, *%named --> Duckie::Result)

Run a query and return a `Duckie::Result`. If the query fails, a soft failure is thrown.

Use `?` as positional placeholders and `$name` for named placeholders.

    $db.query("select 1 as n").rows;
    $db.query('select ? as n', 42);
    $db.query('select $x + $y as sum', x => 1, y => 2);

### method prepare

    method prepare(Str $sql --> Duckie::PreparedStatement)

Prepare a statement. Returns a `Duckie::PreparedStatement`. Use `?` for positional parameters or `$name` for named parameters.

The returned `Duckie::PreparedStatement` has an `execute` method:

    multi method execute(--> Duckie::Result)
    multi method execute(*@params --> Duckie::Result)
    multi method execute(*%named --> Duckie::Result)

Execute the prepared statement, optionally binding positional (`?`) or named (`$name`) parameters.

    my $stmt = $db.prepare('select ? as n, ? as s');
    $stmt.execute(42, 'hello').rows;
    # [{n => 42, s => hello}]

    my $stmt2 = $db.prepare('select $x + $y as sum');
    $stmt2.execute(x => 1, y => 2).rows;

### method register-table-function

    method register-table-function(
      Str     $name,
      :@columns,      # required: list of Pairs  name => 'TYPE'
      :@params = [],  # optional: list of SQL parameter type names
      :&function!,    # required: callable (*@params --> Iterable of arrays)
    ) returns Duckie

Register a user-defined table function that calls a Raku subroutine.

`@columns` is a list of `Pair` objects mapping column name to DuckDB type string (e.g. `'n' =E<gt> 'INTEGER'`). Supported types: `VARCHAR`, `INTEGER`, `BIGINT`, `DOUBLE`, `FLOAT`, `BOOLEAN`.

`@params` declares the SQL parameter types accepted at the call site.

`&function` is called once per query execution with the SQL arguments (as strings) and must return an iterable of arrays, one per output row.

**Thread safety note**: registering any table or scalar function causes the connection to switch to single-threaded mode (`SET threads=1`). This is necessary because MoarVM NativeCall callbacks are bound to the OS thread that created them; if DuckDB's internal worker threads invoke a callback, MoarVM panics with "native callback ran on thread unknown to MoarVM". Single-threaded mode ensures callbacks are always invoked on the same thread that issued the query.

    $db.register-table-function('squares',
      columns  => ['n' => 'INTEGER', 'sq' => 'INTEGER'],
      params   => ['INTEGER'],
      function => sub ($n) { (1..$n.Int).map(-> $i { [$i, $i*$i] }) },
    );
    $db.query('SELECT * FROM squares(4)').rows;
    # [{n => 1, sq => 1}, {n => 2, sq => 4}, ...]

### method register-scalar-function

    method register-scalar-function(
      Str     $name,
      :@params!,      # required: list of SQL parameter type names
      :$returns!,     # required: return type name
      :&function!,    # required: callable (*@row-values --> Any)
    ) returns Duckie

Register a user-defined scalar function that calls a Raku subroutine once per input row.

`&function` receives one argument per declared parameter and must return a single value of the declared return type.

**Thread safety note**: see [register-table-function](register-table-function) — registering any UDF switches the connection to single-threaded mode to prevent MoarVM panics from DuckDB worker threads invoking NativeCall callbacks.

    $db.register-scalar-function('raku-upper',
      params   => ['VARCHAR'],
      returns  => 'VARCHAR',
      function => sub ($s) { $s.uc },
    );
    $db.query("SELECT raku_upper('hello world')").column-data(0);
    # ['HELLO WORLD']

### method register-raku-sub

    method register-raku-sub(&function) returns Duckie

Register a named Raku subroutine as a DuckDB scalar UDF, inferring the SQL parameter and return types from the subroutine's type annotations.

The subroutine must:

  * have a name (i.e. not be an anonymous `sub`)

  * have typed parameters and a typed return value

Supported Raku-to-SQL type mappings:

<table class="pod-table">
<thead><tr>
<th>Raku type</th> <th>DuckDB type</th>
</tr></thead>
<tbody>
<tr> <td>Int</td> <td>INTEGER</td> </tr> <tr> <td>Str</td> <td>VARCHAR</td> </tr> <tr> <td>Num</td> <td>DOUBLE</td> </tr> <tr> <td>Bool</td> <td>BOOLEAN</td> </tr>
</tbody>
</table>

Unannotated or unrecognised types default to `VARCHAR`.

    sub double-it(Int $n --> Int) { $n * 2 }
    $db.register-raku-sub(&double-it);
    # Raku hyphens are converted to underscores for SQL:
    $db.query('SELECT double_it(21)').column-data(0);
    # [42]

### method DESTROY

Close the database connection and free resources.

SEE ALSO
========

  * [Duckie::Result](https://github.com/bduggan/raku-duckie/blob/main/docs/lib/Duckie/Result.md)

  * [Duckie::DuckDB::Native](https://github.com/bduggan/raku-duckie/blob/main/docs/lib/Duckie/DuckDB/Native.md)

ENVIRONMENT
===========

Set `DUCKIE_DEBUG` to a true value to enable logging to `STDERR`.

AUTHOR
======

Brian Duggan

