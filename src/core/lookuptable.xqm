xquery version "3.0";

module namespace ltb = "http://aac.ac.at/content_repository/lookuptable";

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm"; 
import module namespace resource="http://aac.ac.at/content_repository/resource" at "resource.xqm";
import module namespace project="http://aac.ac.at/content_repository/project" at "project.xqm";
import module namespace rf="http://aac.ac.at/content_repository/resourcefragment" at "resourcefragment.xqm";
import module namespace repo-utils="http://aac.ac.at/content_repository/utils" at "repo-utils.xqm";

declare namespace cr="http://aac.ac.at/content_repository";

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
    let $rf:filename :=     util:document-name($rf:data),
        $rf:collection :=   util:collection-name($rf:data)
    let $ltb:path:=        
            let $path := (resource:path($resource-pid,$project-pid,"lookuptable"),project:path($project-pid,"lookuptables"))[1]
            return replace($path,'/$',''),
        $ltb:filename:=  $ltb:filename-prefix||$resource-pid||".xml"
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
    let $ltb:store := repo-utils:store-in-cache($ltb:filename,$ltb:path,$ltb:container,config:config($project-pid))
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

(:~
 : gets the data for the lookuptable as a document-node()
 : 
 : @param $resource-pid the pid of the resource 
 : @param $project-pid the id of the project to work in
 : @return the mets:file entry for the lookuptable.
~:)
declare function ltb:dump() as document-node()? {
()
};

(:~
 : gets the database-path to the lookuptable 
 : 
 : @param $resource-pid the pid of the resource 
 : @param $project-pid the id of the project to work in
 : @return the mets:file entry for the lookuptable.
~:)
declare function ltb:get-path() as xs:string? {
    ()
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