xquery version "3.0";

import module namespace config="http://exist-db.org/xquery/apps/config" at "../../core/config.xqm";
import module namespace viewer = "http://sade/viewer" at "viewer.xqm" ;

let $project := request:get-parameter("project","")

let $config := map { "config" := config:config($project)}
(:~ internal resource identfier :)
let $id := request:get-parameter("resource-id","")
let $format := request:get-parameter("format","xml")
					
return viewer:display($config, $id, $format)
					

