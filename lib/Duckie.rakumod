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

=head1 EXPORTS

If an argument to C<use Duckie> is provided, a new C<Duckie> object is exported
with that name.  e.g.

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

use Duckie::DuckDB::Native;
use Duckie::Result;
use Log::Async;

logger.untapped-ok = True;

if %*ENV<DUCKIE_DEBUG> {
  logger.send-to($*ERR) 
}

has DuckDB::Native::Database $.dbh .= new;
has DuckDB::Native::Connection $.conn .= new;
has Str $.file = ':memory:';

submethod TWEAK {
  duckdb_open($!file, $!dbh) == +DUCKDB_SUCCESS or fail "Failed to open database $!file";
  duckdb_connect($!dbh, $!conn) == +DUCKDB_SUCCESS or fail "Failed to connect to database";
}

#| Run a query and return a result.  If the query fails, a soft failure is thrown.
method query(Str $sql --> Duckie::Result) {
  trace "Running query: $sql";
  my $res = DuckDB::Native::Result.new;
  unless (duckdb_query($!conn, $sql, $res) == DUCKDB_SUCCESS) {
     fail duckdb_result_error($res);
  }
  return Duckie::Result.new(:$res);
}

#| Close the database connection and free resources.
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

sub EXPORT($name = Nil) {
  return %( ) without $name;
  %( $name => Duckie.new );
}

