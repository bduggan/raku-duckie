#!/usr/bin/env raku

use Duckie;

my \db = Duckie.new;

with db.query('select ? as one',1) -> $res {
  .say for $res.rows;
} else {
  say 'fail';
}

with db.query('select 12 where 22 = $num',num => 1) -> $res {
  .say for $res.rows;
} else {
  say 'fail';
  .say;
}

# prepare once, execute multiple times with positional params
my $ps = db.prepare('select ? as val, ? as doubled');
for 1..3 -> $n {
  .say for $ps.execute($n, $n * 2).rows;
}

# prepare once, execute multiple times with named params
my $ps2 = db.prepare('select $x + $y as sum');
for (1,2), (10,20), (100,200) -> ($x, $y) {
  .say for $ps2.execute(:$x, :$y).rows;
}
