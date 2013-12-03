xquery version "3.0";

import module namespace xdb="http://exist-db.org/xquery/xmldb";
import module namespace config="http://exist-db.org/xquery/apps/config-params" at "core/config.xql";
import module namespace project="http://aac.ac.at/content_repository/project" at "core/project.xqm";

(: The following external variables are set by the repo:deploy function :)

(: file path pointing to the exist installation directory :)
declare variable $home external;
(: path to the directory containing the unpacked .xar package :)
declare variable $dir external;
(: the target collection into which the app is deployed :)
declare variable $target external;

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

declare variable $local:cr-writer:=doc($dir||"/modules/access-control/writer.xml")/write;

(: setup projects-dir :)
local:mkcol("", $config:projects-dir),
(: store the collection configuration :)
local:mkcol("/db/system/config", $target),
xdb:store-files-from-pattern(concat("/system/config", $target), $dir, "*.xconf"),

(: we need two system users for the data maangement :)
(: TODO merge these into one? :)
sm:create-account($local:cr-writer/xs:string(write-user),$local:cr-writer/xs:string(write-user-cred),()),
sm:create-account("cr-xq","cr-xq",()),
sm:create-group("cr-admin","cr-xq","admin"),
project:new("defaultProject")