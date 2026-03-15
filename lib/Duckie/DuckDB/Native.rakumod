=begin pod

=head1 NAME

Duckie::DuckDB::Native - Native bindings for DuckDB

=head1 SYNOPSIS

=begin code

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

=end code

=head1 DESCRIPTION

This is a direct mapping to the  [C API](https://duckdb.org/docs/api/c/api.html) of DuckDB.

This is incomplete, contributions are welcome!  All new additions should have corresponding
tests in the test suite.

Note that many subroutines are either deprecated or marked for deprecation in some future release.
If they have been deprecated and there is a working alternative, then we provide the newer
preferred alternative.  If there is no alternative, then we provide the deprecated subroutine.

Some descriptions have been included below, which have mostly been taken directly from the header file C<duckdb.h>.

=head1 CLASSES

=end pod

unit module DuckDB::Native;

use NativeCall;

sub libduckdb {
  # This may need work for other platforms/versions, e.g.
  # '/opt/homebrew/Cellar/duckdb/1.0.0/lib/libduckdb.dylib'
  'duckdb'
};

# Scalar UDF support was added in libduckdb 1.1.0
sub libduckdb_1_1 { ('duckdb', v1.1) };

enum DuckDBState is export (
  DUCKDB_SUCCESS => 0,
  DUCKDB_ERROR => 1,
);

enum DuckDBType is export (
  DUCKDB_TYPE_INVALID => 0,
  DUCKDB_TYPE_BOOLEAN => 1,           # bool
  DUCKDB_TYPE_TINYINT => 2,           # int8_t
  DUCKDB_TYPE_SMALLINT => 3,          # int16_t
  DUCKDB_TYPE_INTEGER => 4,           # int32_t
  DUCKDB_TYPE_BIGINT => 5,            # int64_t
  DUCKDB_TYPE_UTINYINT => 6,          # uint8_t
  DUCKDB_TYPE_USMALLINT => 7,         # uint16_t
  DUCKDB_TYPE_UINTEGER => 8,          # uint32_t
  DUCKDB_TYPE_UBIGINT => 9,           # uint64_t
  DUCKDB_TYPE_FLOAT => 10,            # float
  DUCKDB_TYPE_DOUBLE => 11,           # double
  DUCKDB_TYPE_TIMESTAMP => 12,        # duckdb_timestamp, in microseconds
  DUCKDB_TYPE_DATE => 13,             # duckdb_date
  DUCKDB_TYPE_TIME => 14,             # duckdb_time
  DUCKDB_TYPE_INTERVAL => 15,         # duckdb_interval
  DUCKDB_TYPE_HUGEINT => 16,          # duckdb_hugeint
  DUCKDB_TYPE_UHUGEINT => 32,         # duckdb_uhugeint
  DUCKDB_TYPE_VARCHAR => 17,          # const char*
  DUCKDB_TYPE_BLOB => 18,             # duckdb_blob
  DUCKDB_TYPE_DECIMAL => 19,          # decimal
  DUCKDB_TYPE_TIMESTAMP_S => 20,      # duckdb_timestamp, in seconds
  DUCKDB_TYPE_TIMESTAMP_MS => 21,     # duckdb_timestamp, in milliseconds
  DUCKDB_TYPE_TIMESTAMP_NS => 22,     # duckdb_timestamp, in nanoseconds
  DUCKDB_TYPE_ENUM => 23,             # enum type, only useful as logical type
  DUCKDB_TYPE_LIST => 24,             # list type, only useful as logical type
  DUCKDB_TYPE_STRUCT => 25,           # struct type, only useful as logical type
  DUCKDB_TYPE_MAP => 26,              # map type, only useful as logical type
  DUCKDB_TYPE_ARRAY => 33,            # duckdb_array, only useful as logical type
  DUCKDB_TYPE_UUID => 27,             # duckdb_hugeint
  DUCKDB_TYPE_UNION => 28,            # union type, only useful as logical type
  DUCKDB_TYPE_BIT => 29,              # duckdb_bit
  DUCKDB_TYPE_TIME_TZ => 30,          # duckdb_time_tz
  DUCKDB_TYPE_TIMESTAMP_TZ => 31,     # duckdb_timestamp
  DUCKDB_TYPE_ANY => 34,              # any type
  DUCKDB_TYPE_VARINT => 35,           # duckdb_varint
  DUCKDB_TYPE_SQLNULL => 36,          # SQLNULL type
);

#| `duckdb_database` :
#| A database object. Should be closed with `duckdb_close`.
class Database is repr('CPointer') is export { }

#| `duckdb_connection` :
#| A connection to a duckdb database. Must be closed with `duckdb_disconnect`.
class Connection is repr('CPointer') is export { }

#| `duckdb_result` :
#| A query result consists of a pointer to its internal data.
#| Must be freed with 'duckdb_destroy_result'.
class Result is repr('CStruct') is export {
  has uint64 $.column_count;                      # idx_t column_count;
  has uint64 $.row_count;                         # idx_t row_count;
  has uint64 $.rows_changed;                      # idx_t rows_changed;
  has Pointer $.columns is rw = Pointer.new;      # duckdb_column *columns;
  has Str $.error_message;                        # char *error_message;
  has Pointer $.internal_data = Pointer.new;      # void *internal_data;
}

#| `duckdb_data_chunk` :
#| Contains a data chunk from a duckdb_result.
#| Must be destroyed with `duckdb_destroy_data_chunk`.
class DataChunk is repr('CPointer') is export { }

#| `duckdb_logical_type` :
#| Holds an internal logical type.
#| Must be destroyed with `duckdb_destroy_logical_type`.
class LogicalType is repr('CPointer') is export { }

#| `duckdb_hugeint` :
#| Hugeints are composed of a (lower, upper) component
#| The value of the hugeint is upper * 2^64 + lower
class HugeInt is repr('CStruct') is export {
  has uint64 $.lower; # uint64_t lower;
  has int64 $.upper; # int64_t upper;
  #| Returns the value of the hugeint
  method value {
    return $!upper * 2**64 + $!lower;
  }
}

#| `duckdb_blob` :
#| Blobs are composed of a pointer to data and a size
class DuckBlob is repr('CStruct') is export {
  has Pointer $.data; # void *data;
  has uint64 $.size;  # idx_t size;
}

#| `duckdb_uhugeint` :
#| An unsigned hugeint, similar to duckdb_hugeint
class UHugeInt is repr('CStruct') is export {
  has uint64 $.lower; # uint64_t lower;
  has uint64 $.upper; # uint64_t upper;
  method value {
    return $!upper * 2**64 + $!lower;
  }
}

#| `duckdb_decimal` :
#| Decimals are composed of a width and a scale, and are stored in a hugeint
class Decimal is repr('CStruct') is export {
  has uint8 $.width; # uint8_t width;
  has uint8 $.scale; # uint8_t scale;
  has HugeInt $.value; # duckdb_hugeint value;
}

#| `duckdb_date` :
#| Days are stored as days since 1970-01-01
class DuckDate is repr('CStruct') is export {
  has int32 $.days; # int32_t days;
  method Date {
    # $.days is days since 1970-01-01
    DateTime.new( $.days * 24 * 60 * 60).Date;
  }
}

#| `duckdb_time` :
#| Time is stored as microseconds since 00:00:00
class DuckTime is repr('CStruct') is export {
  has int64 $.micros; # int64_t micros;
  #| cast to a raku DateTime
  method DateTime {
    # $.micros is microseconds since 00:00:00
    DateTime.new($.micros / 1_000_000);
  }
}

#| `duckdb_timestamp` :
#| Timestamps are stored as microseconds since 1970-01-01
class DuckTimestamp is repr('CStruct') is export {
  has int64 $.micros; # int64_t micros;
  method DateTime {
    # $.micros is microseconds since 1970-01-01
    DateTime.new($.micros / 1_000_000);
  }
}

enum DuckDBResultType (
  DUCKDB_RESULT_TYPE_INVALID => 0,
  DUCKDB_RESULT_TYPE_CHANGED_ROWS => 1,
  DUCKDB_RESULT_TYPE_NOTHING => 2,
  DUCKDB_RESULT_TYPE_QUERY_RESULT => 3,
);

my constant NULL is export = Pointer;

=begin pod

=head1 SUBROUTINES

=end pod

#| DUCKDB_API duckdb_string duckdb_value_string(duckdb_result *result, idx_t col, idx_t row);
sub duckdb_value_string(Result $res, uint64 $col, uint64 $row) returns Str is native(libduckdb) is export { * }

#| DUCKDB_API bool duckdb_value_boolean(duckdb_result *result, idx_t col, idx_t row);
sub duckdb_value_boolean(Result $res, uint64 $col, uint64 $row) returns int32 is native(libduckdb) is export { * }

#| DUCKDB_API uint64_t duckdb_value_uint64(duckdb_result *result, idx_t col, idx_t row);
sub duckdb_value_uint64(Result $res, uint64 $col, uint64 $row) returns uint64 is native(libduckdb) is export { * }

#| DUCKDB_API duckdb_state duckdb_open(const char *path, duckdb_database *out_database);
sub duckdb_open(Str $path, Database $dbh is rw) returns int32 is native(libduckdb) is export { * }

#| DUCKDB_API void duckdb_close(duckdb_database *database);
sub duckdb_close(Database $dbh is rw) is native(libduckdb) is export { * }

#| DUCKDB_API duckdb_state duckdb_connect(duckdb_database database, duckdb_connection *out_connection);
sub duckdb_connect(Database $dbh, Connection $conn is rw) returns int32 is native(libduckdb) is export { * }

#| DUCKDB_API void duckdb_disconnect(duckdb_connection *connection);
sub duckdb_disconnect(Connection $conn is rw) is native(libduckdb) is export { * }

#| DUCKDB_API duckdb_state duckdb_query(duckdb_connection connection, const char *query, duckdb_result *out_result);
sub duckdb_query(Connection $conn, Str $query is encoded('utf8'), Result $res is rw) returns int32 is native(libduckdb) is export { * }

#| DUCKDB_API void duckdb_destroy_result(duckdb_result *result);
sub duckdb_destroy_result(Result $res is rw) is native(libduckdb) is export { * }

#| DUCKDB_API const char *duckdb_library_version();
sub duckdb_library_version() returns Str is native(libduckdb) is export { * }

#| DUCKDB_API idx_t duckdb_column_count(duckdb_result *result);
sub duckdb_column_count(Result $res) returns uint64 is native(libduckdb) is export { * }

#| DUCKDB_API idx_t duckdb_row_count(duckdb_result *result);
sub duckdb_row_count(Result $res) returns uint64 is native(libduckdb) is export { * }

#| DUCKDB_API const char *duckdb_column_name(duckdb_result *result, idx_t col);
sub duckdb_column_name(Result $res, uint64 $col) returns Str is native(libduckdb) is export { * }

#| DUCKDB_API duckdb_type duckdb_column_type(duckdb_result *result, idx_t col);
sub duckdb_column_type(Result $res, uint64 $col) returns uint32 is native(libduckdb) is export { * }

#| DUCKDB_API void *duckdb_column_data(duckdb_result *result, idx_t col);
sub duckdb_column_data(Result $res, uint64 $col) returns Pointer is native(libduckdb) is export { * }

#| DUCKDB_API idx_t duckdb_rows_changed(duckdb_result *result);
sub duckdb_rows_changed(Result $res) returns uint64 is native(libduckdb) is export { * }

#| DUCKDB_API const char *duckdb_result_error(duckdb_result *result);
sub duckdb_result_error(Result $res) returns Str is native(libduckdb) is export { * }

#| DUCKDB_API idx_t duckdb_result_chunk_count(duckdb_result result);
sub duckdb_result_chunk_count(Result $res) returns uint64 is native(libduckdb) is export { * }

#| DUCKDB_API duckdb_result_type duckdb_result_return_type(duckdb_result result);
sub duckdb_result_return_type(Result $res) returns uint32 is native(libduckdb) is export { * }

#| DUCKDB_API duckdb_data_chunk duckdb_result_get_chunk(duckdb_result result, idx_t chunk_index);
sub duckdb_result_get_chunk(Result $res, uint64 $chunk_index) returns DataChunk is native(libduckdb) is export { * }

#| DUCKDB_API idx_t duckdb_data_chunk_get_column_count(duckdb_data_chunk chunk);
sub duckdb_data_chunk_get_column_count(DataChunk $chunk) is native(libduckdb) is export { * }

#| DUCKDB_API bool *duckdb_nullmask_data(duckdb_result *result, idx_t col);
sub duckdb_nullmask_data(Result $res, uint64 $col) returns Pointer is native(libduckdb) is export { * }

#| DUCKDB_API duckdb_logical_type duckdb_column_logical_type(duckdb_result *result, idx_t col);
sub duckdb_column_logical_type(Result $res, uint64 $col) returns LogicalType is native(libduckdb) is export { * }

#| DUCKDB_API char *duckdb_logical_type_get_alias(duckdb_logical_type type);
sub duckdb_logical_type_get_alias(LogicalType $type) returns Str is native(libduckdb) is export { * }

#| DUCKDB_API uint8_t duckdb_decimal_width(duckdb_logical_type type);
sub duckdb_decimal_width(LogicalType $type) returns uint8 is native(libduckdb) is export { * }

#| DUCKDB_API uint8_t duckdb_decimal_scale(duckdb_logical_type type);
sub duckdb_decimal_scale(LogicalType $type) returns uint8 is native(libduckdb) is export { * }

#| DUCKDB_API duckdb_type duckdb_decimal_internal_type(duckdb_logical_type type);
sub duckdb_decimal_internal_type(LogicalType $type) returns uint32 is native(libduckdb) is export { * }

#| `duckdb_prepared_statement` :
#| A prepared statement object. Must be destroyed with `duckdb_destroy_prepared_statement`.
class PreparedStatement is repr('CPointer') is export { }

#| DUCKDB_API duckdb_state duckdb_prepare(duckdb_connection connection, const char *query, duckdb_prepared_statement *out_prepared_statement);
sub duckdb_prepare(Connection $conn, Str $query, PreparedStatement $stmt is rw) returns int32 is native(libduckdb) is export { * }

#| DUCKDB_API void duckdb_destroy_prepare(duckdb_prepared_statement *prepared_statement);
sub duckdb_destroy_prepare(PreparedStatement $stmt is rw) is native(libduckdb) is export { * }

#| DUCKDB_API const char *duckdb_prepare_error(duckdb_prepared_statement prepared_statement);
sub duckdb_prepare_error(PreparedStatement $stmt) returns Str is native(libduckdb) is export { * }

#| DUCKDB_API duckdb_state duckdb_execute_prepared(duckdb_prepared_statement prepared_statement, duckdb_result *out_result);
sub duckdb_execute_prepared(PreparedStatement $stmt, Result $res is rw) returns int32 is native(libduckdb) is export { * }

#| DUCKDB_API idx_t duckdb_nparams(duckdb_prepared_statement prepared_statement);
sub duckdb_nparams(PreparedStatement $stmt) returns uint64 is native(libduckdb) is export { * }

#| DUCKDB_API const char *duckdb_parameter_name(duckdb_prepared_statement prepared_statement, idx_t index);
#| Returns the name of the parameter at the given index (1-based). The name includes the leading '$'.
sub duckdb_parameter_name(PreparedStatement $stmt, uint64 $idx) returns Str is native(libduckdb) is export { * }

#| DUCKDB_API duckdb_state duckdb_bind_parameter_index(duckdb_prepared_statement prepared_statement, idx_t *param_idx, const char *name);
#| Looks up the 1-based index of a named parameter by name (without the leading '$').
sub duckdb_bind_parameter_index(PreparedStatement $stmt, uint64 $param_idx is rw, Str $name) returns int32 is native(libduckdb) is export { * }

#| DUCKDB_API duckdb_state duckdb_bind_boolean(duckdb_prepared_statement prepared_statement, idx_t param_idx, bool val);
sub duckdb_bind_boolean(PreparedStatement $stmt, uint64 $idx, int32 $val) returns int32 is native(libduckdb) is export { * }

#| DUCKDB_API duckdb_state duckdb_bind_int8(duckdb_prepared_statement prepared_statement, idx_t param_idx, int8_t val);
sub duckdb_bind_int8(PreparedStatement $stmt, uint64 $idx, int8 $val) returns int32 is native(libduckdb) is export { * }

#| DUCKDB_API duckdb_state duckdb_bind_int16(duckdb_prepared_statement prepared_statement, idx_t param_idx, int16_t val);
sub duckdb_bind_int16(PreparedStatement $stmt, uint64 $idx, int16 $val) returns int32 is native(libduckdb) is export { * }

#| DUCKDB_API duckdb_state duckdb_bind_int32(duckdb_prepared_statement prepared_statement, idx_t param_idx, int32_t val);
sub duckdb_bind_int32(PreparedStatement $stmt, uint64 $idx, int32 $val) returns int32 is native(libduckdb) is export { * }

#| DUCKDB_API duckdb_state duckdb_bind_int64(duckdb_prepared_statement prepared_statement, idx_t param_idx, int64_t val);
sub duckdb_bind_int64(PreparedStatement $stmt, uint64 $idx, int64 $val) returns int32 is native(libduckdb) is export { * }

#| DUCKDB_API duckdb_state duckdb_bind_float(duckdb_prepared_statement prepared_statement, idx_t param_idx, float val);
sub duckdb_bind_float(PreparedStatement $stmt, uint64 $idx, num32 $val) returns int32 is native(libduckdb) is export { * }

#| DUCKDB_API duckdb_state duckdb_bind_double(duckdb_prepared_statement prepared_statement, idx_t param_idx, double val);
sub duckdb_bind_double(PreparedStatement $stmt, uint64 $idx, num64 $val) returns int32 is native(libduckdb) is export { * }

#| DUCKDB_API duckdb_state duckdb_bind_varchar(duckdb_prepared_statement prepared_statement, idx_t param_idx, const char *val);
sub duckdb_bind_varchar(PreparedStatement $stmt, uint64 $idx, Str $val) returns int32 is native(libduckdb) is export { * }

#| DUCKDB_API duckdb_state duckdb_bind_null(duckdb_prepared_statement prepared_statement, idx_t param_idx);
sub duckdb_bind_null(PreparedStatement $stmt, uint64 $idx) returns int32 is native(libduckdb) is export { * }

#| DUCKDB_API duckdb_state duckdb_bind_blob(duckdb_prepared_statement prepared_statement, idx_t param_idx, const void *data, idx_t length);
sub duckdb_bind_blob(PreparedStatement $stmt, uint64 $idx, CArray[uint8] $data, uint64 $length) returns int32 is native(libduckdb) is export { * }

# --- Logical type ---

#| DUCKDB_API duckdb_logical_type duckdb_create_logical_type(duckdb_type type);
sub duckdb_create_logical_type(uint32 $type) returns LogicalType is native(libduckdb) is export { * }

#| DUCKDB_API void duckdb_destroy_logical_type(duckdb_logical_type *type);
sub duckdb_destroy_logical_type(LogicalType $type is rw) is native(libduckdb) is export { * }

# --- Table functions ---

#| `duckdb_table_function` :
#| A table function. Must be destroyed with `duckdb_destroy_table_function`.
class TableFunction is repr('CPointer') is export { }

#| `duckdb_bind_info` :
#| Information passed to the bind callback of a table function.
class BindInfo is repr('CPointer') is export { }

#| `duckdb_init_info` :
#| Information passed to the init callback of a table function.
class InitInfo is repr('CPointer') is export { }

#| `duckdb_function_info` :
#| Information passed to the function callback of a table function.
class FunctionInfo is repr('CPointer') is export { }

#| `duckdb_vector` :
#| A column vector, used to write output data in table function callbacks.
class DuckVector is repr('CPointer') is export { }

#| `duckdb_value` :
#| A scalar value, used to retrieve parameters in table function bind callbacks.
class DuckValue is repr('CPointer') is export { }

#| DUCKDB_API duckdb_table_function duckdb_create_table_function();
sub duckdb_create_table_function() returns TableFunction is native(libduckdb) is export { * }

#| DUCKDB_API void duckdb_destroy_table_function(duckdb_table_function *table_function);
sub duckdb_destroy_table_function(TableFunction $tf is rw) is native(libduckdb) is export { * }

#| DUCKDB_API void duckdb_table_function_set_name(duckdb_table_function table_function, const char *name);
sub duckdb_table_function_set_name(TableFunction $tf, Str $name) is native(libduckdb) is export { * }

#| DUCKDB_API void duckdb_table_function_add_parameter(duckdb_table_function table_function, duckdb_logical_type type);
sub duckdb_table_function_add_parameter(TableFunction $tf, LogicalType $type) is native(libduckdb) is export { * }

#| DUCKDB_API void duckdb_table_function_set_extra_info(duckdb_table_function table_function, void *extra_info, duckdb_delete_callback_t destroy);
sub duckdb_table_function_set_extra_info(TableFunction $tf, Pointer $extra, Pointer $destroy) is native(libduckdb) is export { * }

#| DUCKDB_API void duckdb_table_function_set_bind(duckdb_table_function table_function, duckdb_table_function_bind_t bind);
sub duckdb_table_function_set_bind(TableFunction $tf, &callback (BindInfo)) is native(libduckdb) is export { * }

#| DUCKDB_API void duckdb_table_function_set_init(duckdb_table_function table_function, duckdb_table_function_init_t init);
sub duckdb_table_function_set_init(TableFunction $tf, &callback (InitInfo)) is native(libduckdb) is export { * }

#| DUCKDB_API void duckdb_table_function_set_function(duckdb_table_function table_function, duckdb_table_function_t function);
sub duckdb_table_function_set_function(TableFunction $tf, &callback (FunctionInfo, DataChunk)) is native(libduckdb) is export { * }

#| DUCKDB_API duckdb_state duckdb_register_table_function(duckdb_connection con, duckdb_table_function function);
sub duckdb_register_table_function(Connection $conn, TableFunction $tf) returns int32 is native(libduckdb) is export { * }

# --- Bind info ---

#| DUCKDB_API void *duckdb_bind_get_extra_info(duckdb_bind_info info);
sub duckdb_bind_get_extra_info(BindInfo $info) returns Pointer is native(libduckdb) is export { * }

#| DUCKDB_API void duckdb_bind_add_result_column(duckdb_bind_info info, const char *name, duckdb_logical_type type);
sub duckdb_bind_add_result_column(BindInfo $info, Str $name, LogicalType $type) is native(libduckdb) is export { * }

#| DUCKDB_API idx_t duckdb_bind_get_parameter_count(duckdb_bind_info info);
sub duckdb_bind_get_parameter_count(BindInfo $info) returns uint64 is native(libduckdb) is export { * }

#| DUCKDB_API duckdb_value duckdb_bind_get_parameter(duckdb_bind_info info, idx_t index);
sub duckdb_bind_get_parameter(BindInfo $info, uint64 $index) returns DuckValue is native(libduckdb) is export { * }

#| DUCKDB_API void duckdb_bind_set_bind_data(duckdb_bind_info info, void *bind_data, duckdb_delete_callback_t destroy);
sub duckdb_bind_set_bind_data(BindInfo $info, Pointer $data, Pointer $destroy) is native(libduckdb) is export { * }

# --- Init info ---

#| DUCKDB_API void *duckdb_init_get_bind_data(duckdb_init_info info);
sub duckdb_init_get_bind_data(InitInfo $info) returns Pointer is native(libduckdb) is export { * }

#| DUCKDB_API void duckdb_init_set_init_data(duckdb_init_info info, void *init_data, duckdb_delete_callback_t destroy);
sub duckdb_init_set_init_data(InitInfo $info, Pointer $data, Pointer $destroy) is native(libduckdb) is export { * }

# --- Function info ---

#| DUCKDB_API void *duckdb_function_get_bind_data(duckdb_function_info info);
sub duckdb_function_get_bind_data(FunctionInfo $info) returns Pointer is native(libduckdb) is export { * }

#| DUCKDB_API void *duckdb_function_get_init_data(duckdb_function_info info);
sub duckdb_function_get_init_data(FunctionInfo $info) returns Pointer is native(libduckdb) is export { * }

# --- Data chunk (table function output) ---

#| DUCKDB_API duckdb_vector duckdb_data_chunk_get_vector(duckdb_data_chunk chunk, idx_t col_idx);
sub duckdb_data_chunk_get_vector(DataChunk $chunk, uint64 $col) returns DuckVector is native(libduckdb) is export { * }

#| DUCKDB_API void duckdb_data_chunk_set_size(duckdb_data_chunk chunk, idx_t size);
sub duckdb_data_chunk_set_size(DataChunk $chunk, uint64 $size) is native(libduckdb) is export { * }

# --- Vector ---

#| DUCKDB_API void *duckdb_vector_get_data(duckdb_vector vector);
sub duckdb_vector_get_data(DuckVector $vec) returns Pointer is native(libduckdb) is export { * }

#| DUCKDB_API void duckdb_vector_assign_string_element(duckdb_vector vector, idx_t index, const char *str);
sub duckdb_vector_assign_string_element(DuckVector $vec, uint64 $idx, Str $str) is native(libduckdb) is export { * }

#| DUCKDB_API idx_t duckdb_vector_size();
sub duckdb_vector_size() returns uint64 is native(libduckdb) is export { * }

#| DUCKDB_API idx_t duckdb_data_chunk_get_size(duckdb_data_chunk chunk);
sub duckdb_data_chunk_get_size(DataChunk $chunk) returns uint64 is native(libduckdb) is export { * }

# --- Value API ---

#| DUCKDB_API void duckdb_destroy_value(duckdb_value *value);
sub duckdb_destroy_value(DuckValue $val is rw) is native(libduckdb) is export { * }

#| DUCKDB_API char *duckdb_get_varchar(duckdb_value value);
sub duckdb_get_varchar(DuckValue $val) returns Str is native(libduckdb) is export { * }

#| DUCKDB_API int64_t duckdb_get_int64(duckdb_value value);
sub duckdb_get_int64(DuckValue $val) returns int64 is native(libduckdb) is export { * }

# --- Scalar functions ---

#| `duckdb_scalar_function` :
#| A scalar (row-level) UDF. Must be destroyed with `duckdb_destroy_scalar_function`.
class ScalarFunction is repr('CPointer') is export { }

#| DUCKDB_API duckdb_scalar_function duckdb_create_scalar_function();
sub duckdb_create_scalar_function() returns ScalarFunction is native(libduckdb_1_1) is export { * }

#| DUCKDB_API void duckdb_destroy_scalar_function(duckdb_scalar_function *scalar_function);
sub duckdb_destroy_scalar_function(ScalarFunction $sf is rw) is native(libduckdb_1_1) is export { * }

#| DUCKDB_API void duckdb_scalar_function_set_name(duckdb_scalar_function scalar_function, const char *name);
sub duckdb_scalar_function_set_name(ScalarFunction $sf, Str $name) is native(libduckdb_1_1) is export { * }

#| DUCKDB_API void duckdb_scalar_function_add_parameter(duckdb_scalar_function scalar_function, duckdb_logical_type type);
sub duckdb_scalar_function_add_parameter(ScalarFunction $sf, LogicalType $type) is native(libduckdb_1_1) is export { * }

#| DUCKDB_API void duckdb_scalar_function_set_return_type(duckdb_scalar_function scalar_function, duckdb_logical_type type);
sub duckdb_scalar_function_set_return_type(ScalarFunction $sf, LogicalType $type) is native(libduckdb_1_1) is export { * }

#| DUCKDB_API void duckdb_scalar_function_set_extra_info(duckdb_scalar_function scalar_function, void *extra_info, duckdb_delete_callback_t destroy);
sub duckdb_scalar_function_set_extra_info(ScalarFunction $sf, Pointer $extra, Pointer $destroy) is native(libduckdb_1_1) is export { * }

#| DUCKDB_API void duckdb_scalar_function_set_function(duckdb_scalar_function scalar_function, duckdb_scalar_function_t function);
#| The callback signature is: void f(duckdb_function_info info, duckdb_data_chunk input, duckdb_vector output)
sub duckdb_scalar_function_set_function(ScalarFunction $sf, &callback (FunctionInfo, DataChunk, DuckVector)) is native(libduckdb_1_1) is export { * }

#| DUCKDB_API duckdb_state duckdb_register_scalar_function(duckdb_connection con, duckdb_scalar_function scalar_function);
sub duckdb_register_scalar_function(Connection $conn, ScalarFunction $sf) returns int32 is native(libduckdb_1_1) is export { * }

#| DUCKDB_API void *duckdb_scalar_function_get_extra_info(duckdb_function_info info);
sub duckdb_scalar_function_get_extra_info(FunctionInfo $info) returns Pointer is native(libduckdb_1_1) is export { * }

#| DUCKDB_API void duckdb_scalar_function_set_error(duckdb_function_info info, const char *error);
sub duckdb_scalar_function_set_error(FunctionInfo $info, Str $error) is native(libduckdb_1_1) is export { * }

