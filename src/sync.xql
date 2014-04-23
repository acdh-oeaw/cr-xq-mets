xquery version "3.0";
try{
    let $col := request:get-parameter("col","/db/apps/cr-xq-dev0913")
    let $target := request:get-parameter("target","/opt/repo/SADE/src")
    return file:sync($col, $target, ()) 
    
} catch * { 
    let $col := "/db/apps/cr-xq-dev0913"
    let $target := "/opt/repo/SADE/src"
    return file:sync($col, $target, ())  
}