NAME
====

Duckie::DuckDB::Native - Native bindings for DuckDB

SYNOPSIS
========

    my DuckDB::Native::Database $dbh .= new;
    my DuckDB::Native::Connection $conn .= new;
    my DuckDB::Native::Result $res .= new;

    duckdb_open(':memory:', $dbh) == DUCKDB_SUCCESS or die "failed to open db";
    duckdb_connect($dbh, $conn) == DUCKDB_SUCCESS or die "failed to connect";

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

class DuckDB::Native::DuckBlob
------------------------------

`duckdb_blob` : Blobs are composed of a pointer to data and a size

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

SUBROUTINES
===========

### sub duckdb_value_string

```raku
sub duckdb_value_string(
    DuckDB::Native::Result $res,
    uint64 $col,
    uint64 $row
) returns Str
```

DUCKDB_API duckdb_string duckdb_value_string(duckdb_result *result, idx_t col, idx_t row);

### sub duckdb_value_boolean

```raku
sub duckdb_value_boolean(
    DuckDB::Native::Result $res,
    uint64 $col,
    uint64 $row
) returns int32
```

DUCKDB_API bool duckdb_value_boolean(duckdb_result *result, idx_t col, idx_t row);

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
) returns Mu
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
) returns Mu
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
) returns Mu
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

class DuckDB::Native::PreparedStatement
---------------------------------------

`duckdb_prepared_statement` : A prepared statement object. Must be destroyed with `duckdb_destroy_prepared_statement`.

### sub duckdb_prepare

```raku
sub duckdb_prepare(
    DuckDB::Native::Connection $conn,
    Str $query,
    DuckDB::Native::PreparedStatement $stmt is rw
) returns int32
```

DUCKDB_API duckdb_state duckdb_prepare(duckdb_connection connection, const char *query, duckdb_prepared_statement *out_prepared_statement);

### sub duckdb_destroy_prepare

```raku
sub duckdb_destroy_prepare(
    DuckDB::Native::PreparedStatement $stmt is rw
) returns Mu
```

DUCKDB_API void duckdb_destroy_prepare(duckdb_prepared_statement *prepared_statement);

### sub duckdb_prepare_error

```raku
sub duckdb_prepare_error(
    DuckDB::Native::PreparedStatement $stmt
) returns Str
```

DUCKDB_API const char *duckdb_prepare_error(duckdb_prepared_statement prepared_statement);

### sub duckdb_execute_prepared

```raku
sub duckdb_execute_prepared(
    DuckDB::Native::PreparedStatement $stmt,
    DuckDB::Native::Result $res is rw
) returns int32
```

DUCKDB_API duckdb_state duckdb_execute_prepared(duckdb_prepared_statement prepared_statement, duckdb_result *out_result);

### sub duckdb_nparams

```raku
sub duckdb_nparams(
    DuckDB::Native::PreparedStatement $stmt
) returns uint64
```

DUCKDB_API idx_t duckdb_nparams(duckdb_prepared_statement prepared_statement);

### sub duckdb_parameter_name

```raku
sub duckdb_parameter_name(
    DuckDB::Native::PreparedStatement $stmt,
    uint64 $idx
) returns Str
```

DUCKDB_API const char *duckdb_parameter_name(duckdb_prepared_statement prepared_statement, idx_t index); Returns the name of the parameter at the given index (1-based). The name includes the leading '$'.

### sub duckdb_bind_parameter_index

```raku
sub duckdb_bind_parameter_index(
    DuckDB::Native::PreparedStatement $stmt,
    uint64 $param_idx is rw,
    Str $name
) returns int32
```

DUCKDB_API duckdb_state duckdb_bind_parameter_index(duckdb_prepared_statement prepared_statement, idx_t *param_idx, const char *name); Looks up the 1-based index of a named parameter by name (without the leading '$').

### sub duckdb_bind_boolean

```raku
sub duckdb_bind_boolean(
    DuckDB::Native::PreparedStatement $stmt,
    uint64 $idx,
    int32 $val
) returns int32
```

DUCKDB_API duckdb_state duckdb_bind_boolean(duckdb_prepared_statement prepared_statement, idx_t param_idx, bool val);

### sub duckdb_bind_int8

```raku
sub duckdb_bind_int8(
    DuckDB::Native::PreparedStatement $stmt,
    uint64 $idx,
    int8 $val
) returns int32
```

DUCKDB_API duckdb_state duckdb_bind_int8(duckdb_prepared_statement prepared_statement, idx_t param_idx, int8_t val);

### sub duckdb_bind_int16

```raku
sub duckdb_bind_int16(
    DuckDB::Native::PreparedStatement $stmt,
    uint64 $idx,
    int16 $val
) returns int32
```

DUCKDB_API duckdb_state duckdb_bind_int16(duckdb_prepared_statement prepared_statement, idx_t param_idx, int16_t val);

### sub duckdb_bind_int32

```raku
sub duckdb_bind_int32(
    DuckDB::Native::PreparedStatement $stmt,
    uint64 $idx,
    int32 $val
) returns int32
```

DUCKDB_API duckdb_state duckdb_bind_int32(duckdb_prepared_statement prepared_statement, idx_t param_idx, int32_t val);

### sub duckdb_bind_int64

```raku
sub duckdb_bind_int64(
    DuckDB::Native::PreparedStatement $stmt,
    uint64 $idx,
    int64 $val
) returns int32
```

DUCKDB_API duckdb_state duckdb_bind_int64(duckdb_prepared_statement prepared_statement, idx_t param_idx, int64_t val);

### sub duckdb_bind_float

```raku
sub duckdb_bind_float(
    DuckDB::Native::PreparedStatement $stmt,
    uint64 $idx,
    num32 $val
) returns int32
```

DUCKDB_API duckdb_state duckdb_bind_float(duckdb_prepared_statement prepared_statement, idx_t param_idx, float val);

### sub duckdb_bind_double

```raku
sub duckdb_bind_double(
    DuckDB::Native::PreparedStatement $stmt,
    uint64 $idx,
    num64 $val
) returns int32
```

DUCKDB_API duckdb_state duckdb_bind_double(duckdb_prepared_statement prepared_statement, idx_t param_idx, double val);

### sub duckdb_bind_varchar

```raku
sub duckdb_bind_varchar(
    DuckDB::Native::PreparedStatement $stmt,
    uint64 $idx,
    Str $val
) returns int32
```

DUCKDB_API duckdb_state duckdb_bind_varchar(duckdb_prepared_statement prepared_statement, idx_t param_idx, const char *val);

### sub duckdb_bind_null

```raku
sub duckdb_bind_null(
    DuckDB::Native::PreparedStatement $stmt,
    uint64 $idx
) returns int32
```

DUCKDB_API duckdb_state duckdb_bind_null(duckdb_prepared_statement prepared_statement, idx_t param_idx);

### sub duckdb_bind_blob

```raku
sub duckdb_bind_blob(
    DuckDB::Native::PreparedStatement $stmt,
    uint64 $idx,
    NativeCall::Types::CArray[uint8] $data,
    uint64 $length
) returns int32
```

DUCKDB_API duckdb_state duckdb_bind_blob(duckdb_prepared_statement prepared_statement, idx_t param_idx, const void *data, idx_t length);

### sub duckdb_create_logical_type

```raku
sub duckdb_create_logical_type(
    uint32 $type
) returns DuckDB::Native::LogicalType
```

DUCKDB_API duckdb_logical_type duckdb_create_logical_type(duckdb_type type);

### sub duckdb_destroy_logical_type

```raku
sub duckdb_destroy_logical_type(
    DuckDB::Native::LogicalType $type is rw
) returns Mu
```

DUCKDB_API void duckdb_destroy_logical_type(duckdb_logical_type *type);

class DuckDB::Native::TableFunction
-----------------------------------

`duckdb_table_function` : A table function. Must be destroyed with `duckdb_destroy_table_function`.

class DuckDB::Native::BindInfo
------------------------------

`duckdb_bind_info` : Information passed to the bind callback of a table function.

class DuckDB::Native::InitInfo
------------------------------

`duckdb_init_info` : Information passed to the init callback of a table function.

class DuckDB::Native::FunctionInfo
----------------------------------

`duckdb_function_info` : Information passed to the function callback of a table function.

class DuckDB::Native::DuckVector
--------------------------------

`duckdb_vector` : A column vector, used to write output data in table function callbacks.

class DuckDB::Native::DuckValue
-------------------------------

`duckdb_value` : A scalar value, used to retrieve parameters in table function bind callbacks.

### sub duckdb_create_table_function

```raku
sub duckdb_create_table_function() returns DuckDB::Native::TableFunction
```

DUCKDB_API duckdb_table_function duckdb_create_table_function();

### sub duckdb_destroy_table_function

```raku
sub duckdb_destroy_table_function(
    DuckDB::Native::TableFunction $tf is rw
) returns Mu
```

DUCKDB_API void duckdb_destroy_table_function(duckdb_table_function *table_function);

### sub duckdb_table_function_set_name

```raku
sub duckdb_table_function_set_name(
    DuckDB::Native::TableFunction $tf,
    Str $name
) returns Mu
```

DUCKDB_API void duckdb_table_function_set_name(duckdb_table_function table_function, const char *name);

### sub duckdb_table_function_add_parameter

```raku
sub duckdb_table_function_add_parameter(
    DuckDB::Native::TableFunction $tf,
    DuckDB::Native::LogicalType $type
) returns Mu
```

DUCKDB_API void duckdb_table_function_add_parameter(duckdb_table_function table_function, duckdb_logical_type type);

### sub duckdb_table_function_set_extra_info

```raku
sub duckdb_table_function_set_extra_info(
    DuckDB::Native::TableFunction $tf,
    NativeCall::Types::Pointer $extra,
    NativeCall::Types::Pointer $destroy
) returns Mu
```

DUCKDB_API void duckdb_table_function_set_extra_info(duckdb_table_function table_function, void *extra_info, duckdb_delete_callback_t destroy);

### sub duckdb_table_function_set_bind

```raku
sub duckdb_table_function_set_bind(
    DuckDB::Native::TableFunction $tf,
    &callback (DuckDB::Native::BindInfo $)
) returns Mu
```

DUCKDB_API void duckdb_table_function_set_bind(duckdb_table_function table_function, duckdb_table_function_bind_t bind);

### sub duckdb_table_function_set_init

```raku
sub duckdb_table_function_set_init(
    DuckDB::Native::TableFunction $tf,
    &callback (DuckDB::Native::InitInfo $)
) returns Mu
```

DUCKDB_API void duckdb_table_function_set_init(duckdb_table_function table_function, duckdb_table_function_init_t init);

### sub duckdb_table_function_set_function

```raku
sub duckdb_table_function_set_function(
    DuckDB::Native::TableFunction $tf,
    &callback (DuckDB::Native::FunctionInfo $, DuckDB::Native::DataChunk $)
) returns Mu
```

DUCKDB_API void duckdb_table_function_set_function(duckdb_table_function table_function, duckdb_table_function_t function);

### sub duckdb_register_table_function

```raku
sub duckdb_register_table_function(
    DuckDB::Native::Connection $conn,
    DuckDB::Native::TableFunction $tf
) returns int32
```

DUCKDB_API duckdb_state duckdb_register_table_function(duckdb_connection con, duckdb_table_function function);

### sub duckdb_bind_get_extra_info

```raku
sub duckdb_bind_get_extra_info(
    DuckDB::Native::BindInfo $info
) returns NativeCall::Types::Pointer
```

DUCKDB_API void *duckdb_bind_get_extra_info(duckdb_bind_info info);

### sub duckdb_bind_add_result_column

```raku
sub duckdb_bind_add_result_column(
    DuckDB::Native::BindInfo $info,
    Str $name,
    DuckDB::Native::LogicalType $type
) returns Mu
```

DUCKDB_API void duckdb_bind_add_result_column(duckdb_bind_info info, const char *name, duckdb_logical_type type);

### sub duckdb_bind_get_parameter_count

```raku
sub duckdb_bind_get_parameter_count(
    DuckDB::Native::BindInfo $info
) returns uint64
```

DUCKDB_API idx_t duckdb_bind_get_parameter_count(duckdb_bind_info info);

### sub duckdb_bind_get_parameter

```raku
sub duckdb_bind_get_parameter(
    DuckDB::Native::BindInfo $info,
    uint64 $index
) returns DuckDB::Native::DuckValue
```

DUCKDB_API duckdb_value duckdb_bind_get_parameter(duckdb_bind_info info, idx_t index);

### sub duckdb_bind_set_bind_data

```raku
sub duckdb_bind_set_bind_data(
    DuckDB::Native::BindInfo $info,
    NativeCall::Types::Pointer $data,
    NativeCall::Types::Pointer $destroy
) returns Mu
```

DUCKDB_API void duckdb_bind_set_bind_data(duckdb_bind_info info, void *bind_data, duckdb_delete_callback_t destroy);

### sub duckdb_init_get_bind_data

```raku
sub duckdb_init_get_bind_data(
    DuckDB::Native::InitInfo $info
) returns NativeCall::Types::Pointer
```

DUCKDB_API void *duckdb_init_get_bind_data(duckdb_init_info info);

### sub duckdb_init_set_init_data

```raku
sub duckdb_init_set_init_data(
    DuckDB::Native::InitInfo $info,
    NativeCall::Types::Pointer $data,
    NativeCall::Types::Pointer $destroy
) returns Mu
```

DUCKDB_API void duckdb_init_set_init_data(duckdb_init_info info, void *init_data, duckdb_delete_callback_t destroy);

### sub duckdb_function_get_bind_data

```raku
sub duckdb_function_get_bind_data(
    DuckDB::Native::FunctionInfo $info
) returns NativeCall::Types::Pointer
```

DUCKDB_API void *duckdb_function_get_bind_data(duckdb_function_info info);

### sub duckdb_function_get_init_data

```raku
sub duckdb_function_get_init_data(
    DuckDB::Native::FunctionInfo $info
) returns NativeCall::Types::Pointer
```

DUCKDB_API void *duckdb_function_get_init_data(duckdb_function_info info);

### sub duckdb_data_chunk_get_vector

```raku
sub duckdb_data_chunk_get_vector(
    DuckDB::Native::DataChunk $chunk,
    uint64 $col
) returns DuckDB::Native::DuckVector
```

DUCKDB_API duckdb_vector duckdb_data_chunk_get_vector(duckdb_data_chunk chunk, idx_t col_idx);

### sub duckdb_data_chunk_set_size

```raku
sub duckdb_data_chunk_set_size(
    DuckDB::Native::DataChunk $chunk,
    uint64 $size
) returns Mu
```

DUCKDB_API void duckdb_data_chunk_set_size(duckdb_data_chunk chunk, idx_t size);

### sub duckdb_vector_get_data

```raku
sub duckdb_vector_get_data(
    DuckDB::Native::DuckVector $vec
) returns NativeCall::Types::Pointer
```

DUCKDB_API void *duckdb_vector_get_data(duckdb_vector vector);

### sub duckdb_vector_assign_string_element

```raku
sub duckdb_vector_assign_string_element(
    DuckDB::Native::DuckVector $vec,
    uint64 $idx,
    Str $str
) returns Mu
```

DUCKDB_API void duckdb_vector_assign_string_element(duckdb_vector vector, idx_t index, const char *str);

### sub duckdb_vector_size

```raku
sub duckdb_vector_size() returns uint64
```

DUCKDB_API idx_t duckdb_vector_size();

### sub duckdb_data_chunk_get_size

```raku
sub duckdb_data_chunk_get_size(
    DuckDB::Native::DataChunk $chunk
) returns uint64
```

DUCKDB_API idx_t duckdb_data_chunk_get_size(duckdb_data_chunk chunk);

### sub duckdb_destroy_value

```raku
sub duckdb_destroy_value(
    DuckDB::Native::DuckValue $val is rw
) returns Mu
```

DUCKDB_API void duckdb_destroy_value(duckdb_value *value);

### sub duckdb_get_varchar

```raku
sub duckdb_get_varchar(
    DuckDB::Native::DuckValue $val
) returns Str
```

DUCKDB_API char *duckdb_get_varchar(duckdb_value value);

### sub duckdb_get_int64

```raku
sub duckdb_get_int64(
    DuckDB::Native::DuckValue $val
) returns int64
```

DUCKDB_API int64_t duckdb_get_int64(duckdb_value value);

class DuckDB::Native::ScalarFunction
------------------------------------

`duckdb_scalar_function` : A scalar (row-level) UDF. Must be destroyed with `duckdb_destroy_scalar_function`.

### sub duckdb_create_scalar_function

```raku
sub duckdb_create_scalar_function() returns DuckDB::Native::ScalarFunction
```

DUCKDB_API duckdb_scalar_function duckdb_create_scalar_function();

### sub duckdb_destroy_scalar_function

```raku
sub duckdb_destroy_scalar_function(
    DuckDB::Native::ScalarFunction $sf is rw
) returns Mu
```

DUCKDB_API void duckdb_destroy_scalar_function(duckdb_scalar_function *scalar_function);

### sub duckdb_scalar_function_set_name

```raku
sub duckdb_scalar_function_set_name(
    DuckDB::Native::ScalarFunction $sf,
    Str $name
) returns Mu
```

DUCKDB_API void duckdb_scalar_function_set_name(duckdb_scalar_function scalar_function, const char *name);

### sub duckdb_scalar_function_add_parameter

```raku
sub duckdb_scalar_function_add_parameter(
    DuckDB::Native::ScalarFunction $sf,
    DuckDB::Native::LogicalType $type
) returns Mu
```

DUCKDB_API void duckdb_scalar_function_add_parameter(duckdb_scalar_function scalar_function, duckdb_logical_type type);

### sub duckdb_scalar_function_set_return_type

```raku
sub duckdb_scalar_function_set_return_type(
    DuckDB::Native::ScalarFunction $sf,
    DuckDB::Native::LogicalType $type
) returns Mu
```

DUCKDB_API void duckdb_scalar_function_set_return_type(duckdb_scalar_function scalar_function, duckdb_logical_type type);

### sub duckdb_scalar_function_set_extra_info

```raku
sub duckdb_scalar_function_set_extra_info(
    DuckDB::Native::ScalarFunction $sf,
    NativeCall::Types::Pointer $extra,
    NativeCall::Types::Pointer $destroy
) returns Mu
```

DUCKDB_API void duckdb_scalar_function_set_extra_info(duckdb_scalar_function scalar_function, void *extra_info, duckdb_delete_callback_t destroy);

### sub duckdb_scalar_function_set_function

```raku
sub duckdb_scalar_function_set_function(
    DuckDB::Native::ScalarFunction $sf,
    &callback (DuckDB::Native::FunctionInfo $, DuckDB::Native::DataChunk $, DuckDB::Native::DuckVector $)
) returns Mu
```

DUCKDB_API void duckdb_scalar_function_set_function(duckdb_scalar_function scalar_function, duckdb_scalar_function_t function); The callback signature is: void f(duckdb_function_info info, duckdb_data_chunk input, duckdb_vector output)

### sub duckdb_register_scalar_function

```raku
sub duckdb_register_scalar_function(
    DuckDB::Native::Connection $conn,
    DuckDB::Native::ScalarFunction $sf
) returns int32
```

DUCKDB_API duckdb_state duckdb_register_scalar_function(duckdb_connection con, duckdb_scalar_function scalar_function);

### sub duckdb_scalar_function_get_extra_info

```raku
sub duckdb_scalar_function_get_extra_info(
    DuckDB::Native::FunctionInfo $info
) returns NativeCall::Types::Pointer
```

DUCKDB_API void *duckdb_scalar_function_get_extra_info(duckdb_function_info info);

### sub duckdb_scalar_function_set_error

```raku
sub duckdb_scalar_function_set_error(
    DuckDB::Native::FunctionInfo $info,
    Str $error
) returns Mu
```

DUCKDB_API void duckdb_scalar_function_set_error(duckdb_function_info info, const char *error);

