xquery version "3.0";

module namespace ltb = "http://aac.ac.at/content_repository/lookuptable";

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm"; 
import module namespace resource="http://aac.ac.at/content_repository/resource" at "resource.xqm";
import module namespace project="http://aac.ac.at/content_repository/project" at "project.xqm";
import module namespace rf="http://aac.ac.at/content_repository/resourcefragment" at "resourcefragment.xqm";
import module namespace repo-utils="http://aac.ac.at/content_repository/utils" at "repo-utils.xqm";

declare namespace mets="http://www.loc.gov/METS/";
declare namespace xlink="http://www.w3.org/1999/xlink";
declare namespace cr="http://aac.ac.at/content_repository";
declare namespace fcs="http://clarin.eu/fcs/1.0";
(:~
 : Getter / setter / storage functions for lookuptables.
~:)

declare variable $ltb:default-path := $config:default-lookuptable-path;
declare variable $ltb:filename-prefix := $config:RESOURCE_LOOKUPTABLE_FILENAME_PREFIX; 


(:~ Creates a lookup table from resourcefragments.   
 : 
 : @param $resource-pid the pid of the resource 
 : @param $project-pid the id of the project to work in
 : @return the path to the lookup table
~:)
declare function ltb:generate($resource-pid as xs:string,$project-pid as xs:string) as xs:string? {
    let $rf:data:=          
            let $rf:dump := rf:dump($resource-pid, $project-pid)
            return
                if (exists($rf:dump))
                then $rf:dump
                else 
                    let $rf:path:= rf:generate($resource-pid,$project-pid)
                    return doc($rf:path)
    let $base-uri := base-uri($rf:data)
    let $rf:filename :=     tokenize($base-uri,'/')[last()],
        $rf:collection :=   substring-before($base-uri,'/'||$rf:filename)
    let $ltb:current-filepath := resource:path($resource-pid,$project-pid,"lookuptable")
    let $ltb:filename:= if ($ltb:current-filepath != '')
                        then tokenize($ltb:current-filepath,'/')[last()]
                        else $ltb:filename-prefix||$resource-pid||".xml"
    let $ltb:path:= 
                if ($ltb:current-filepath != '')
                then substring-before($ltb:current-filepath,"/"||$ltb:filename)
                else project:path($project-pid,"lookuptables")
                
    let $ltb:container :=
        element {QName($config:RESOURCE_LOOKUPTABLE_ELEMENT_NSURI,$config:RESOURCE_LOOKUPTABLE_ELEMENT_NAME)} {
            attribute project-pid {$project-pid},
            attribute resource-pid {$resource-pid},
            attribute created {current-dateTime()},
            attribute origin {base-uri($rf:data)},
            attribute originmodified {xmldb:last-modified($rf:collection,$rf:filename)},
            for $fragment in $rf:data//*[local-name(.) eq $config:RESOURCE_RESOURCEFRAGMENT_ELEMENT_NAME and namespace-uri(.) eq $config:RESOURCE_RESOURCEFRAGMENT_ELEMENT_NSURI]
            return
                element {QName($config:RESOURCE_RESOURCEFRAGMENT_ELEMENT_NSURI,$config:RESOURCE_RESOURCEFRAGMENT_ELEMENT_NAME)} {
                    attribute project-pid {$project-pid},
                    attribute resource-pid {$resource-pid},
                    attribute resourcefragment-pid {$fragment/@resourcefragment-pid},
                    for $part-id in $fragment//@cr:id return <cr:id>{xs:string($part-id)}</cr:id>
                }
        }
    let $ltb:store := repo-utils:store($ltb:path,$ltb:filename,$ltb:container,true(),config:config($project-pid))
    
  let $ltb-fileid:=$resource-pid||$config:RESOURCE_LOOKUPTABLE_FILEID_SUFFIX,
      $ltb-file:=resource:make-file($ltb-fileid,$ltb:path||'/'||$ltb:filename,"lookuptable"),
      $store-file:=   resource:add-file($ltb-file,$resource-pid,$project-pid)
    return base-uri($ltb:store)
};

(:~
 : 
 : @param $resource-pid the pid of the resource 
 : @param $project-pid the id of the project to work in
 : @return the path to the working copy
~:)
declare function ltb:add($resource-pid as xs:string, $project-pid as xs:string) as xs:string? {
    ()
};

(:~
 : gets the mets:file entry for the lookuptable.
 : 
 : @param $resource-pid the pid of the resource 
 : @param $project-pid the id of the project to work in
 : @return the mets:file entry for the lookuptable.
~:)
declare function ltb:get(){
    ()
};

(:~ Finds the rfs containing an element with given @cr:id

 : @param $element-id the id of a xml-element expected inside some resourcefragment
 : @param $resource-pid the pid of the resource 
 : @param $project-pid the pid of the project
@return resourcefragment of the containing resourcefragment  
:)
declare function ltb:lookup($element-id as xs:string, $resource-pid as xs:string, $project-pid as xs:string) as xs:string* {
(:    rf:dump($resource-pid, $project-pid)/id($element-id)/ancestor::fcs:resourceFragment    :)
    ltb:dump($resource-pid, $project-pid)//fcs:resourceFragment[cr:id eq $element-id]/xs:string(@resourcefragment-pid)         
};


(:~
 : gets the data for the lookuptable as a document-node()
 : 
 : @param $resource-pid the pid of the resource 
 : @param $project-pid the id of the project to work in
 : @return the mets:file entry for the lookuptable.
~:)
declare function ltb:dump($resource-pid as xs:string, $project-pid as xs:string) as document-node()? {
let $ltb:location:=  resource:path($resource-pid, $project-pid, "lookuptable"  ),
        $ltb:doc := if (doc-available($ltb:location)) then doc($ltb:location) else util:log("INFO","Could not locate lookuptable from "||$ltb:location) 
    return $ltb:doc
};



(:~
 : gets the data for the lookuptable as a document-node()
 : 
 : @param $resource-pid the pid of the resource 
 : @param $project-pid the id of the project to work in
 : @return the mets:file entry for the lookuptable.
~:)
declare function ltb:dump($resource-pid as xs:string, $project-pid as xs:string) as document-node()? {
let $ltb:location:=  resource:path($resource-pid, $project-pid, "lookuptable"  ),
        $ltb:doc := if (doc-available($ltb:location)) then doc($ltb:location) else util:log("INFO","Could not locate lookuptable from "||$ltb:location) 
    return $ltb:doc
};


(:~
 : gets the data for the lookuptable as a document-node()
 : 
 : @param $resource-pid the pid of the resource 
 : @param $project-pid the id of the project to work in
 : @return the mets:file entry for the lookuptable.
~:)
declare function ltb:dump($resourcefragment-pid as xs:string, $resource-pid as xs:string, $project-pid as xs:string)  {
    let $ltb:location:=  resource:path($resource-pid, $project-pid, "lookuptable"),
        $ltb:doc := if (doc-available($ltb:location)) then doc($ltb:location) else util:log("INFO","Could not locate lookuptable from "||$ltb:location) 
    return
(:    "$ltb:doc//fcs:"||$config:RESOURCE_RESOURCEFRAGMENT_ELEMENT_NAME||"[@cr:"||$config:RESOURCEFRAGMENT_PID_NAME||"='"||$resourcefragment-pid||"']":)
    util:eval(
        "$ltb:doc//fcs:"||$config:RESOURCE_RESOURCEFRAGMENT_ELEMENT_NAME||"[@"||$config:RESOURCEFRAGMENT_PID_NAME||"='"||$resourcefragment-pid||"']"
    )
};

(:~
 : OBSOLETED by resource:path() ??
 
 : gets the database-path to the lookuptable 
 : 
 : @param $resource-pid the pid of the resource 
 : @param $project-pid the id of the project to work in
 : @return the mets:file entry for the lookuptable.
~:)
declare function ltb:path($resource-pid as xs:string, $project-pid as xs:string) as xs:string? {
    let $rf:fileGrp:=resource:files($resource-pid, $project-pid)
    return $rf:fileGrp/mets:file[@USE eq $config:RESOURCE_LOOKUPTABLE_FILE_USE]/mets:FLocat/@xlink:href
};


(:~
 : removes the lookuptable.
 : 
 : @param $resource-pid the pid of the resource 
 : @param $project-pid the id of the project to work in
 : @return empty()
~:)
declare function ltb:remove(){
()
};

(:~
 : removes the lookuptable.
 : 
 : @param $resource-pid the pid of the resource 
 : @param $project-pid the id of the project to work in
 : @return the path to the working copy
~:)
declare function ltb:remove(){
()
};

(:~
 : removes the data of a lookuptable.
 : 
 : @param $resource-pid the pid of the resource 
 : @param $project-pid the id of the project to work in
 : @return the path to the working copy
~:)
declare function ltb:remove-data(){
()
};