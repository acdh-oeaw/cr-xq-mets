xquery version "3.0";

import module namespace config="http://exist-db.org/xquery/apps/config" at "../../core/config.xqm";
import module namespace viewer = "http://sade/viewer" at "viewer.xqm" ;

let $project := request:get-parameter("project","")

let $config-map := config:config-map($project)
(:~ process the relative path; expecting one or two components:
first component $id, second optional: $type :)
let $path := request:get-parameter("rel-path",""),
    $path-components := tokenize($path,'/')[.!='']

(:~ $id of a project, resource or resourcefragment :)
(: if the 1st path component is already a type keyword, the user asks for the whole project:)
let $id :=  if ($path-components[1] = ("data","metadata", "entry"))
            then $project
            else $path-components[1] 

(:~ @param $type 'data' | 'entry' | 'metadata' ; default: 'entry'  :)
let $type := 
        if ($id = $project)
        then ($path-components[1],'entry')[1]
        else ($path-components[2],'entry')[1],
    $subtype := 
        if ($id = $project)
        then $path-components[2]
        else $path-components[3]
        
let $format := request:get-parameter("x-format","xml")
					
return viewer:display($config-map, $id, $project, $type, $subtype, $format)
(:return <a>{($id, $type)}</a>:)
					