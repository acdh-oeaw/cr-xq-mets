xquery version "3.0";

module namespace master="http://aac.ac.at/content_repository/master";
import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm"; 
import module namespace resource="http://aac.ac.at/content_repository/resource" at "resource.xqm";
import module namespace repo-utils="http://aac.ac.at/content_repository/utils" at "repo-utils.xqm";


(: declaration of helper namespaces for better code structuring :)
declare namespace param="userinput.parameters";
declare namespace this="current.object";

declare namespace mets="http://www.loc.gov/METS/";
declare namespace xlink="http://www.w3.org/1999/xlink";
declare namespace fcs = "http://clarin.eu/fcs/1.0";
declare namespace cr="http://aac.ac.at/content_repository";


(:~
 :  @return the mets:file-Element of the Master File.
~:)
declare function master:get($param:resource-pid as xs:string, $param:project-id as xs:string) as element(mets:file)? {
    let $mets:record:=config:config($param:project-id),
        $mets:resource:=resource:get($param:resource-pid,$param:project-id),
        $mets:resource-files:=resource:get-resourcefiles($param:resource-pid,$param:project-id)
    let $mets:master:=$mets:resource-files/mets:file[@USE eq $config:RESOURCE_MASTER_FILE_USE]
    return $mets:master
};


(:~
 : Gets a master file for a resource as a document-node and stores it to the project's data directory. It does *not* register it with the resource.
 : 
 : @param $content: the content of the resource 
 : @param $filename: the filename of the resource to store.
 : @param $param:resource-pid: the pid of the resource to store
 : @param $project-id: the id of the project the resource belongs to
~:)
declare function master:store($content as document-node(), $param:filename as xs:string?, $param:resource-pid as xs:string?, $param:project-id as xs:string) as element(mets:file)? {
    let $master:filename := ($param:filename,$param:resource-pid)[1]
    let $master:targetpath:= resource:path($param:resource-pid,$param:project-id,'master')
    let $store:= xmldb:store($master:targetpath,$master:filename,$content)
    return 
        if (doc-available($master:targetpath||"/"||$this:filename))
        then $master:targetpath||"/"||$this:filename
        else util:log("INFO", "master doc of resource "||$param:resource-pid||" could not be stored at "||$master:targetpath)
};

(:~
 : Gets a master file for a resource from a temporary upload path or as 
 : a document-node and moves it to the project's data directory. It does *not* register it with the resource.
 : 
 : @param $param:tmppath: the full path to the uploaded resource file.
 : @param $param:resource-pid: the pid of the resource 
~:)
declare function master:store($param:tmppath as xs:string, $param:resource-pid as xs:string, $param:project-id as xs:string) as element(mets:file)? {
    let $this:filename := tokenize($param:tmppath,'/')[last()],
        $this:collection:= substring-before($param:tmppath,$this:filename)
    let $master:targetpath:= resource:path($param:resource-pid,$param:project-id,'master')
    let $mv:= xmldb:move($this:collection,$master:targetpath,$this:filename)
    return 
        if (doc-available($master:targetpath||"/"||$this:filename))
        then $master:targetpath||"/"||$this:filename
        else util:log("INFO", "master doc of resource "||$param:resource-pid||" could not be moved to its targetpath "||$master:targetpath)
};

(:~
 : Registers a master document with the resource by appending a mets:file element to
 : the resources mets:fileGrp.
 : If there is already a master registered with this resource, it will be replaced.
 : Note that this function does not touch the actual data. 
 : Storage is handled by master:store().
 : 
 : @param $param:path the path to the stored working copy
 : @param $param:resource-pid the pid of the resource
 : @param $param:project-id: the id of the current project
 : @return the added mets:file element 
~:)
declare function master:add($param:master-filepath as xs:string, $param:resource-pid as xs:string,$param:project-id as xs:string) as element(mets:file)? {
    let $master:fileid:=$param:resource-pid||$config:RESOURCE_MASTER_FILEID_SUFFIX
    let $master:file:=resource:make-file($master:fileid,$param:master-filepath,"master")
    let $store-file:=resource:add-file($master:file,$param:resource-pid,$param:project-id)
    return $store-file
};