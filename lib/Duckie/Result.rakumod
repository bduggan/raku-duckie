=begin pod

=head1 NAME

Duckie::Result - DuckDB result set

=head1 SYNOPSIS

=begin code

use Duckie::Result;

my $result = Duckie::Result.new(:$res);

say $result.column-count;
say $result.row-count;
say $result.column-names;
say $result.rows[0]<column-name>;
say $result.rows(:arrays)[0][0];
say $result.columns[0][0];

=end code

=head1 DESCRIPTION

This class represents a result set from a DuckDB query.  Data is converted
from native types into higher level Raku types, and may be retrieved in
either a row-oriented or column-oriented form.  Note that for row-oriented
retrieval, the entire result set is read into memory.

While DuckDB is geared towards efficient memory use, this class aims to
provide a more Raku-friendly interface to the data, which may involve
some copying and conversion.

=head1 METHODS

=end pod

unit class Duckie::Result;
use Duckie::DuckDB::Native;
use NativeCall;
use Log::Async;

logger.untapped-ok;

has DuckDB::Native::Result $.res;
has @!column-names;
has @!all-column-data;
has Bool $!use-chunks;

#| Returns the names of the columns in the result set
method column-names(--> List) {
  return @!column-names if @!column-names;
  @!column-names := eager (^self.column-count).map: { duckdb_column_name($!res, $_) };
}

sub enum-to-str($type) {
  DuckDBType.invert.Hash{ $type }.Str.subst('DUCKDB_TYPE_', '');  # Output: BOOLEAN
}

#| Return the native column types of the columns
method column-types(--> List) {
  eager (^self.column-count).map: { enum-to-str(duckdb_column_type($!res, $_)) };
}

#| Return the native type by column name
method column-type(Str $name --> Str) {
  my $index = self.column-names.first( :k, * eq $name );
  fail "No such column: $name" unless defined $index;
  enum-to-str( duckdb_column_type($!res, $index))
}

#| Returns the number of columns in the result set
method column-count(--> Int) {
  $!res.column_count;
}

#| Returns the number of rows in the result set
method row-count(--> Int) {
  duckdb_row_count($!res);
}

#| Returns the data for the specified column name
multi method column-data(Str $name --> List) {
  my $index = self.column-names.first( :k, * eq $name );
  fail "No such column: $name" unless defined $index;
  self.column-data($index);
}

#| Returns the data for the specified column number
multi method column-data(Int $c --> List) {
  return self!chunk-column-data($c) if self!use-chunks;
  my $data = duckdb_column_data($!res, $c);
  my $null-mask = nativecast(Pointer[int8], duckdb_nullmask_data($!res, $c));
  my $column-type = duckdb_column_type($!res, $c);
  my %types = DuckDBType.enums.invert.Hash;
  my $count = duckdb_row_count($!res);
  my sub val-at($v,$n) {
    $v.add($n).deref;
  }

  my $logical-type = duckdb_column_logical_type($!res, $c);
  my @ret;

  given $column-type {
    when DUCKDB_TYPE_BOOLEAN {
      @ret = (^$count).map: { $null-mask[$_] ?? Nil !! so duckdb_value_boolean($!res, $c, $_) };
      return @ret;
    }
  }

  without $data {
    warning "no data for column $c ({self.column-names[ $c ]}) of type { %types{$column-type} }";
    my @ret = (^$count).map: { Nil }
    return @ret;
  }
  given $column-type {
    when DUCKDB_TYPE_TINYINT {
      my $values = nativecast(Pointer[int8], $data);
      @ret = (^$count).map: { $null-mask[$_] ?? Nil !! val-at($values,$_).Int };
    }
    when DUCKDB_TYPE_UTINYINT {
      my $values = nativecast(Pointer[uint8], $data);
      @ret = (^$count).map: { $null-mask[$_] ?? Nil !! val-at($values,$_).Int };
    }
    when DUCKDB_TYPE_SMALLINT {
      my $values = nativecast(Pointer[int16], $data);
      @ret = (^$count).map: { $null-mask[$_] ?? Nil !! val-at($values,$_).Int };
    }
    when DUCKDB_TYPE_USMALLINT {
      my $values = nativecast(Pointer[uint16], $data);
      @ret = (^$count).map: { $null-mask[$_] ?? Nil !! val-at($values,$_).Int };
    }
    when DUCKDB_TYPE_INTEGER {
      my $values = nativecast(Pointer[int32], $data);
      @ret = (^$count).map: { $null-mask[$_] ?? Nil !! val-at($values,$_).Int };
    }
    when DUCKDB_TYPE_UINTEGER {
      my $values = nativecast(Pointer[uint32], $data);
      @ret = (^$count).map: { $null-mask[$_] ?? Nil !! val-at($values,$_).Int };
    }
    when | DUCKDB_TYPE_BIGINT
         | DUCKDB_TYPE_UBIGINT
         {
      my $values = nativecast(Pointer[int64], $data);
      @ret = (^$count).map: { $null-mask[$_] ?? Nil !! val-at($values,$_).Numeric };
    }
    when DUCKDB_TYPE_VARCHAR {
      @ret = (^$count).map: { $null-mask[$_] ?? Nil !! duckdb_value_string($!res,$c,$_) }
    }
    when DUCKDB_TYPE_BLOB {
      my $values := nativecast(Pointer[DuckBlob], $data);
      @ret = (^$count).map: {
        if $null-mask[$_] {
          Nil
        } else {
          my $blob = val-at($values, $_);
          my $src = nativecast(CArray[uint8], $blob.data);
          Buf.new( (^$blob.size).map({ $src[$_] }) )
        }
      }
    }
    when DUCKDB_TYPE_DECIMAL {
      my $width = duckdb_decimal_width($logical-type);
      my $scale = duckdb_decimal_scale($logical-type);
      my $internal-type = duckdb_decimal_internal_type($logical-type);
      do given $internal-type {
        when DUCKDB_TYPE_SMALLINT | DUCKDB_TYPE_INTEGER | DUCKDB_TYPE_BIGINT {
          my $values := nativecast(Pointer[int64],$data);
          @ret = (^$count).map: { $null-mask[$_] ?? Nil !! Rat.new($values[2*$_], 10**$scale); }
        }
        when DUCKDB_TYPE_HUGEINT {
          my $values := nativecast(Pointer[HugeInt],$data);
          @ret = (^$count).map: { $null-mask[$_] ?? Nil !! Rat.new( val-at($values,$_).value, 10**$scale); }
        }
        when DUCKDB_TYPE_UHUGEINT {
          my $values := nativecast(Pointer[UHugeInt],$data);
          @ret = (^$count).map: { $null-mask[$_] ?? Nil !! Rat.new( val-at($values,$_).value, 10**$scale); }
        }
        default {
          debug "decimal internal type for column $c ({ self.column-names[$c] }) { %types{ $internal-type } }";
          my $values := nativecast(Pointer[int64],$data);
          @ret = (^$count).map: { $null-mask[$_] ?? Nil !! Rat.new($values[2*$_], 10**$scale); }
        }
      }
    }
    when DUCKDB_TYPE_HUGEINT {
      my $values := nativecast(Pointer[HugeInt],$data);
      @ret = (^$count).map: {
         $null-mask[$_] ?? Nil !! val-at($values,$_).value
      }
    }
    when DUCKDB_TYPE_UHUGEINT {
      my $values := nativecast(Pointer[UHugeInt],$data);
      @ret = (^$count).map: {
         $null-mask[$_] ?? Nil !! val-at($values,$_).value
      }
    }
    when DUCKDB_TYPE_DATE {
      my $values := nativecast(Pointer[DuckDate],$data);
      @ret = (^$count).map: { $null-mask[$_] ?? Nil !! val-at($values,$_).Date }
    }
    when DUCKDB_TYPE_TIME {
      my $values := nativecast(Pointer[DuckTime],$data);
      @ret = (^$count).map: { $null-mask[$_] ?? Nil !! val-at($values,$_).DateTime }
    }
    when DUCKDB_TYPE_TIME_NS {
      my $values := nativecast(Pointer[DuckTimeNS],$data);
      @ret = (^$count).map: { $null-mask[$_] ?? Nil !! val-at($values,$_).DateTime }
    }
    when | DUCKDB_TYPE_TIMESTAMP
         | DUCKDB_TYPE_TIMESTAMP_S
         | DUCKDB_TYPE_TIMESTAMP_MS
         | DUCKDB_TYPE_TIMESTAMP_NS
         | DUCKDB_TYPE_TIMESTAMP_TZ {
      my $values = nativecast(Pointer[DuckTimestamp],$data);
      @ret = (^$count).map: { $null-mask[$_] ?? Nil !! val-at($values,$_).DateTime }
    }
    when DUCKDB_TYPE_FLOAT {
      my $values = nativecast(Pointer[num32],$data);
      @ret = (^$count).map: { $null-mask[$_] ?? Nil !! val-at($values,$_).Numeric };
    }
    when DUCKDB_TYPE_DOUBLE {
      my $values = nativecast(Pointer[num64],$data);
      @ret = (^$count).map: { $null-mask[$_] ?? Nil !! val-at($values,$_).Numeric };
    }
    when DUCKDB_TYPE_INVALID {
      fail "invalid column $c";
    }
    default {
      @ret = (^$count).map: {
        # soft failure for each one
        Failure.new("unsupported column type: $column-type ({%types{$column-type} }) for column $c ({self.column-names[$c]})");
      }
    }
  }
  @ret;
}

#| The deprecated column API (duckdb_column_data) has no data for some
#| types (e.g. GEOMETRY), and once a result has been read through the chunk
#| API the deprecated API no longer works (and vice versa).  So results that
#| contain any of those types are read entirely through the chunk API.
method !use-chunks(--> Bool) {
  $!use-chunks //= so (^self.column-count).grep: {
    duckdb_column_type($!res, $_) == DUCKDB_TYPE_GEOMETRY
  }
}

#| Returns the data for the specified column number, read from the result chunks.
method !chunk-column-data(Int $c --> List) {
  my $decode = self!chunk-decoder($c);
  my @ret;
  for ^duckdb_result_chunk_count($!res) -> $i {
    my $chunk = duckdb_result_get_chunk($!res, $i);
    my $vec = duckdb_data_chunk_get_vector($chunk, $c);
    my $data = duckdb_vector_get_data($vec);
    my $validity = duckdb_vector_get_validity($vec);
    for ^duckdb_data_chunk_get_size($chunk) -> $row {
      my $valid = !$validity || ($validity[$row div 64] +& (1 +< ($row % 64)));
      @ret.push: $valid ?? $decode($data, $row) !! Nil;
    }
    duckdb_destroy_data_chunk($chunk);
  }
  @ret;
}

#| Read element $i of a vector stored as duckdb_string_t (16 bytes/element):
#|   bytes 0-3  : uint32 length
#|   if len ≤ 12: bytes 4-15 contain the inlined data
#|   if len > 12: bytes 8-15 contain a pointer to the data
sub string-t-at(Pointer $data, Int $i --> Buf) {
  my $raw = nativecast(CArray[uint8], $data);
  my $off = $i * 16;
  my $len = [+|] (^4).map: { $raw[$off + $_] +< ($_ * 8) };
  return Buf.new( (^$len).map({ $raw[$off + 4 + $_] }) ) if $len <= 12;
  my $addr = [+|] (^8).map: { $raw[$off + 8 + $_] +< ($_ * 8) };
  my $src = nativecast(CArray[uint8], Pointer.new($addr));
  Buf.new( (^$len).map({ $src[$_] }) );
}

#| Returns a sub that converts element $i of a vector for column $c.
method !chunk-decoder(Int $c --> Callable) {
  my sub at(\T) { -> $data, $i { nativecast(CArray[T], $data)[$i] } }
  my sub struct-at(\T) { -> $data, $i { nativecast(Pointer[T], $data).add($i).deref } }
  my $column-type = duckdb_column_type($!res, $c);
  given $column-type {
    when DUCKDB_TYPE_BOOLEAN    { -> $d, $i { so at(uint8)($d, $i) } }
    when DUCKDB_TYPE_TINYINT    { at(int8) }
    when DUCKDB_TYPE_UTINYINT   { at(uint8) }
    when DUCKDB_TYPE_SMALLINT   { at(int16) }
    when DUCKDB_TYPE_USMALLINT  { at(uint16) }
    when DUCKDB_TYPE_INTEGER    { at(int32) }
    when DUCKDB_TYPE_UINTEGER   { at(uint32) }
    when DUCKDB_TYPE_BIGINT     { at(int64) }
    when DUCKDB_TYPE_UBIGINT    { at(uint64) }
    when DUCKDB_TYPE_FLOAT      { at(num32) }
    when DUCKDB_TYPE_DOUBLE     { at(num64) }
    when DUCKDB_TYPE_HUGEINT    { -> $d, $i { struct-at(HugeInt)($d, $i).value } }
    when DUCKDB_TYPE_UHUGEINT   { -> $d, $i { struct-at(UHugeInt)($d, $i).value } }
    when DUCKDB_TYPE_VARCHAR    { -> $d, $i { string-t-at($d, $i).decode } }
    when DUCKDB_TYPE_BLOB       { &string-t-at }
    when DUCKDB_TYPE_GEOMETRY   { -> $d, $i { DuckWKB.new(wkb => string-t-at($d, $i)).hex } }
    when DUCKDB_TYPE_DATE       { -> $d, $i { struct-at(DuckDate)($d, $i).Date } }
    when DUCKDB_TYPE_TIME       { -> $d, $i { struct-at(DuckTime)($d, $i).DateTime } }
    when DUCKDB_TYPE_TIME_NS    { -> $d, $i { struct-at(DuckTimeNS)($d, $i).DateTime } }
    when DUCKDB_TYPE_TIMESTAMP | DUCKDB_TYPE_TIMESTAMP_TZ {
      -> $d, $i { struct-at(DuckTimestamp)($d, $i).DateTime }
    }
    # vectors store these in their own units, not microseconds
    when DUCKDB_TYPE_TIMESTAMP_S  { -> $d, $i { DuckTimestamp.new(micros => at(int64)($d, $i) * 1_000_000).DateTime } }
    when DUCKDB_TYPE_TIMESTAMP_MS { -> $d, $i { DuckTimestamp.new(micros => at(int64)($d, $i) * 1_000).DateTime } }
    when DUCKDB_TYPE_TIMESTAMP_NS { -> $d, $i { DuckTimestamp.new(micros => at(int64)($d, $i) div 1_000).DateTime } }
    when DUCKDB_TYPE_DECIMAL {
      my $logical-type = duckdb_column_logical_type($!res, $c);
      my $scale = duckdb_decimal_scale($logical-type);
      my $value = do given duckdb_decimal_internal_type($logical-type) {
        when DUCKDB_TYPE_SMALLINT { at(int16) }
        when DUCKDB_TYPE_INTEGER  { at(int32) }
        when DUCKDB_TYPE_BIGINT   { at(int64) }
        default                   { -> $d, $i { struct-at(HugeInt)($d, $i).value } }
      }
      -> $d, $i { Rat.new($value($d, $i), 10**$scale) }
    }
    default {
      my %types = DuckDBType.enums.invert.Hash;
      warning "unsupported column type: $column-type ({%types{$column-type} }) for column $c ({self.column-names[$c]})";
      -> $, $ { Nil }
    }
  }
}

method !maybe-read-all {
  return if @!all-column-data;
  my $columns = self.column-count;
  debug "reading rows from $columns column{ $columns == 1 ?? '' !! 's'}";
  @!all-column-data = (^$columns).map: { self.column-data($_) }
}

#| Returns all the data for all of the columns.
method columns {
  self!maybe-read-all;
  @!all-column-data;
}

#| The dataset as a list of hashes, where the keys are the column names.
#| Set the C<:arrays> flag to True, to return the data as an array of arrays.
method rows(Bool :$arrays = False --> Iterable) {
  self!maybe-read-all;
  my @rows = do {
    when @!all-column-data == 0 {
      [];
    }
    when @!all-column-data == 1 {
      @!all-column-data[0].map: { [ $_, ] }
    }
    default {
      [Z] @!all-column-data;
    }
  }
  return @rows if $arrays;
  @rows.map: { %( self.column-names Z=> @$_ ) }
}

method DESTROY {
  with $!res {
    trace "destroying result";
    duckdb_destroy_result($!res);
    $!res = Nil;
  }
}

=begin pod

=head1 NOTES

Unsupported types are currently treated as C<Nil>.  These will emit a warning, if diagnostics
are enabled.  Set C<DUCKIE_DEBUG> to send warnings to stderr (or use C<Log::Async> and add
a tap).

=end pod

