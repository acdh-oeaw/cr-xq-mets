xquery version "3.0";

import module namespace fcs="http://clarin.eu/fcs/1.0" at "../fcs/fcs.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "../../core/config.xqm"; 
import module namespace toc = "http://aac.ac.at/content_repository/toc" at "../../core/toc.xqm";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at  "../../core/repo-utils.xqm";
import module namespace project="http://aac.ac.at/content_repository/project" at "../../core/project.xqm";
import module namespace index="http://aac.ac.at/content_repository/index" at "../../core/index.xqm";
import module namespace gen="http://aac.ac.at/content_repository/generate-index" at "generate-index-functions.xqm";
import module namespace ixfn = "http://aac.ac.at/content-repository/projects-index-functions/" at "index-functions.xqm";

declare namespace cr="http://aac.ac.at/content_repository";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace mets = "http://www.loc.gov/METS/";
declare namespace xlink = "http://www.w3.org/1999/xlink";
declare namespace sru = "http://www.loc.gov/zing/srw/";

let $x-context := "abacus",
    $index-key := "placeName",
    $config:=config:project-config($x-context),
    $subsequenceSize := 20000,
    $data-collection := repo-utils:context-to-collection($x-context, $config)

 (:~ generate index functions for one project  :)
(: return gen:generate-index-functions($x-context):)
  
  (:~ generate the top level switch for dispatching to project-specific index functions :)
(: return gen:register-project-index-functions() :)


(:~ test various stages of the index generation :)
(: let $nodes-match-ixfn := ixfn:apply-index ($data-collection, $index-key,$x-context,'match')
    let $nodes-match-main := index:apply-index ($data-collection, $index-key,$x-context,'match')
 return (count($nodes-match-ixfn), count($nodes-match-main)) :)

(: gets the base data for given index  :)
(:    let $nodes := index:apply-index($data-collection, $index-key,$x-context,()) 
 let $terms := fcs:term-from-nodes(subsequence($nodes,1, $subsequenceSize), 'size',$index-key,$x-context) return count($terms//sru:term) :)
 let $scan :=  fcs:do-scan-default($index-key,$x-context,'text', $config) return $scan 


 (: the core part of fcs:term-from-nodes :: :)
 (: let $termlabels := project:get-termlabels($x-context, $index-key)
 let $nodes := index:apply-index($data-collection, $index-key,$x-context,())
     let $terms  :=  for $n in subsequence($nodes,1,$subsequenceSize)
                    let $term-value := index:apply-index($n,$index-key,$x-context,'match-only')
                    let $term-label := fcs:term-to-label($term-value,$index-key,$x-context,$termlabels)
                    return $term-label
return count($terms) :)
  
  