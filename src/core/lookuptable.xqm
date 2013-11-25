xquery version "3.0";

module namespace tbl="http://aac.ac.at/content_repository/lookuptable";
import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm"; 
import module namespace resource="http://aac.ac.at/content_repository/resource" at "resource.xqm";
import module namespace rf="http://aac.ac.at/content_repository/resourcefragment" at "resourcefragment.xqm";
import module namespace repo-utils="http://aac.ac.at/content_repository/utils" at "repo-utils.xqm";

declare namespace cr="http://aac.ac.at/content_repository";

(:~
 : Getter / setter / storage functions for lookuptables.
~:)

declare variable $tbl:default-path := $config:default-lookuptable-path;
declare variable $tbl:filename-prefix := $config:RESOURCE_LOOKUPTABLE_FILENAME_SUFFIX; 


(:~
 : 
 : @param $resource-pid the pid of the resource 
 : @param $project-id the id of the project to work in
 : @return the path to the lookup table
~:)
declare function tbl:create($resource-pid as xs:string,$project-id as xs:string) as xs:string? {
    let $rf:file:= rf:get-data($resource-pid, $project-id)
    let $tbl:path-param:=($config//param[@key='lookup-tables.path'],$tbl:default-path)[1],
        $tbl:path := replace($tbl:path-param,'/$',''),
        $tbl:filename:=$tbl:filename-prefix||$filename
    
    let $tbl:container :=
                    <fcs:lookup-table context="{$project}" pid="{$resource-pid}" created="{current-dateTime()}" filepath="{$path}" filemodified="{xmldb:last-modified($collection,$filename)}">{
                        for $fragment in $fragments-extracted
                        return 
                            <fcs:ResourceFragment context="{$project}" resource-pid="{$resource-pid}" resourcefragment-pid="{$fragment/@resourcefragment-pid}">{
                                for $cr:id in $fragment//@cr:id 
                                return <cr:id>{$cr:id}</cr:id>
                            }</fcs:ResourceFragment>
                    }</fcs:lookup-table>,
                $store-table:=repo-utils:store-in-cache($table-filename,$table-path,$table-doc,$config)
    return $tbl:path||"/"||$tbl:filename
};

(:~
 : 
 : @param $resource-pid the pid of the resource 
 : @param $project-id the id of the project to work in
 : @return the path to the working copy
~:)
declare function tbl:new(){
()
};

(:~
 : gets the mets:file entry for the lookuptable.
 : 
 : @param $resource-pid the pid of the resource 
 : @param $project-id the id of the project to work in
 : @return the mets:file entry for the lookuptable.
~:)
declare function tbl:get(){
()
};

(:~
 : gets the data for the lookuptable as a document-node()
 : 
 : @param $resource-pid the pid of the resource 
 : @param $project-id the id of the project to work in
 : @return the mets:file entry for the lookuptable.
~:)
declare function tbl:get-data() as document-node()? {
()
};

(:~
 : gets the database-path to the lookuptable 
 : 
 : @param $resource-pid the pid of the resource 
 : @param $project-id the id of the project to work in
 : @return the mets:file entry for the lookuptable.
~:)
declare function tbl:get-path() as xs:string? {
    ()
};

(:~
 : removes the lookuptable.
 : 
 : @param $resource-pid the pid of the resource 
 : @param $project-id the id of the project to work in
 : @return empty()
~:)
declare function tbl:remove(){
()
};

(:~
 : removes the lookuptable.
 : 
 : @param $resource-pid the pid of the resource 
 : @param $project-id the id of the project to work in
 : @return the path to the working copy
~:)
declare function tbl:remove(){
()
};

(:~
 : removes the data of a lookuptable.
 : 
 : @param $resource-pid the pid of the resource 
 : @param $project-id the id of the project to work in
 : @return the path to the working copy
~:)
declare function tbl:remove-data(){
()
};