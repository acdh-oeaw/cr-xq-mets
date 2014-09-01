xquery version "3.0";

declare namespace cr="http://aac.ac.at/content_repository";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace mets = "http://www.loc.gov/METS/";
declare namespace xlink = "http://www.w3.org/1999/xlink";
declare namespace sru = "http://www.loc.gov/zing/srw/";

(:import module namespace repo-utils="http://aac.ac.at/content_repository/utils" at "core/repo-utils.xqm";:)
import module namespace fcs="http://clarin.eu/fcs/1.0" at "modules/fcs/fcs.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "core/config.xqm"; 
import module namespace toc = "http://aac.ac.at/content_repository/toc" at "core/toc.xqm";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at  "core/repo-utils.xqm";
import module namespace project="http://aac.ac.at/content_repository/project" at "core/project.xqm";


let $resource-pid := "abacus2.5",   
    $x-context := "abacus",
    $indexes := "chapter",
    $config:=config:project-config($x-context)
    let $data-collection := repo-utils:context-to-collection($x-context, $config)

(: return $data-collection//(div[@type='chapter']|front|back)[data(@cr:id)='abacus.3.d1e74044']:)

 (: collection($projects)//mets:div[@ID = normalize-space($x-context)]:)
 
(:return $config:cr-config//config:path:)
(: return project:list-resources-resolved($x-context):)
  
(: return $data-collection//persName:)
(:    let $labels := project:get-termlabels($x-context):)
    let $term := 'city'
(:    return xs:string(($labels//term[@key=$term][ancestor::*/@key='placeType'],$term)[1]):)
(: return  fcs:term-to-label('city', 'placeType', $x-context):)
 
(: return (config:path("projects"),project:path($x-context,'home'), config:param-value($config,'project-dir')):)

