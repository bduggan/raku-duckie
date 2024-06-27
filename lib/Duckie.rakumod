unit class Duckie;

=begin pod

=head1 NAME

Duckie - A wrapper and native bindings for DuckDB

=head1 SYNOPSIS

=begin code

use Duckie;
my $db = Duckie.new;

# Basic query
say $db.query("select 1 as the_loneliest_number").column-data(0); # [1]

# Errors are soft failures
with $db.query("select 1 as the_loneliest_number") -> $result {
  say $result.column-data('the_loneliest_number'); # [1]
} else {
  say "Failed to run query: $_";
}

# DuckDB can query lots of types of data sources and even join between them
$result = $db.query("select * from 'data.csv')");
$result = $db.query: q:to/SQL/;
attach 'postgres://secret:pw@localhost/dbname' as my_postgres_database (type postgres);
select * from my_postgres_database.my_table;
SQL

=end code

=head1 DESCRIPTION

This module provides Raku bindings for L<DuckDB|https://duckdb.org/>.  DuckDB is
a "fast in-process analytical database".  It provides an SQL interface for a variety
of data sources.  Result sets are column-oriented, with a rich set of types
that are either inferred or preserved from the data source.  The high-level
interface also provides a familiar row-oriented API.

This module provides two sets of classes.

=item C<Duckie::DuckDB::Native> is a low-level interface that directly
maps to the L<C API|https://duckdb.org/docs/api/c/api.html>.  Note that
a number of the function calls there are either deprecated or scheduled
for deprecation, so the implementation of the Raku interface favors the
more recent mechanisms where possible.

=item C<Duckie> provides a very high level interface that handles things like
memory management and native type-casting.  While the Raku language
supports native types, the results from C<Duckie> do not currently expose them,
preferring, for instance to return Integers instead of uint8s, int64s, etc, and
using Rats for decimals, and Nums for floats.  A future interface may expose
native types.

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

