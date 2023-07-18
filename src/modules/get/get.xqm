xquery version "3.0";

module namespace get = "http://aac.ac.at/content_repository/get";
import module namespace config="http://exist-db.org/xquery/apps/config" at "../../core/config.xqm";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at "../../core/repo-utils.xqm";
import module namespace resource="http://aac.ac.at/content_repository/resource" at "../../core/resource.xqm";

(:~ @param $type 'data' | 'entry' | 'metadata' | 'download' | 'redirect'; default: 'redirect'  :)
(: download: to download files referenced in fileGrp @use = 'download' :)
(: redirect: redirect to permalink of application view :)
declare variable $get:types := ("data","metadata", "entry", "download", "redirect");
declare variable $get:default-type := "redirect";

declare variable $get:subtypes := map{
                                    "metadata" := ($resource:mdtypes, $resource:othermdtypes) 
                                  };

declare function get:parse-relPath($path as xs:string, $project as xs:string) as map() {
(:    let $log := util:log-app("DEBUG", $config:app-name, "get:parse-relPath("||$path||","||$project||")"):)
    let $path-components := tokenize($path,'/')[.!='' and .!="get"]
    (:let $log := for $c at $pos in $path-components return util:log-app("DEBUG", $config:app-name, $pos||": "||$c):)
    (:~ $id of a project, resource or resourcefragment :)
    (: if the 1st path component is already a type keyword, the user asks for the whole project:)
    let $id :=  if ($path-components[1] = ("data","metadata", "entry"))
                then $project
                else $path-components[1]
    
    let $type := 
        if ($path-components[1] = $get:types)
        then ($path-components[1],$get:default-type)[1][.=$get:types]
        else ($path-components[2],$get:default-type)[1][.=$get:types]
        
    let $subtype := 
        if ($type = $get:types)
        then
            if ($path-components[1] = $get:types)
            then $path-components[2][. = map:get($get:subtypes,$type)]
            else $path-components[3][. = map:get($get:subtypes,$type)]
        else ()

    return map{
        "path-components" := $path-components,
        "id" := $id,
        "type" := $type,
        "subtype" := $subtype
    }
};