xquery version "3.0";

declare namespace cr="http://aac.ac.at/content_repository";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace mets = "http://www.loc.gov/METS/";
  
import module namespace repo-utils="http://aac.ac.at/content_repository/utils" at "core/repo-utils.xqm";
import module namespace fcs="http://clarin.eu/fcs/1.0" at "modules/fcs/fcs.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "core/config.xqm"; 
import module namespace project = "http://aac.ac.at/content_repository/project" at "core/project.xqm";
import module namespace resource="http://aac.ac.at/content_repository/resource";
import module namespace rf = "http://aac.ac.at/content_repository/resourcefragment" at "core/resourcefragment.xqm";
import module namespace wc="http://aac.ac.at/content_repository/workingcopy" at "core/wc.xqm";
import module namespace lt = "http://aac.ac.at/content_repository/lookuptable" at "core/lookuptable.xqm";
import module namespace toc = "http://aac.ac.at/content_repository/toc" at "core/toc.xqm";

import module namespace index = "http://aac.ac.at/content_repository/index" at "core/index.xqm";

let $project-pid := 'abacus'
let $resource-pid := 'abacus.5'
let $temp-file-path := "/db/cr-data/_temp/Abraham-Loesch_Wienn_persKeys-rm-toks-ids-pos.xml"

let $resource-label := 'Lösch Wienn'
let $toc-xpath := "//div[@type='chapter']"
let $toc-type := 'chapter'                
 
(:return project:new($project-pid):)
(: return index:store-xconf($project-pid ):)
(:return  repo-utils:mkcol("/db/cr-projects", "abacus"):)

(: return resource:generate-pid($project-pid):)
  
(:let  $resource-pid := resource:new-with-label(doc($temp-file-path),$project-pid, $resource-label):)
(: return $resource-pid:)
(:  :)
(: let  $resource-pid:= 'abacus2.3':)
(: return resource:get($resource-pid, $project-pid):)
(: return resource:label($resource-pid, $project-pid):)
(:return resource:label(document {<cr:data>{$resource-label}</cr:data>},$resource-pid,$project-pid):)
 
(: return index:index-as-xpath('resourcefragment-pid',$project-pid,'label-only'):)
(:return wc:get-data($resource-pid,$project-pid):)
(:let $rf-gen :=  rf:generate($resource-pid, $project-pid):)
 
let $lt-gen :=  lt:generate($resource-pid, $project-pid)

let $toc-gen :=  toc:generate(('front','chapter'),  $resource-pid, $project-pid)
 
(: return ($resource-pid, $rf-gen, $lt-gen, $toc-gen):)
 
(:return resource:get-toc-resolved($project-pid):)
 
(: return ($resource-pid, $rf-gen):)
  return ($lt-gen, $toc-gen)
 