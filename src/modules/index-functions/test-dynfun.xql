xquery version "3.0";

import module namespace dynix="http://cr-xq/dynix" at "dynix.xqm";
import module namespace repo-utils="http://aac.ac.at/content_repository/utils" at "/db/apps/cr-xq-mets/core/repo-utils.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "/db/apps/cr-xq-mets/core/config.xqm"; 
import module namespace project = "http://aac.ac.at/content_repository/project" at "/db/apps/cr-xq-mets/core/project.xqm"; 
 import module namespace index = "http://aac.ac.at/content_repository/index" at "/db/apps/cr-xq-mets/core/index.xqm";

import module namespace fcs = "http://clarin.eu/fcs/1.0" at "/db/apps/cr-xq-mets/modules/fcs/fcs.xqm";
import module namespace handle = "http://aac.ac.at/content_repository/handle" at "/db/apps/cr-xq-mets/modules/resource/handle.xqm";
import module namespace cmdcheck = "http://clarin.eu/cmd/check" at "/db/apps/cr-xq-mets/modules/cmd/cmdcheck.xqm";
declare namespace cmd = "http://www.clarin.eu/cmd/";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

let $project-pid := 'abacus'
let $config := config:config($project-pid)
let $index := 'pos'
(:let $context-parsed := repo-utils:parse-x-context($project-pid,$config):)
(:let $data-path := repo-utils:context-to-collection-path($project-pid, $config ):)
 let $path := index:index-as-xpath( $index,$project-pid)
    let $data := repo-utils:context-to-data($project-pid,$config),
(:    $nodes := subsequence(util:eval("$data//"||$path),1,$fcs:maxScanSize):)
  $nodes := subsequence(dynix:apply-index($data, $index,$project-pid,()),1,$fcs:maxScanSize)

(:return dynix:apply-index($data[1],'pos', $project-pid,()):)
(: return fcs:do-scan-default-dynix('pos', $project-pid, 'text', $config):)
(: return count($nodes):)
 return fcs:term-from-nodes-dynix($nodes, 'text', $index, $project-pid)
 
 