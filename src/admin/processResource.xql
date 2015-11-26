xquery version "3.0";
declare namespace request="http://exist-db.org/xquery/request";
declare option exist:serialize "method=xml media-type=text/xml indent=yes";

import module namespace config="http://exist-db.org/xquery/apps/config" at "../core/config.xqm"; 
import module namespace ixgen="http://aac.ac.at/content_repository/generate-index" at "../modules/index-functions/generate-index-functions.xqm";
import module namespace project = "http://aac.ac.at/content_repository/project" at "../core/project.xqm";
import module namespace resource="http://aac.ac.at/content_repository/resource" at "../core/resource.xqm";

let $data := request:get-data()/*
let $project-pid := $data/projectName/text()
let $resource-label := $data/fileName/text()
let $resource := concat('/db/cr-data/',$project-pid,'/',$resource-label)
let $resourcedata := doc($resource)
let $resource-pid := resource:new-with-label($resourcedata, $project-pid, $resource-label) 
let $gen-aux := resource:refresh-aux-files(('front','chapter','back','index'), $resource-pid, $project-pid)
return 
    <data>        
        <resource-label>{$resource-label}</resource-label>
        <resource>{$resource}</resource>
        <resourcedata>{$resourcedata}</resourcedata>
        <resource-pid>{$resource-pid}</resource-pid>
   </data>