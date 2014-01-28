xquery version "3.0";
let $col    := request:get-parameter("col","/db/apps/cr-xq-dev0913"),
    $target :=  request:get-parameter("target","/opt/repo/SADE/src")
return file:sync($col, $target, ())