xquery version "3.0";

(:
The MIT License (MIT)

Copyright (c) 2016 Austrian Centre for Digital Humanities at the Austrian Academy of Sciences

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE
:)

import module namespace repo-utils="http://aac.ac.at/content_repository/utils" at "core/repo-utils.xqm";
import module namespace project="http://aac.ac.at/content_repository/project" at "core/project.xqm";
import module namespace resource="http://aac.ac.at/content_repository/resource" at "core/resource.xqm";
import module namespace rf="http://aac.ac.at/content_repository/resourcefragment" at "core/resourcefragment.xqm";
import module namespace facs="http://aac.ac.at/content_repository/facs" at "core/facs.xqm";
import module namespace wc="http://aac.ac.at/content_repository/workingcopy" at "core/wc.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "core/config.xqm";
import module namespace cr="http://aac.ac.at/content_repository" at "core/cr.xqm";
import module namespace lt="http://aac.ac.at/content_repository/lookuptable" at "core/lt.xqm";
import module namespace toc="http://aac.ac.at/content_repository/toc" at "core/toc.xqm";

declare namespace cmd="http://www.clarin.eu/cmd/";

declare namespace mets = "http://www.loc.gov/METS/";
declare namespace fcs = "http://clarin.eu/fcs/1.0";
declare namespace xlink="http://www.w3.org/1999/xlink";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare function local:register-all-CMDI-metadata($project-pid as xs:string) {
for $rid in project:list-resource-pids($project-pid)
   let $master := resource:master($rid,$project-pid),
       $masterURI := base-uri($master),
       $masterName := util:document-name($master),
       $md := doc(resolve-uri('metadata/CMDI/', $masterURI)||$masterName)
   return resource:dmd($rid,$project-pid,$md,"CMDI")
};

let $rid := "abacus.3",
    $project-pid := "abacus",
    $mappings-used-for-toc := ('front','chapter','back','body','index','n','preface','dedication'), 
    $resource-label := "Grosse Todten Bruderschaft"

let $data  := doc("/db/cr-data/abacus/Abraham-Todten_Bruderschaft.xml")

(:~ 1.  uncomment this to add a new resource  :)        
(:let  $resource-pid := resource:new-with-label($data, $project-pid, $resource-label) return $resource-pid :)

(:~ 2. use this to generate/refresh all auxiliary files for given resource :)
(:let $gen-aux := resource:refresh-aux-files($mappings-used-for-toc, $resource-pid, $project-pid) return $gen-aux:)

(: uncomment this to refresh aux-files for all resources :)
for $rid in project:list-resource-pids($project-pid)
    return resource:refresh-aux-files($mappings-used-for-toc, $rid, $project-pid) 
    
    
(:~ alternatively you can do it one by one:  :)
(: let $wc-gen :=  wc:generate($resource-pid, $project-pid) return $wc-gen:)
(: let $lt-gen :=  lt:generate($resource-pid, $project-pid) return $lt-gen:)
(: let $toc-gen :=  toc:generate($mappings-used-for-toc, $rid, $project-pid) return ($rid, $toc-gen) :)

(:~ 3. if you have links to facsimile/images in the data you can use this to extract them and write them in the project-configuration  :)
(:let $gen-facs := facs:generate($resource-pid,$project-pid):)


(:~ 4. add a metadata record for given resource :)
(:Register the teiHeader:)
(:Register CMDI:)
(:return local:register-all-CMDI-metadata($project-pid):)
 

(:~ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 :  Below are some debugging tests you don't need in normal workflow  :)
 
(:return ($resource-pid, $gen-aux, $gen-facs):)
(:  return ($lt-gen, $toc-gen):)
(: return index:store-xconf($project-pid ):)

(:let $master:=  resource:master($resource-pid,$project-pid),:)
(:        $master_filename:=  util:document-name($master):)
(:        return $master_filename:)


(:return resource:dmd($resource-pid,$project-pid):)

(:return resource:dmd("CMDI",$resource-pid,$project-pid):)

 (:return resource:set-handle("data",$resource-pid,$project-pid):)
(:return resource:label($resource-pid,$project-pid):)

(: return resource:dmd2dc($resource-pid, $project-pid):)
