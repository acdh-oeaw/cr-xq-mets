xquery version "3.0";

import module namespace config="http://exist-db.org/xquery/apps/config" at "../../core/config.xqm";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at "../../core/repo-utils.xqm";
import module namespace viewer = "http://sade/viewer" at "viewer.xqm" ;

let $project := request:get-parameter("project","")

let $config-map := config:config-map($project) 

(:~ process the relative path; expecting one or two components:
first component $id, second optional: $type :)
let $path := request:get-parameter("rel-path",""),
    $path-components := tokenize($path,'/')[.!='' and .!="get"]

(:~ $id of a project, resource or resourcefragment :)
(: if the 1st path component is already a type keyword, the user asks for the whole project:)
let $id :=  if ($path-components[1] = ("data","metadata", "entry"))
            then $project
            else $path-components[1]
            
let $parse-id := repo-utils:parse-x-context($id,$config-map)

(:~ @param $type 'data' | 'entry' | 'metadata' ; default: 'entry'  :)
let $type := 
        if ($id = $project)
        then ($path-components[1],'entry')[1]
        else ($path-components[2],'entry')[1],
    $subtype := 
        if ($id = $project)
        then $path-components[2]
        else $path-components[3]

(: content negotiation
text/html -> human readable 
application/x-cmdi+xml -> machine processable 
@seeAlso http://www.clarin.eu/sites/default/files/CE-2013-0106-pid-task-force.pdf
:)
let $header-accept := request:get-header("Accept")
let $accept-format := if (contains($header-accept,'text/html')) then "htmlpage" else "xml" 
let $format := (request:get-parameter("x-format",if ($type = "data") then "xml" else $accept-format))[1]
(:return <debug>{$header-accept||" -- format: "||$format}</debug>:)
let $debug := <a>
        <path-components>{
            for $c at $pos in $path-components 
            return <path-component n="{$pos}">{$path-components[$pos]}</path-component>
        }</path-components>
        <project>{$project}</project>
        <id>{$id}</id>
        <type>{$type}</type>
        <subtype>{$subtype}</subtype>
        <format>{$format}</format>
        <context-parsed>{for $i in $parse-id return for $k in map:keys($i) return $k||":"||map:get($i,$k)}</context-parsed> 
       </a>
let $log := util:log-app("INFO",$config:app-name,$debug)
return viewer:display($config-map, $id, map:get($parse-id[1],"project-pid"), $type, $subtype, $format)