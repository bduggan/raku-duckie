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

#| The deprecated column API (duckdb_column_data) has no data for nested
#| types (LIST, STRUCT) or some other types (e.g. GEOMETRY), and once a result
#| has been read through the chunk API the deprecated API no longer works
#| (and vice versa).  So results that contain any of those types are read
#| entirely through the chunk API.
my constant @chunk-only-types = (
  DUCKDB_TYPE_GEOMETRY, DUCKDB_TYPE_LIST, DUCKDB_TYPE_STRUCT,
  DUCKDB_TYPE_UUID, DUCKDB_TYPE_TIME_TZ, DUCKDB_TYPE_INTERVAL, DUCKDB_TYPE_BIGNUM,
  DUCKDB_TYPE_BIT, DUCKDB_TYPE_ENUM, DUCKDB_TYPE_MAP,
  DUCKDB_TYPE_ARRAY, DUCKDB_TYPE_UNION,
);

method !use-chunks(--> Bool) {
  $!use-chunks //= so (^self.column-count).grep: {
    duckdb_column_type($!res, $_) == any(@chunk-only-types)
  }
}

#| Returns the data for the specified column number, read from the result chunks.
method !chunk-column-data(Int $c --> List) {
  my @ret;
  my $label = "column $c ({self.column-names[$c]})";
  for ^duckdb_result_chunk_count($!res) -> $i {
    my $chunk = duckdb_result_get_chunk($!res, $i);
    my $vec = duckdb_data_chunk_get_vector($chunk, $c);
    my $decode = self!chunk-decoder($vec, $label);
    my $data = duckdb_vector_get_data($vec);
    my $validity = duckdb_vector_get_validity($vec);
    for ^duckdb_data_chunk_get_size($chunk) -> $row {
      @ret.push: vector-valid($validity, $row) ?? $decode($data, $row) !! Nil;
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

#| Decode a BIGNUM blob: a 3 byte header followed by the big-endian bytes of
#| the absolute value.  The top bit of the header is set for positive numbers;
#| for negative numbers the header and the data are bitwise inverted.
sub bignum-value(Buf $blob --> Int) {
  my $negative = !($blob[0] +& 0x80);
  my @bytes = $blob.subbuf(3).list;
  @bytes = @bytes.map: { $_ +^ 0xFF } if $negative;
  my $abs = :256[ @bytes ];
  $negative ?? -$abs !! $abs;
}

#| Decode a BIT blob into a string of 0s and 1s.  The first byte is the number
#| of padding bits (0-7), which are the first bits of the second byte.
sub bit-string(Buf $blob --> Str) {
  my $padding = $blob[0];
  my $bits = $blob.subbuf(1).list.map({ .fmt('%08b') }).join;
  $bits.substr($padding);
}

#| Check the $row'th bit in a validity bitmap.  A bitmap where all values
#| are valid is represented by a NULL pointer.
sub vector-valid($validity, Int $row --> Bool) {
  !$validity || so ($validity[$row div 64] +& (1 +< ($row % 64)))
}

#| Reads a NUL-terminated C string at a pointer.
sub cstring-at(Pointer $p --> Str) {
  my $bytes := nativecast(CArray[uint8], $p);
  my @bytes;
  my $i = 0;
  while $bytes[$i] {
    @bytes.push: $bytes[$i];
    $i++;
  }
  Buf.new(@bytes).decode;
}

#| Returns a sub that converts element $i of the given vector.  The type is
#| looked up from the vector itself, so this works for the columns of a
#| result chunk as well as for the child vectors of nested types, which are
#| decoded recursively.
method !chunk-decoder(DuckVector $vec, Str $label = 'vector' --> Callable) {
  my sub at(\T) { -> $data, $i { nativecast(CArray[T], $data)[$i] } }
  my sub struct-at(\T) { -> $data, $i { nativecast(Pointer[T], $data).add($i).deref } }
  my $logical-type = duckdb_vector_get_column_type($vec);
  my $column-type = duckdb_get_type_id($logical-type);
  my $decode = do given $column-type {
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
    when DUCKDB_TYPE_UUID       { -> $d, $i { struct-at(HugeInt)($d, $i).uuid } }
    when DUCKDB_TYPE_VARCHAR    { -> $d, $i { string-t-at($d, $i).decode } }
    when DUCKDB_TYPE_BLOB       { &string-t-at }
    when DUCKDB_TYPE_BIGNUM     { -> $d, $i { bignum-value(string-t-at($d, $i)) } }
    when DUCKDB_TYPE_BIT        { -> $d, $i { bit-string(string-t-at($d, $i)) } }
    when DUCKDB_TYPE_GEOMETRY   { -> $d, $i { DuckWKB.new(wkb => string-t-at($d, $i)).hex } }
    when DUCKDB_TYPE_DATE       { -> $d, $i { struct-at(DuckDate)($d, $i).Date } }
    when DUCKDB_TYPE_TIME       { -> $d, $i { struct-at(DuckTime)($d, $i).DateTime } }
    when DUCKDB_TYPE_TIME_NS    { -> $d, $i { struct-at(DuckTimeNS)($d, $i).DateTime } }
    when DUCKDB_TYPE_TIME_TZ    { -> $d, $i { struct-at(DuckTimeTZ)($d, $i).DateTime } }
    when DUCKDB_TYPE_INTERVAL   { -> $d, $i { struct-at(DuckInterval)($d, $i).Interval } }
    when DUCKDB_TYPE_TIMESTAMP | DUCKDB_TYPE_TIMESTAMP_TZ {
      -> $d, $i { struct-at(DuckTimestamp)($d, $i).DateTime }
    }
    # vectors store these in their own units, not microseconds
    when DUCKDB_TYPE_TIMESTAMP_S  { -> $d, $i { DuckTimestamp.new(micros => at(int64)($d, $i) * 1_000_000).DateTime } }
    when DUCKDB_TYPE_TIMESTAMP_MS { -> $d, $i { DuckTimestamp.new(micros => at(int64)($d, $i) * 1_000).DateTime } }
    when DUCKDB_TYPE_TIMESTAMP_NS { -> $d, $i { DuckTimestamp.new(micros => at(int64)($d, $i) div 1_000).DateTime } }
    when DUCKDB_TYPE_DECIMAL {
      my $scale = duckdb_decimal_scale($logical-type);
      my $value = do given duckdb_decimal_internal_type($logical-type) {
        when DUCKDB_TYPE_SMALLINT { at(int16) }
        when DUCKDB_TYPE_INTEGER  { at(int32) }
        when DUCKDB_TYPE_BIGINT   { at(int64) }
        default                   { -> $d, $i { struct-at(HugeInt)($d, $i).value } }
      }
      -> $d, $i { Rat.new($value($d, $i), 10**$scale) }
    }
    # enums are stored as an index into a dictionary of the enum's values.
    # The logical type is destroyed below, so read the whole dictionary now.
    when DUCKDB_TYPE_ENUM {
      my @dictionary = (^duckdb_enum_dictionary_size($logical-type)).map: {
        my $ptr = duckdb_enum_dictionary_value($logical-type, $_);
        my $value = nativecast(Str, $ptr);
        duckdb_free($ptr);
        $value;
      };
      my &index-at = do given duckdb_enum_internal_type($logical-type) {
        when DUCKDB_TYPE_UTINYINT  { at(uint8) }
        when DUCKDB_TYPE_USMALLINT { at(uint16) }
        default                    { at(uint32) }
      }
      -> $d, $i { @dictionary[ index-at($d, $i) ] }
    }
    # lists are a parent vector of duckdb_list_entry (offset, length) pairs
    # whose elements live in a child vector, at the given offsets.
    # A map is a list of structs with a key and a value; it is returned as a
    # list of pairs, which keeps the order and the types of the keys.
    when DUCKDB_TYPE_LIST | DUCKDB_TYPE_MAP {
      my $is-map = $column-type == DUCKDB_TYPE_MAP;
      my $child-vec = duckdb_list_vector_get_child($vec);
      my $child-data = duckdb_vector_get_data($child-vec);
      my $child-validity = duckdb_vector_get_validity($child-vec);
      my &child-decode = self!chunk-decoder($child-vec, $label);
      -> $data, $i {
        my $entry = struct-at(DuckListEntry)($data, $i);
        my @elements = (^$entry.length).map: {
          my $k = $entry.offset + $_;
          vector-valid($child-validity, $k) ?? child-decode($child-data, $k) !! Nil;
        };
        @elements = @elements.map({ .<key> => .<value> }) if $is-map;
        @elements;
      }
    }
    # fixed size arrays have no per-row entries: row $i is the $size elements
    # of the child vector starting at $i * $size
    when DUCKDB_TYPE_ARRAY {
      my $size = duckdb_array_type_array_size($logical-type);
      my $child-vec = duckdb_array_vector_get_child($vec);
      my $child-data = duckdb_vector_get_data($child-vec);
      my $child-validity = duckdb_vector_get_validity($child-vec);
      my &child-decode = self!chunk-decoder($child-vec, $label);
      -> $, $i {
        my @elements = (^$size).map: {
          my $k = $i * $size + $_;
          vector-valid($child-validity, $k) ?? child-decode($child-data, $k) !! Nil;
        };
        @elements;
      }
    }
    # unions are stored as a struct whose first child is a (uint8) tag vector
    # selecting which of the other children (the members) holds the value of
    # each row.  The value is returned without the name of the member.
    when DUCKDB_TYPE_UNION {
      my $tag-vec = duckdb_struct_vector_get_child($vec, 0);
      my $tag-data = duckdb_vector_get_data($tag-vec);
      my $tag-validity = duckdb_vector_get_validity($tag-vec);
      my @members = (^duckdb_union_type_member_count($logical-type)).map: {
        my $member-vec = duckdb_struct_vector_get_child($vec, $_ + 1);
        %(
          :data(duckdb_vector_get_data($member-vec)),
          :validity(duckdb_vector_get_validity($member-vec)),
          :decode(self!chunk-decoder($member-vec, $label)),
        )
      };
      -> $, $i {
        if vector-valid($tag-validity, $i) {
          my %member = @members[ at(uint8)($tag-data, $i) ];
          vector-valid(%member<validity>, $i) ?? %member<decode>(%member<data>, $i) !! Nil;
        } else {
          Nil
        }
      }
    }
    # structs have one child vector per field; row $i of the struct is
    # row $i of each of the child vectors
    when DUCKDB_TYPE_STRUCT {
      my @fields = (^duckdb_struct_type_child_count($logical-type)).map: {
        my $name-ptr = duckdb_struct_type_child_name($logical-type, $_);
        my $name = cstring-at($name-ptr);
        duckdb_free($name-ptr);
        my $child-vec = duckdb_struct_vector_get_child($vec, $_);
        %(
          :name($name),
          :data(duckdb_vector_get_data($child-vec)),
          :validity(duckdb_vector_get_validity($child-vec)),
          :decode(self!chunk-decoder($child-vec, $label)),
        )
      };
      -> $, $i {
        my %struct;
        for @fields -> %field {
          %struct{ %field<name> } = vector-valid(%field<validity>, $i)
            ?? %field<decode>(%field<data>, $i)
            !! Nil;
        }
        %struct
      }
    }
    default {
      my %types = DuckDBType.enums.invert.Hash;
      warning "unsupported column type: $column-type ({%types{$column-type} }) for $label";
      -> $, $ { Nil }
    }
  }
  duckdb_destroy_logical_type($logical-type);
  $decode;
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

LIST columns are returned as arrays of the decoded elements, and STRUCT columns
as hashes of their fields.  These are decoded recursively, so nested types
(e.g. a list of structs) are supported, as are other types (including
GEOMETRY) inside a list or struct.

Other types are returned as follows:

=item UUID: a C<Str> in the canonical 8-4-4-4-12 form.
=item TIME_TZ: a C<DateTime> on 1970-01-01, with the stored UTC offset as its C<timezone>.
=item INTERVAL: an C<Interval> with C<months>, C<days> and C<micros> (and C<seconds>).  These are kept apart since months and days vary in length.
=item BIGNUM: an C<Int>.
=item BIT: a C<Str> of C<0>s and C<1>s.
=item ENUM: the C<Str> value.
=item MAP: an array of C<Pair>s, which keeps the order and the types of the keys.
=item ARRAY (fixed size): an array of the decoded elements, like a LIST.
=item UNION: the value of the member that is set (the name of the member is not returned).

Unsupported types are currently treated as C<Nil>.  These will emit a warning, if diagnostics
are enabled.  Set C<DUCKIE_DEBUG> to send warnings to stderr (or use C<Log::Async> and add
a tap).

=end pod

