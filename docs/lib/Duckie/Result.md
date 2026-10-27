NAME
====

Duckie::Result - DuckDB result set

SYNOPSIS
========

    use Duckie::Result;

    my $result = Duckie::Result.new(:$res);

    say $result.column-count;
    say $result.row-count;
    say $result.column-names;
    say $result.rows[0]<column-name>;
    say $result.rows(:arrays)[0][0];
    say $result.columns[0][0];

DESCRIPTION
===========

This class represents a result set from a DuckDB query. Data is converted from native types into higher level Raku types, and may be retrieved in either a row-oriented or column-oriented form. Note that for row-oriented retrieval, the entire result set is read into memory.

While DuckDB is geared towards efficient memory use, this class aims to provide a more Raku-friendly interface to the data, which may involve some copying and conversion.

METHODS
=======

### method column-names

```raku
method column-names() returns List
```

Returns the names of the columns in the result set

### method column-types

```raku
method column-types() returns List
```

Return the native column types of the columns

### method column-type

```raku
method column-type(
    Str $name
) returns Str
```

Return the native type by column name

### method column-count

```raku
method column-count() returns Int
```

Returns the number of columns in the result set

### method row-count

```raku
method row-count() returns Int
```

Returns the number of rows in the result set

### multi method column-data

```raku
multi method column-data(
    Str $name
) returns List
```

Returns the data for the specified column name

### multi method column-data

```raku
multi method column-data(
    Int $c
) returns List
```

Returns the data for the specified column number

### method use-chunks

```raku
method use-chunks() returns Bool
```

The deprecated column API (duckdb_column_data) has no data for nested types (LIST, STRUCT) or some other types (e.g. GEOMETRY), and once a result has been read through the chunk API the deprecated API no longer works (and vice versa).  So results that contain any of those types are read entirely through the chunk API.

### method chunk-column-data

```raku
method chunk-column-data(
    Int $c
) returns List
```

Returns the data for the specified column number, read from the result chunks.

### sub string-t-at

```raku
sub string-t-at(
    NativeCall::Types::Pointer $data,
    Int $i
) returns Buf
```

Read element $i of a vector stored as duckdb_string_t (16 bytes/element): bytes 0-3  : uint32 length if len ≤ 12: bytes 4-15 contain the inlined data if len > 12: bytes 8-15 contain a pointer to the data

### sub vector-valid

```raku
sub vector-valid(
    $validity,
    Int $row
) returns Bool
```

Check the $row'th bit in a validity bitmap.  A bitmap where all values are valid is represented by a NULL pointer.

### sub cstring-at

```raku
sub cstring-at(
    NativeCall::Types::Pointer $p
) returns Str
```

Reads a NUL-terminated C string at a pointer.

### method chunk-decoder

```raku
method chunk-decoder(
    DuckDB::Native::DuckVector $vec,
    Str $label = "vector"
) returns Callable
```

Returns a sub that converts element $i of the given vector.  The type is looked up from the vector itself, so this works for the columns of a result chunk as well as for the child vectors of nested types, which are decoded recursively.

### method columns

```raku
method columns() returns Mu
```

Returns all the data for all of the columns.

### method rows

```raku
method rows(
    Bool :$arrays = Bool::False
) returns Iterable
```

The dataset as a list of hashes, where the keys are the column names. Set the C<:arrays> flag to True, to return the data as an array of arrays.

NOTES
=====

LIST columns are returned as arrays of the decoded elements, and STRUCT columns as hashes of their fields. These are decoded recursively, so nested types (e.g. a list of structs) are supported, as are other types (including GEOMETRY) inside a list or struct.

Unsupported types are currently treated as `Nil`. These will emit a warning, if diagnostics are enabled. Set `DUCKIE_DEBUG` to send warnings to stderr (or use `Log::Async` and add a tap).

