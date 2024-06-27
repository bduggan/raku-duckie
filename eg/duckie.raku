#!/usr/bin/env raku

use Duckie;

my $db = Duckie.new;
with $db.query("select 1 as the_loneliest_number") -> $result {
  say $result.column-data('the_loneliest_number'); # [1]
} else {
  say "Query failed: $_";
}
