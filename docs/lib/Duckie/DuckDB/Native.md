NAME
====

Duckie::DuckDB::Native - Native bindings for DuckDB

SYNOPSIS
========

    my DuckDB::Native::Database $dbh .= new;
    my DuckDB::Native::Connection $conn .= new;
    my DuckDB::Native::Result $res .= new;

    duckdb_open(':memory:', $dbh), +DUCKDB_SUCCESS, 'open';
    duckdb_connect($dbh, $conn) , +DUCKDB_SUCCESS, 'connect';

    duckdb_query($conn, 'select 42 as answer', $res);
    say duckdb_value_string($res, 0, 0);

    duckdb_destroy_result($res);

    duckdb_disconnect($conn);
    duckdb_close($dbh);

DESCRIPTION
===========

This is a direct mapping to the [C API](https://duckdb.org/docs/api/c/api.html) of DuckDB.

This is incomplete, contributions are welcome! All new additions should have corresponding tests in the test suite.

Note that many subroutines are either deprecated or marked for deprecation in some future release. If they have been deprecated and there is a working alternative, then we provide the newer preferred alternative. If there is no alternative, then we provide the deprecated subroutine.

Some descriptions have been included below, which have mostly been taken directly from the header file `duckdb.h`.

CLASSES
=======

class DuckDB::Native::Database
------------------------------

`duckdb_database` : A database object. Should be closed with `duckdb_close`.

class DuckDB::Native::Connection
--------------------------------

`duckdb_connection` : A connection to a duckdb database. Must be closed with `duckdb_disconnect`.

class DuckDB::Native::Result
----------------------------

`duckdb_result` : A query result consists of a pointer to its internal data. Must be freed with 'duckdb_destroy_result'.

class DuckDB::Native::DataChunk
-------------------------------

`duckdb_data_chunk` : Contains a data chunk from a duckdb_result. Must be destroyed with `duckdb_destroy_data_chunk`.

class DuckDB::Native::LogicalType
---------------------------------

`duckdb_logical_type` : Holds an internal logical type. Must be destroyed with `duckdb_destroy_logical_type`.

class DuckDB::Native::HugeInt
-----------------------------

`duckdb_hugeint` : Hugeints are composed of a (lower, upper) component The value of the hugeint is upper * 2^64 + lower

### method value

```raku
method value() returns Mu
```

Returns the value of the hugeint

class DuckDB::Native::UHugeInt
------------------------------

`duckdb_uhugeint` : An unsigned hugeint, similar to duckdb_hugeint

class DuckDB::Native::Decimal
-----------------------------

`duckdb_decimal` : Decimals are composed of a width and a scale, and are stored in a hugeint

class DuckDB::Native::DuckDate
------------------------------

`duckdb_date` : Days are stored as days since 1970-01-01

class DuckDB::Native::DuckTime
------------------------------

`duckdb_time` : Time is stored as microseconds since 00:00:00

### method DateTime

```raku
method DateTime() returns Mu
```

cast to a raku DateTime

class DuckDB::Native::DuckTimestamp
-----------------------------------

`duckdb_timestamp` : Timestamps are stored as microseconds since 1970-01-01

### sub duckdb_value_string

```raku
sub duckdb_value_string(
    DuckDB::Native::Result $res,
    uint64 $col,
    uint64 $row
) returns Str
```

DUCKDB_API duckdb_string duckdb_value_string(duckdb_result *result, idx_t col, idx_t row);

### sub duckdb_value_uint64

```raku
sub duckdb_value_uint64(
    DuckDB::Native::Result $res,
    uint64 $col,
    uint64 $row
) returns uint64
```

DUCKDB_API uint64_t duckdb_value_uint64(duckdb_result *result, idx_t col, idx_t row);

### sub duckdb_open

```raku
sub duckdb_open(
    Str $path,
    DuckDB::Native::Database $dbh is rw
) returns int32
```

DUCKDB_API duckdb_state duckdb_open(const char *path, duckdb_database *out_database);

### sub duckdb_close

```raku
sub duckdb_close(
    DuckDB::Native::Database $dbh is rw
) returns int32
```

DUCKDB_API void duckdb_close(duckdb_database *database);

### sub duckdb_connect

```raku
sub duckdb_connect(
    DuckDB::Native::Database $dbh,
    DuckDB::Native::Connection $conn is rw
) returns int32
```

DUCKDB_API duckdb_state duckdb_connect(duckdb_database database, duckdb_connection *out_connection);

### sub duckdb_disconnect

```raku
sub duckdb_disconnect(
    DuckDB::Native::Connection $conn is rw
) returns int32
```

DUCKDB_API void duckdb_disconnect(duckdb_connection *connection);

### sub duckdb_query

```raku
sub duckdb_query(
    DuckDB::Native::Connection $conn,
    Str $query,
    DuckDB::Native::Result $res is rw
) returns int32
```

DUCKDB_API duckdb_state duckdb_query(duckdb_connection connection, const char *query, duckdb_result *out_result);

### sub duckdb_destroy_result

```raku
sub duckdb_destroy_result(
    DuckDB::Native::Result $res is rw
) returns int32
```

DUCKDB_API void duckdb_destroy_result(duckdb_result *result);

### sub duckdb_library_version

```raku
sub duckdb_library_version() returns Str
```

DUCKDB_API const char *duckdb_library_version();

### sub duckdb_column_count

```raku
sub duckdb_column_count(
    DuckDB::Native::Result $res
) returns uint64
```

DUCKDB_API idx_t duckdb_column_count(duckdb_result *result);

### sub duckdb_row_count

```raku
sub duckdb_row_count(
    DuckDB::Native::Result $res
) returns uint64
```

DUCKDB_API idx_t duckdb_row_count(duckdb_result *result);

### sub duckdb_column_name

```raku
sub duckdb_column_name(
    DuckDB::Native::Result $res,
    uint64 $col
) returns Str
```

DUCKDB_API const char *duckdb_column_name(duckdb_result *result, idx_t col);

### sub duckdb_column_type

```raku
sub duckdb_column_type(
    DuckDB::Native::Result $res,
    uint64 $col
) returns uint32
```

DUCKDB_API duckdb_type duckdb_column_type(duckdb_result *result, idx_t col);

### sub duckdb_column_data

```raku
sub duckdb_column_data(
    DuckDB::Native::Result $res,
    uint64 $col
) returns NativeCall::Types::Pointer
```

DUCKDB_API void *duckdb_column_data(duckdb_result *result, idx_t col);

### sub duckdb_rows_changed

```raku
sub duckdb_rows_changed(
    DuckDB::Native::Result $res
) returns uint64
```

DUCKDB_API idx_t duckdb_rows_changed(duckdb_result *result);

### sub duckdb_result_error

```raku
sub duckdb_result_error(
    DuckDB::Native::Result $res
) returns Str
```

DUCKDB_API const char *duckdb_result_error(duckdb_result *result);

### sub duckdb_result_chunk_count

```raku
sub duckdb_result_chunk_count(
    DuckDB::Native::Result $res
) returns uint64
```

DUCKDB_API idx_t duckdb_result_chunk_count(duckdb_result result);

### sub duckdb_result_return_type

```raku
sub duckdb_result_return_type(
    DuckDB::Native::Result $res
) returns uint32
```

DUCKDB_API duckdb_result_type duckdb_result_return_type(duckdb_result result);

### sub duckdb_result_get_chunk

```raku
sub duckdb_result_get_chunk(
    DuckDB::Native::Result $res,
    uint64 $chunk_index
) returns DuckDB::Native::DataChunk
```

DUCKDB_API duckdb_data_chunk duckdb_result_get_chunk(duckdb_result result, idx_t chunk_index);

### sub duckdb_data_chunk_get_column_count

```raku
sub duckdb_data_chunk_get_column_count(
    DuckDB::Native::DataChunk $chunk
) returns Mu
```

DUCKDB_API idx_t duckdb_data_chunk_get_column_count(duckdb_data_chunk chunk);

### sub duckdb_nullmask_data

```raku
sub duckdb_nullmask_data(
    DuckDB::Native::Result $res,
    uint64 $col
) returns NativeCall::Types::Pointer
```

DUCKDB_API bool *duckdb_nullmask_data(duckdb_result *result, idx_t col);

### sub duckdb_column_logical_type

```raku
sub duckdb_column_logical_type(
    DuckDB::Native::Result $res,
    uint64 $col
) returns DuckDB::Native::LogicalType
```

DUCKDB_API duckdb_logical_type duckdb_column_logical_type(duckdb_result *result, idx_t col);

### sub duckdb_logical_type_get_alias

```raku
sub duckdb_logical_type_get_alias(
    DuckDB::Native::LogicalType $type
) returns Str
```

DUCKDB_API char *duckdb_logical_type_get_alias(duckdb_logical_type type);

### sub duckdb_decimal_width

```raku
sub duckdb_decimal_width(
    DuckDB::Native::LogicalType $type
) returns uint8
```

DUCKDB_API uint8_t duckdb_decimal_width(duckdb_logical_type type);

### sub duckdb_decimal_scale

```raku
sub duckdb_decimal_scale(
    DuckDB::Native::LogicalType $type
) returns uint8
```

DUCKDB_API uint8_t duckdb_decimal_scale(duckdb_logical_type type);

### sub duckdb_decimal_internal_type

```raku
sub duckdb_decimal_internal_type(
    DuckDB::Native::LogicalType $type
) returns uint32
```

DUCKDB_API duckdb_type duckdb_decimal_internal_type(duckdb_logical_type type);

