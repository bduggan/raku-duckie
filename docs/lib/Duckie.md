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

    # DuckDB can query or import data from CSV files, JSON files, HTTP or AWS S3 URLs, PostgreSQL database,
    # MySQL database, SQLite database, Parquet files and more.

    # Postgres
    $db.query: q[ attach 'postgres://secret:pw@localhost/dbname' as pg (type postgres)]
    $res = $db.query: "select * from pg.my_table"

    # HTTP
    $db.query("install httpfs");
    $db.query("load httpfs");
    $res = $db.query: "select * from 'http://example.com/data.csv'";

    # It can even join between them
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

METHODS
=======

### method new

    method new(
      :$file = ':memory:'
    ) returns Duckie

Create a new Duckie object. The optional `:file` parameter specifies the path to a file to use as a database. If not specified, an in-memory database is used. The database is opened and connected to when the object is created.

### method query

```raku
method query(
    Str $sql
) returns Duckie::Result
```

Run a query and return a result. If the query fails, a soft failure is thrown.

### method DESTROY

```raku
method DESTROY() returns Mu
```

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

