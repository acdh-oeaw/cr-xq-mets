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
declare function master:get($resource-pid as xs:string, $project-pid as xs:string) as element(mets:file)? {
    let $mets:record:=config:config($project-pid),
        $mets:resource:=resource:get($resource-pid,$project-pid),
        $mets:resource-files:=resource:files($resource-pid,$project-pid)
    let $mets:master:=$mets:resource-files/mets:file[@USE eq $config:RESOURCE_MASTER_FILE_USE]
    return $mets:master
};

(:~
 : The path to a resource's master file. This is based upon the resource's mets entry, so 
 : the master must be already registered with it. 
 :
 : @param $resource-pid: the pid of the resource to store
 : @param $project-id: the id of the project the resource belongs to
 : @return the db path to the file
~:)
declare function master:path($resource-pid as xs:string, $project-pid as xs:string) as xs:string? {
    let $master:=master:get($resource-pid,$project-pid),
        $master:locat:=$master/mets:FLocat/@xlink:href
    return
        if ($master)
        then xs:string($master:locat)
        else ()
};

(:~
 : Gets a master file for a resource as a document-node and stores it to the project's data directory. It does *not* register it with the resource.
 : 
 : @param $content: the content of the resource 
 : @param $filename: the filename of the resource to store.
 : @param $resource-pid: the pid of the resource to store
 : @param $project-id: the id of the project the resource belongs to
 : @return the db path to the file
~:)
declare function master:store($data as document-node(), $resource-pid as xs:string?, $project-pid as xs:string) as xs:string? {
    let $this:filename := $resource-pid||".xml"
    let $master:targetpath:= resource:path($resource-pid,$project-pid,'master')
    let $store:= repo-utils:store-in-cache($this:filename,$master:targetpath,$data,config:config($project-pid)), 
        $this:filepath:=$master:targetpath||"/"||$this:filename
    return 
        if (doc-available($this:filepath))
        then $this:filepath
        else util:log("INFO", "master doc of resource "||$resource-pid||" could not be stored at "||$master:targetpath)
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