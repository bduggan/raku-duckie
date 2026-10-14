#!/usr/bin/env raku

use Duckie;

my $db = Duckie.new;
my $res = $db.query: 'install spatial; load spatial;';
$res = $db.query(q:to/SQL/);
select st_geomfromgeojson('{"coordinates":[-75.189743,39.962082],"type":"Point"}') as pt
SQL
say $res.rows[0]<pt>
