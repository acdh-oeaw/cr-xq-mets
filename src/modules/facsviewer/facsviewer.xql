xquery version "3.0";

import module namespace config="http://exist-db.org/xquery/apps/config" at "../../core/config.xqm";
import module namespace facs="http://www.oeaw.ac.at/icltt/cr-xq/facsviewer" at "facsviewer.xqm";

(: handles requests to facsimile files :)

let $filename := request:get-parameter("exist-resource","")
let $project := request:get-parameter("project","")
let $config := map { "config" := config:config($project)}


let $file-path:=facs:filename-to-path($filename,$project,$config) 


return response:redirect-to($file-path)
					

