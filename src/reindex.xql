xquery version "3.0";
let $login:=xmldb:login("/db","daniel","Tj=)j;a[-Ue!Ae")
let $cr-project:="abacus"
let $db:="/db"
let $cr-data-path:="/db/cr-data"
let $cr-projects-path:="/db/cr-projects"
let $p:=($db,$cr-data-path,$cr-projects-path)
return
    xmldb:reindex($p[3])