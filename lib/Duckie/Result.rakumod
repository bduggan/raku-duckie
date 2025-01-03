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

#| Returns the names of the columns in the result set
method column-names(--> List) {
  return @!column-names if @!column-names;
  @!column-names := eager (^self.column-count).map: { duckdb_column_name($!res, $_) };
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
  my $data = duckdb_column_data($!res, $c);
  my $null-mask = nativecast(Pointer[int8], duckdb_nullmask_data($!res, $c));
  my $column-type = duckdb_column_type($!res, $c);
  my %types = DuckDBType.enums.invert.Hash;
  my $count = duckdb_row_count($!res);
  my sub val-at($v,$n) {
    $v.add($n).deref;
  }

  without $data {
    warning "no data for column $c ({self.column-names[ $c ]}) of type { %types{$column-type} }";
    my @ret = (^$count).map: { Nil }
    return @ret;
  }
  my $logical-type = duckdb_column_logical_type($!res, $c);
  my @ret;
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
    when DUCKDB_TYPE_BOOLEAN {
      my $values = nativecast(Pointer[uint8], $data);
      @ret = (^$count).map: { $null-mask[$_] ?? Nil !! so val-at($values,$_) };
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
    when | DUCKDB_TYPE_TIMESTAMP
         | DUCKDB_TYPE_TIMESTAMP_S
         | DUCKDB_TYPE_TIMESTAMP_MS
         | DUCKDB_TYPE_TIMESTAMP_NS {
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
  my @rows = [Z] @!all-column-data;
  return @rows if $arrays;
  @rows.map: { %( self.column-names Z=> @$_ ) }
}

method DESTROY {
  with $!res {
    debug "destroying result";
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

