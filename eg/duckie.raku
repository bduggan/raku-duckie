#!/usr/bin/env raku

use Duckie;

my $db = Duckie.new;
with $db.query("select 1 as the_loneliest_number") -> $result {
  say $result.column-data('the_loneliest_number'); # [1]
} else {
  say "Query failed: $_";
}

$db.query('install httpfs');
$db.query('load httpfs');
my $res = $db.query(q:to/SQL/);
select * from
'https://gist.githubusercontent.com/bduggan/35070194b86c6dfe79de59a323a4c008/raw/e01b5cca0a394a72db9ed509cd13b6c42ad0288b/gistfile1.csv' x
left join 'https://gist.githubusercontent.com/bduggan/35070194b86c6dfe79de59a323a4c008/raw/e01b5cca0a394a72db9ed509cd13b6c42ad0288b/gistfile1.csv' y
on x.a = y.a
SQL

say $res.rows.raku;
