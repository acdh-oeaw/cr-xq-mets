xquery version "3.0";
declare namespace request="http://exist-db.org/xquery/request";


declare option exist:serialize "method=xml media-type=text/xml indent=yes";

import module namespace gen = "http://aac.ac.at/content_repository/generate-index" at "../modules/index-functions/generate-index-functions.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "../core/config.xqm"; 
import module namespace project = "http://aac.ac.at/content_repository/project" at "../core/project.xqm";

let $data := request:get-data()/*
let $projectName := if (data($data/projectName) = "") 
    then "aclsdkfjslekjafdsfjsafksajfjslfsdlkf"
    else data($data/projectName)
let $delete := project:structure($projectName,"remove")
let $cr-projects := concat('/db/cr-projects/',$projectName)
let $deleteProject := if (xmldb:collection-available($cr-projects)) 
    then xmldb:remove($cr-projects)
    else <strong>"Sorry, no such collection available."</strong>
let $usernames := sm:find-users-by-username($projectName)
let $deletedUsers := for $user in $usernames return sm:remove-account($user)
let $deletedGroups := for $group in $usernames return sm:remove-group($group)
let $rewriteIndexModul := gen:register-project-index-functions()

return if ($deleteProject = <strong>"Sorry, no such collection available."</strong>) 
    then 
    <data>
        <projectName>{$projectName}</projectName>
        <status>The Project {$projectName} did not exit</status>
    </data>
    else
    <data>
        <projectName>{$projectName}</projectName>
        <status>The Project {$projectName} has been deleted</status>
    </data>