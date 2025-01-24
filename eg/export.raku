#!/usr/bin/env raku

use Duckie 'db', '-debug';

say db.query("select 1 as the_loneliest_number").rows;
