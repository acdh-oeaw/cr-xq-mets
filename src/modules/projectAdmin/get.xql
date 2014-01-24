xquery version "3.0";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "xml";
declare option output:media-type "text/xml";

import module namespace project="http://aac.ac.at/content_repository/project" at "../../core/project.xqm";
import module namespace projectAdmin="http://aac.ac.at/content_repository/projectAdmin" at "projectAdmin.xqm";

let $project-pid := request:get-parameter("project-pid", ""),
	$entity :=      request:get-parameter("entity","")

let $function := projectAdmin:function-by-form($entity,"getter")
return 
    if (exists($function))
    then $function($project-pid)
    else <false/>