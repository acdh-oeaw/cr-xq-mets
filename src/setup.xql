xquery version "3.0";

(:
The MIT License (MIT)

Copyright (c) 2016 Austrian Centre for Digital Humanities at the Austrian Academy of Sciences

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE
:)

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

declare function local:store-prepared-collection-xconf($xconfs, $path, $from-path) {
for $xconf in $xconfs
  let $relPath := replace(resolve-uri("", base-uri($xconf)), $from-path||"/", ''),
      $newCollection := local:mkcol($path, $relPath),
      $newXconf := xdb:store($path||"/"||$relPath, "collection.xconf", $xconf)
  return ()
};

declare variable $local:cr-writer:=doc($target||"/modules/access-control/writer.xml")/write;

declare variable $local:projects-xconf := doc($target||"/_cr-projects_xconf.xml");
declare variable $local:data-xconfs-from-path := "/db_system_config_db_cr-data";
declare variable $local:data-xconfs-to-path := translate($local:data-xconfs-from-path, '_', '/');
declare variable $local:data-xconfs := collection($target||$local:data-xconfs-from-path);  


(: we need two system users for the data maangement :)
(: TODO merge these into one? :)
util:log("INFO", "** setting up writer account **"),
if (not(sm:user-exists(xs:string($local:cr-writer/write-user)))) then sm:create-account(xs:string($local:cr-writer/write-user),xs:string($local:cr-writer/write-user-cred),()) else sm:passwd(xs:string($local:cr-writer/write-user),xs:string($local:cr-writer/write-user-cred)),
util:log("INFO", "** setting up cr-xq system account **"),
if (not(sm:user-exists($config:system-account-user))) then sm:create-account($config:system-account-user,$config:system-account-pwd,$config:system-account-user,()) else sm:passwd($config:system-account-user,$config:system-account-pwd),
if (not(sm:group-exists("cr-admin"))) then sm:create-group("cr-admin",$config:system-account-user,"admin") else (),
util:log("INFO", "$target: "|| $target),
(: setup projects-dir :)
local:mkcol("", $config:projects-dir),
local:mkcol("", $config:data-dir),
local:mkcol(""||$config:data-dir, "_indexes"),
(: store the cr-projects collection configuration :)
local:mkcol("/db/system/config", $config:projects-dir),
(: store the collection configuration :)
local:mkcol("/db/system/config", $target),
(: preparea a collection for the cr-data collection configuration :)
local:mkcol("/db/system/config", $config:data-dir),
local:mkcol("/db/system/config"||$config:data-dir, "_workingcopies"),
local:store-prepared-collection-xconf($local:data-xconfs, $local:data-xconfs-to-path, $target||$local:data-xconfs-from-path),
util:log("INFO", "** chown "||$config:projects-dir||" "||$config:system-account-user||":cr-admin"),
sm:chown(xs:anyURI($config:projects-dir),$config:system-account-user),
sm:chgrp(xs:anyURI($config:projects-dir),'cr-admin'),
sm:chown(xs:anyURI($config:data-dir),$config:system-account-user),
sm:chgrp(xs:anyURI($config:data-dir),'cr-admin'),
sm:chown(xs:anyURI($config:data-dir||"_indexes"),$config:system-account-user),
sm:chgrp(xs:anyURI($config:data-dir||"_indexes"),'cr-admin'),
sm:chmod(xs:anyURI($config:data-dir||"_indexes"),'group=+write'), 
sm:chmod(xs:anyURI($config:data-dir||"_indexes"),'other=+write'),
sm:chown(xs:anyURI("/db/system/config"||$config:data-dir||"_workingcopies"),$config:system-account-user),
sm:chgrp(xs:anyURI("/db/system/config"||$config:data-dir||"_workingcopies"),'cr-admin'),
sm:chmod(xs:anyURI("/db/system/config"||$config:data-dir||"_workingcopies"),'group=+write'), 
util:log("INFO", "** chown "||$config:data-dir||" "||$config:system-account-user||":cr-admin"),
xdb:store-files-from-pattern(concat("/system/config", $target), $dir, "*.xconf"),
xdb:store("/db/system/config/"||$config:projects-dir,'collection.xconf',$local:projects-xconf),
xdb:reindex($config:projects-dir),
xdb:reindex($target),

util:log("INFO", "** setting up default project 'defaultProject' **"),
project:new("defaultProject")
