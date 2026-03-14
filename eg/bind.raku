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
