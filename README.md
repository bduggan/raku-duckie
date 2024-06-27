NAME
====

Duckie - A wrapper and native bindings for DuckDB

SYNOPSIS
========

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

    # DuckDB can read CSV, JSON, AWS S3, HTTP, Parquet, PostgreSQL, SQLite, MySQL and others
    $result = $db.query("select * from 'data.csv')");
    $result = $db.query("select * from 'data.json')");

    $db.query: q[attach 'postgres://secret:pw@localhost/dbname' as my_postgres_database (type postgres);];
    $result = $db.query: "select * from my_postgres_database.my_table";

    $db.query: "install httpfs";
    $db.query: "load httpfs";
    $result = $db.query: "select * from 'http://example.com/data.csv'";

    # It can even join between data sources
    $result = $db.query: q:to/SQL/
    select *
      from 'one.csv'
      join 'two.json' on one.id = two.id
      join 'http://example.com/three.csv' on one.id = three.id
      join 's3://bucket/four.csv' on one.id = four.id
      join my_postgres_database.my_table on one.id = my_table.id
    SQL

DESCRIPTION
===========

This module provides Raku bindings for [DuckDB](https://duckdb.org/). DuckDB is a "fast in-process analytical database". It provides an SQL interface for a variety of data sources. Result sets are column-oriented, with a rich set of types that are either inferred or preserved from the data source. The high-level interface also provides a familiar row-oriented API.

This module provides two sets of classes.

  * `Duckie::DuckDB::Native` is a low-level interface that directly maps to the [C API](https://duckdb.org/docs/api/c/api.html). Note that a number of the function calls there are either deprecated or scheduled for deprecation, so the implementation of the Raku interface favors the more recent mechanisms where possible.

  * `Duckie` provides a very high level interface that handles things like memory management and native type-casting. While the Raku language supports native types, the results from `Duckie` do not currently expose them, preferring, for instance to return Integers instead of uint8s, int64s, etc, and using Rats for decimals, and Nums for floats. A future interface may expose native types.

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

ENVIRONMENT
===========

Set `DUCKIE_DEBUG` to a true value to enable logging to `STDERR`.

AUTHOR
======

Brian Duggan

