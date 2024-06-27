=begin pod

=head1 NAME

Duckie::DuckDB::Native - Native bindings for DuckDB

=head1 SYNOPSIS

=begin code

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

#| DUCKDB_API duckdb_string duckdb_value_string(duckdb_result *result, idx_t col, idx_t row);
sub duckdb_value_string(Result $res, uint64 $col, uint64 $row) returns Str is native(libduckdb) is export { * }

#| DUCKDB_API uint64_t duckdb_value_uint64(duckdb_result *result, idx_t col, idx_t row);
sub duckdb_value_uint64(Result $res, uint64 $col, uint64 $row) returns uint64 is native(libduckdb) is export { * }

#| DUCKDB_API duckdb_state duckdb_open(const char *path, duckdb_database *out_database);
sub duckdb_open(Str $path, Database $dbh is rw) returns int32 is native(libduckdb) is export { * }

#| DUCKDB_API void duckdb_close(duckdb_database *database);
sub duckdb_close(Database $dbh is rw) returns int32 is native(libduckdb) is export { * }

#| DUCKDB_API duckdb_state duckdb_connect(duckdb_database database, duckdb_connection *out_connection);
sub duckdb_connect(Database $dbh, Connection $conn is rw) returns int32 is native(libduckdb) is export { * }

#| DUCKDB_API void duckdb_disconnect(duckdb_connection *connection);
sub duckdb_disconnect(Connection $conn is rw) returns int32 is native(libduckdb) is export { * }

#| DUCKDB_API duckdb_state duckdb_query(duckdb_connection connection, const char *query, duckdb_result *out_result);
sub duckdb_query(Connection $conn, Str $query is encoded('utf8'), Result $res is rw) returns int32 is native(libduckdb) is export { * }

#| DUCKDB_API void duckdb_destroy_result(duckdb_result *result);
sub duckdb_destroy_result(Result $res is rw) returns int32 is native(libduckdb) is export { * }

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

