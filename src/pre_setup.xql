xquery version "3.0";

import module namespace xdb="http://exist-db.org/xquery/xmldb";
import module namespace config="http://exist-db.org/xquery/apps/config-params" at "core/config.xql";
import module namespace configm="http://exist-db.org/xquery/apps/config" at "core/config.xqm";
import module namespace project="http://aac.ac.at/content_repository/project" at "core/project.xqm";

(: The following external variables are set by the repo:deploy function :)

(: file path pointing to the exist installation directory :)
declare variable $home external;
(: path to the directory containing the unpacked .xar package :)
declare variable $dir external;
(: the target collection into which the app is deployed :)
declare variable $target external;

declare variable $tmp-xconfig := 
    <collection xmlns="http://exist-db.org/collection-config/1.0">
        <!-- This application has circular module imports. In order to avoid 
           infinite recursion on installation, RESTXQ processing is disabled. -->  
        <triggers/>
    </collection>;


declare function local:mkcol-recursive($collection, $components) {
    if (exists($components)) then
        let $newColl := concat($collection, "/", $components[1])
        return (
            xdb:create-collection($collection, $components[1]),
            local:mkcol-recursive($newColl, subsequence($components, 2))
        )
    else
        ()
};

(: Helper function to recursively create a collection hierarchy. :)
declare function local:mkcol($collection, $path) {
    local:mkcol-recursive($collection, tokenize($path, "/"))
};

(: This application has circular module imports. In order to avoid infinite recursion on installation 
   we have to disable RESTXQ Processing here.:)
local:mkcol("/db/system/config", $target), 
xdb:store("/db/system/config"||$target,'collection.xconf', $tmp-xconfig)