xquery version "3.0";
try{
    let $source  := request:get-parameter("source","/db/apps/cr-xq-mets")
    let $target-base := request:get-parameter("target-base","/opt/repo")
(:    let $cr-xq-mets-log :=  file:sync($source, $target-base||"/cr-xq-mets/src", ()) :)
(:    let $cs-xsl-log :=  file:sync($source||"/modules/cs-xsl", $target-base||"/cs-xsl", ()) :)
(:    return ($cr-xq-mets-log, $cs-xsl-log):)
    let $cr-project-abacus :=  file:sync("/db/cr-projects/abacus", $target-base||"/cr-projects/abacus-mets", xs:dateTime("2014-05-01T10:10:00")) 
    return $cr-project-abacus
    
    
} catch * {
    let $log := util:log("ERROR", ($err:code, $err:description) )
    return <ERROR>{($err:code, $err:description)}</ERROR>
(:    let $col := "/db/apps/cr-xq-dev0913":)
(:    let $target := "/opt/repo/SADE/src":)
(:    return file:sync($col, $target, ())  :)
}   