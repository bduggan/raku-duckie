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

head
====

NOTES

Unsupported types are currently treated as `Nil`. These will emit a warning, if diagnostics are enabled. Set `DUCKIE_DEBUG` to send warnings to stderr (or use `Log::Async` and add a tap).

