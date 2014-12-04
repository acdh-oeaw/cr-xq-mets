xquery version "3.0";

declare namespace cr="http://aac.ac.at/content_repository";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace mets = "http://www.loc.gov/METS/";
declare namespace xlink = "http://www.w3.org/1999/xlink";
declare namespace sru = "http://www.loc.gov/zing/srw/";

import module namespace fcs="http://clarin.eu/fcs/1.0" at "modules/fcs/fcs.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "core/config.xqm"; 
import module namespace toc = "http://aac.ac.at/content_repository/toc" at "core/toc.xqm";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at  "core/repo-utils.xqm";
import module namespace project="http://aac.ac.at/content_repository/project" at "core/project.xqm";
import module namespace index="http://aac.ac.at/content_repository/index" at "core/index.xqm";
import module namespace ltb = "http://aac.ac.at/content_repository/lookuptable" at "core/lookuptable.xqm";
import module namespace ixgen="http://aac.ac.at/content_repository/generate-index" at "modules/index-functions/generate-index-functions.xqm";
import module namespace ixfn = "http://aac.ac.at/content-repository/projects-index-functions/" at "modules/index-functions/index-functions.xqm";

let $project-pid := "tunico",
    $resource-pid := $project-pid||".1",
    $config:=config:project-config($project-pid)
    
(:return ixgen:generate-index-functions($project-pid):)
(:return xmldb:reindex(project:path($project-pid,"workingcopies")):)
(:return index:store-xconf($project-pid ):)
(:return ltb:dump($resource-pid, $project-pid):)
(:return :)