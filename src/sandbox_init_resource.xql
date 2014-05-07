xquery version "3.0";

import module namespace repo-utils="http://aac.ac.at/content_repository/utils" at "core/repo-utils.xqm";
import module namespace project="http://aac.ac.at/content_repository/project" at "core/project.xqm";
import module namespace resource="http://aac.ac.at/content_repository/resource" at "core/resource.xqm";
import module namespace rf="http://aac.ac.at/content_repository/resourcefragment" at "core/resourcefragment.xqm";
import module namespace facs="http://aac.ac.at/content_repository/facs" at "core/facs.xqm";
import module namespace wc="http://aac.ac.at/content_repository/workingcopy" at "core/wc.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "core/config.xqm";
import module namespace cr="http://aac.ac.at/content_repository" at "core/cr.xqm";

declare namespace cmd="http://www.clarin.eu/cmd/";

declare namespace mets = "http://www.loc.gov/METS/";
declare namespace fcs = "http://clarin.eu/fcs/1.0";
declare namespace xlink="http://www.w3.org/1999/xlink";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

let $resource-pid := "abacus.3",
    $project-pid := "abacus"

(:  : let $resource-pid := "dict-gate.3",
    $project-pid := "dict-gate" :)

(:let $md := doc("/db/cr-data/_tmp/dict-gate/dict-gate.cmd.xml")/*:)
(: let $md := doc("/db/cr-data/_temp/abacus_md/TEIHDR/md-abacus.9.xml"):)
let $data  := doc("/db/cr-data/_tmp/Abraham-Loesch_Wienn_persKeys-rm-toks-ids-pos.xml")


(:let  $resource-pid := resource:new-with-label(doc($temp-file-path),$project-pid, $resource-label):)
(: return $resource-pid:)


(:let $rf-gen :=  rf:generate($resource-pid, $project-pid):)
(: :)
(:let $lt-gen :=  lt:generate($resource-pid, $project-pid):)
(::)
(:let $toc-gen :=  toc:generate(('front','chapter'),  $resource-pid, $project-pid):)
(: :)
(: return ($resource-pid, $rf-gen):)
 
(:return resource:get-toc-resolved($project-pid):)
 
(::)
let $gen-aux := resource:refresh-aux-files($resource-pid, $project-pid)
(::)
(:let $gen-facs := facs:generate($resource-pid,$project-pid):)
 return $gen-aux
(:return ($resource-pid, $gen-aux, $gen-facs):)
(:  return ($lt-gen, $toc-gen):)



(:return resource:dmd($resource-pid,$project-pid):)

(:return resource:dmd($resource-pid,$project-pid,$md,"TEIHDR",true()):)
(:return resource:dmd("CMDI",$resource-pid,$project-pid):)

 (:return resource:set-handle("data",$resource-pid,$project-pid):)
(:return resource:label($resource-pid,$project-pid):)

(: return resource:dmd2dc($resource-pid, $project-pid):)
