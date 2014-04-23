xquery version "3.0";

import module namespace cql = "http://exist-db.org/xquery/cql" at "cql.xqm";
import module namespace query  = "http://aac.ac.at/content_repository/query" at "query.xqm";
import module namespace index = "http://aac.ac.at/content_repository/index" at "../../core/index.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "../../core/config.xqm"; 
import module namespace repo-utils="http://aac.ac.at/content_repository/utils" at "../../core/repo-utils.xqm";

import module namespace request="http://exist-db.org/xquery/request";

(:let $cql := request:get-parameter("cql", "title any Wien and date < 1950"):)
 
 let $cql := 'term1'
 let $xcql := cql:cql-to-xcql($cql)
 let $project-pid := 'abacus2'
 let $config :=  config:config($project-pid) 
let $model := map { "config" := $config, "project" := $project-pid }
 let $map := index:map($project-pid)
 let $xpath := cql:cql-to-xpath($xcql, $project-pid)
(:return $xcql:)
let $index-key := $xcql//index/text(),        
        $index := index:index-from-map($index-key ,$map),
        $index-type := ($index/xs:string(@type),'')[1]
(:    return $index-key:)

let $data-collection := repo-utils:context-to-collection($project-pid, $config)

(:return query:execute-query($xpath,$data-collection, $project-pid ):)
 return util:eval(concat("($data)//", $xpath))


  
