xquery version "3.0";
module namespace cr="http://aac.ac.at/content_repository";

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace repo-utils="http://aac.ac.at/content_repository/utils" at "repo-utils.xqm";

declare namespace mets = "http://www.loc.gov/METS/";
declare namespace mods="http://www.loc.gov/mods/v3";
declare namespace metsrights = "http://cosimo.stanford.edu/sdr/metsrights/";
declare namespace sm="http://exist-db.org/xquery/securitymanager";

declare namespace rest="http://exquery.org/ns/restxq";



declare
    %rest:GET
    %rest:path("/cr_xq")
function cr:project-pids(){
    let $projects:=collection(config:path("projects"))//mets:mets[@TYPE eq "cr-xq project"]
    return
        <cr:projects n="{count($projects)}">{
            for $p in $projects
            return <cr:project project-pid="{$p/@OBJID}">{$p//mets:dmdSec[@ID eq $config:PROJECT_DMDSEC_ID]}</cr:project>
        }</cr:projects>
};