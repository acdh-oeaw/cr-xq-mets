xquery version "3.0";
declare namespace request="http://exist-db.org/xquery/request";
declare option exist:serialize "method=xml media-type=text/xml indent=yes";

import module namespace config="http://exist-db.org/xquery/apps/config" at "../core/config.xqm"; 
import module namespace ixgen="http://aac.ac.at/content_repository/generate-index" at "../modules/index-functions/generate-index-functions.xqm";
import module namespace project = "http://aac.ac.at/content_repository/project" at "../core/project.xqm";

let $data := request:get-data()/*
let $project-pid := data($data/projectName)
let $new-project := project:new($project-pid)
let $cr-projects := concat('/db/cr-projects/',$project-pid)
let $config:=config:project-config($project-pid)
let $createIndex := ixgen:generate-index-functions($project-pid)
return if (exists($new-project)) 
    then  
    <data>
        <projectName>{$project-pid}</projectName>
        <status>{"Created project: "||$project-pid||" in "||config:path('projects')||"/"||$project-pid }</status>
    </data>
    else if (exists(project:get($project-pid)))
    then
    <data>
        <projectName>{$project-pid}</projectName>
        <status>{"Project "||$project-pid||" already exists."}</status>
    </data>
    else 
    <data>
        <projectName>{$project-pid}</projectName>
        <status>{"Project "||$project-pid||" could not be instantiated."}</status>
    </data>
