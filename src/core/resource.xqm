xquery version "3.0";

module namespace resource="http://aac.ac.at/content_repository/resource";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at "repo-utils.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
(:import module namespace master = "http://aac.ac.at/content_repository/master" at "master.xqm";:)
import module namespace project = "http://aac.ac.at/content_repository/project" at "project.xqm";
import module namespace rf = "http://aac.ac.at/content_repository/resourcefragment" at "resourcefragment.xqm";

declare namespace mets="http://www.loc.gov/METS/";
declare namespace xlink="http://www.w3.org/1999/xlink";
declare namespace fcs = "http://clarin.eu/fcs/1.0";
declare namespace cr="http://aac.ac.at/content_repository";

(: declaration of helper namespaces for better code structuring :)
declare namespace param="userinput.parameters";
declare namespace this="current.object";

declare variable $resource:mdtypes := ("MARC","MODS","EAD","DC","NISOIMG","LC-AV","VRA","TEIHDR","DDI","FGDC","LOM","PREMIS","PREMIS:OBJECT","PREMIS:AGENT","PREMIS:RIGHTS","PREMIS:EVENT","TEXTMD","METSRIGHTS","ISO 19115:2003 NAP","OTHER");

declare function resource:make-file($fileid as xs:string, $filepath as xs:string, $type as xs:string) as element(mets:file) {
    let $USE:=
        switch($type)
            case "workingcopy"          return $config:RESOURCE_WORKINGCOPY_FILE_USE
            case "wc"                   return $config:RESOURCE_WORKINGCOPY_FILE_USE
            case "resourcefragments"    return $config:RESOURCE_RESOURCEFRAGMENTS_FILE_USE
            case "fragments"            return $config:RESOURCE_RESOURCEFRAGMENTS_FILE_USE
            case "orig"                 return $config:RESOURCE_MASTER_FILE_USE
            case "master"               return $config:RESOURCE_MASTER_FILE_USE 
            default                     return ()
    return 
        if ($USE!='')
        then 
            <mets:file ID="{$fileid}" MIMETYPE="application/xml" USE="{$USE}">
                <mets:FLocat LOCTYPE="URL" xlink:href="{$filepath}"/>
            </mets:file>
        else ()
};


declare 
    %rest:DELETE
    %rest:path("/cr_xq/{$project-pid}/{$resource-pid}")
function resource:purge($resource-pid as xs:string, $project-pid as xs:string){
    resource:purge($resource-pid,$project-pid,())
};

declare
    %rest:DELETE
    %rest:path("/cr_xq/{$project-pid}/{$resource-pid}")
    %rest:query-param("delete-data","{$delete-data}")
function resource:purge($resource-pid as xs:string, $project-pid as xs:string, $delete-data as xs:boolean*) as empty() {
    if ($delete-data)
    then
        let $files := resource:files($resource-pid,$project-pid)
        return  
            for $f in $files//mets:file/mets:FLocat/@xlink:href
            return
                let $filename:=tokenize($f,'/')[last()],
                    $path := substring-before($f,$filename)
                return xmldb:remove($filename,$path)
    else 
    ()
};

declare function resource:generate-pid($project-pid as xs:string) as xs:string{
    resource:generate-pid($project-pid,'')
};

declare function resource:generate-pid($project-pid as xs:string, $random-seed as xs:string?) as xs:string {
    let $project:=  project:get($project-pid),
        $r-pids:=   $project//mets:div[@TYPE eq $config:PROJECT_RESOURCE_DIV_TYPE]/@ID
    let $this:pid := $project-pid||"."||replace(util:uuid($random-seed),'-','')
    return 
        if ($this:pid = $r-pids)
        then resource:generate-pid($project-pid,xs:string(current-dateTime()))
        else $this:pid
};

declare
    %rest:POST("{$data}")
    %rest:path("/cr_xq/{$project-pid}/newResource-with-label")
    %rest:header-param("resource-label", "{$resource-label}")
function resource:new($data as document-node(), $resource-label as xs:string) {
    let $log := util:log("INFO","*** UPLOADED DATA ***")
    let $log := util:log("INFO",$data/*)
    let $log := util:log("INFO",$resource-label)
    let $project-pid := resource:generate-pid($project-pid,$resource-label)
    return resource:new($data,$project-pid,())
};

declare
    %rest:POST("{$data}")
    %rest:path("/cr_xq/{$project-pid}/newResource")
function resource:new($data as document-node(), $project-pid as xs:string){
    resource:new($data,$project-pid,())
};

(:~
 : Stores the Registers the master of a stored resource permanently with a given project and returns 
 : its generated resource-pid. Returns the ID and issues a log entry, if 
 : the resource is already registered in the METS record; returns the empty sequence, 
 : if the resource is not available or a binary file.
 :
 : This does not generate a working copy, resource-fragment-extracts 
 : or lookup-tables. 
 : 
 : @param $data: the content of the new resource
 : @param $project-pid: the id of the cr-project
 : @return the resource-pid of the created resource  
~:)
declare
    %rest:POST("{$data}")
    %rest:path("/cr_xq/{$project-pid}/newResource")
    %rest:query-param("make-fragments","{$make-fragments}")
function resource:new($data as document-node(), $project-pid as xs:string, $make-fragments as xs:boolean*) as xs:string? {
    let $mets:record := project:get($project-pid),
        $mets:projectData := $mets:record//mets:fileGrp[@ID=$config:PROJECT_DATA_FILEGRP_ID],
        $mets:structMap := $mets:record//mets:structMap[@TYPE=$config:PROJECT_STRUCTMAP_TYPE and @ID=$config:PROJECT_STRUCTMAP_ID],
        $this:resource-pid := resource:generate-pid($project-pid) 
    return
        switch (true())
            case (not(exists($mets:record))) return util:log("INFO","no METS-Record found in config")
            case (not(exists($mets:projectData))) return util:log("INFO","project data not found in mets-record for project "||$project-pid)
            default return 
                let $master_filepath := resource:master($data, $this:resource-pid, $project-pid)    
                return
                    if ($master_filepath ne '')
                    then 
                        let $this:fileGrp:= <mets:fileGrp ID="{$this:resource-pid||$config:PROJECT_RESOURCE_FILEGRP_SUFFIX}" USE="{$config:PROJECT_RESOURCE_FILEGRP_USE}"/>,
                            $this:resource:= <mets:div TYPE="{$config:PROJECT_RESOURCE_DIV_TYPE}" ID="{$this:resource-pid}"/>
                        let $update-data:= (update insert $this:fileGrp into $mets:projectData,
                                            update insert $this:resource into $mets:structMap/mets:div)
                        let $master_register := resource:add-master($master_filepath, $this:resource-pid, $project-pid)
                        let $log := util:log("INFO","registered new resource "||$this:resource-pid||" in cr-project "||$project-pid||".")
                        return
                            if ($make-fragments eq true())
                            then rf:generate($this:resource-pid,$project-pid)
                            else $this:resource-pid
                    else util:log("INFO","New resource "||$this:resource-pid||" could not be created.")
};

(:~
 : Returns the structMap entry for the resource
~:)
declare
    %rest:GET
    %rest:path("/cr_xq/{$project-pid}/{$resource-pid}/entry")
function resource:get($resource-pid as xs:string,$project-pid as xs:string) as element(mets:div)? {
    let $mets:record:=project:get($project-pid)
    return $mets:record//mets:div[@TYPE eq $config:PROJECT_RESOURCE_DIV_TYPE][@ID eq $resource-pid]    
};


(:~
 : Returns the  mets:fileGrp which contains all files of the given resource. 
~:)
declare
    %rest:GET
    %rest:path("/cr_xq/{$project-pid}/{$resource-pid}/files")
function resource:files($resource-pid as xs:string,$project-pid as xs:string) as element(mets:fileGrp)? {
    let $mets:record:=project:get($project-pid),
        $mets:fileGrp-by-id:=$mets:record//mets:fileGrp[@USE=$config:PROJECT_RESOURCE_FILEGRP_USE and xs:string(@ID) eq xs:string($resource-pid||$config:PROJECT_RESOURCE_FILEGRP_SUFFIX)]
    return 
        if (exists($mets:fileGrp-by-id))
        then $mets:fileGrp-by-id
        else 
            (: fallback solution: we just fetch one fptr in the resource data and look for the <fileGrp> which it refers to :)
            let $mets:FILEID:=$mets:record//mets:div[@TYPE eq $config:PROJECT_RESOURCE_DIV_TYPE and @ID eq $resource-pid]//mets:fptr[1]/xs:string(@FILEID)            
            return $mets:record//mets:fileGrp[@USE=$config:PROJECT_RESOURCE_FILEGRP_USE and mets:file/@ID = $mets:FILEID]
};


declare function resource:add-file($file as element(mets:file),$resource-pid as xs:string,$project-pid as xs:string) {
    let $mets:resourceFiles:=resource:files($resource-pid,$project-pid)
    let $this:fileID:=$file/@ID,
        $mets:file:=$mets:resourceFiles//mets:file[@ID eq $this:fileID]
    let $log := util:log("INFO",$mets:resourceFiles)
    return
        if (exists($mets:file))
        then update replace $mets:file with $file
        else update insert $file into $mets:resourceFiles
};

declare function resource:add-fragment($div as element(mets:div),$resource-pid as xs:string,$project-pid as xs:string) {
    let $mets:resource:=resource:get($resource-pid,$project-pid)
    let $this:fragmentID:=$div/@ID,
        $mets:div:=$mets:resource//mets:div[@ID eq $this:fragmentID]
    return
        if (exists($mets:div))
        then update replace $mets:div with $div
        else update insert $div into $mets:resource
};

declare function resource:remove-file($fileid as xs:string,$resource-pid as xs:string,$project-pid as xs:string){
    let $mets:resourceFiles:=resource:files($resource-pid,$project-pid)
    return update delete $mets:resourceFiles//mets:file[@ID eq $fileid]
}; 

(:~
 : Gets the path to the resources data specified as the third argument.
 : The data is read from resource's fileGrp in the project's mets record.  
 : This currently may be one of the following: 
 :  - master
 :  - workingcopy
 :  - lookuptable
 :  - resourcefragments  
 :
 : @param $resource-pid: the PID of the resource
 : @param $project-pid: the ID of the current project
 : @param $key: the key of the data to get
~:)
declare function resource:path($resource-pid as xs:string, $project-pid as xs:string, $key as xs:string) as xs:string? {
    let $config:=   project:get($project-pid),
        $file:=     resource:files($resource-pid,$project-pid),
        $use:=  
            switch($key)
                case "master"           return $config:RESOURCE_MASTER_FILE_USE
                case "wc"               return $config:RESOURCE_WORKINGCOPY_FILE_USE
                case "working copy"     return $config:RESOURCE_WORKINGCOPY_FILE_USE
                case "workingcopy"      return $config:RESOURCE_WORKINGCOPY_FILE_USE
                case "workingcopies"    return $config:RESOURCE_WORKINGCOPY_FILE_USE
                case "lookuptable"      return $config:RESOURCE_LOOKUPTABLE_FILE_USE
                case "resourcefragments"return $config:RESOURCE_RESOURCEFRAGMENTS_FILE_USE
                default                 return ()
    return $file/mets:file[@USE=$use]/mets:FLocat/@xlink:href
};


(:~
 :  @return the mets:file-Element of the Master File.
~:)
declare function resource:get-master($resource-pid as xs:string, $project-pid as xs:string) as element(mets:file)? {
    let $mets:resource:=resource:get($resource-pid,$project-pid),
        $mets:resource-files:=resource:files($resource-pid,$project-pid)
    let $mets:master:=$mets:resource-files/mets:file[@USE eq $config:RESOURCE_MASTER_FILE_USE]
    return $mets:master
};

declare
    %rest:GET
    %rest:path("/cr_xq/{$project-pid}/{$resource-pid}")
function resource:master($resource-pid as xs:string, $project-pid as xs:string) as document-node()? {
    let $doc := doc(resource:path($resource-pid,$project-pid,'master'))
    return $doc
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
declare %private function resource:master($data as document-node(), $resource-pid as xs:string, $project-pid as xs:string) as xs:string? {
    let $current := resource:master($resource-pid,$project-pid)
    return
    if (exists($current))
    then
        update replace $current with $data
    else 
        let $this:filename := $resource-pid||".xml"
        let $master_targetpath:= project:path($project-pid,'master')
        let $store:= 
                try {repo-utils:store-in-cache($this:filename,$master_targetpath,$data,project:get($project-pid))
                } catch * {
                   util:log("INFO", "master doc of resource "||$resource-pid||" could not be stored at "||$master_targetpath) 
                }, 
            $this:filepath:=$master_targetpath||"/"||$this:filename
        return 
            if (doc-available($this:filepath))
            then $this:filepath
            else ()
};

(:~
 : Stores descriptive metadata of a resource in the appropriate collection. It does *not* register it with the resource.
 : 
 : @param $data: the content of the resource 
 : @param $resource-pid: the pid of the resource to store
 : @param $project-id: the id of the project the resource belongs to
 : @return the db path to the file
~:)
declare function resource:store-dmd($data as document-node(), $resource-pid as xs:string?, $project-pid as xs:string) as xs:string? {
    let $this:filename := $config:RESOURCE_DMD_FILENAME_PREFIX||$resource-pid||".xml"
    let $targetpath:= project:path($project-pid,'metadata')
    let $store:= 
            try {repo-utils:store-in-cache($this:filename,$master_targetpath,$data,project:get($project-pid))
            } catch * {
               util:log("INFO", "metadata for resource "||$resource-pid||" could not be stored at "||$targetpath) 
            }, 
        $this:filepath:=$targetpath||"/"||$this:filename
    return 
        if (doc-available($this:filepath))
        then $this:filepath
        else ()
};

(:~
 : Registers a master document with the resource by appending a mets:file element to
 : the resources mets:fileGrp plus a fptr in the structMap.
 : If there is already a master registered with this resource, it will be replaced.
 : Note that this function does not touch the actual data. 
 : Storage is handled by master:store().
 : 
 : @param $param:path the path to the stored working copy
 : @param $param:resource-pid the pid of the resource
 : @param $param:project-id: the id of the current project
 : @return the added mets:file element 
~:)
declare function resource:add-master($master-filepath as xs:string, $resource-pid as xs:string, $project-pid as xs:string) as empty() {
    let $resource :=    resource:get($resource-pid,$project-pid)
    let $master_fileid:=$resource-pid||$config:RESOURCE_MASTER_FILEID_SUFFIX
    let $master_file:=  resource:make-file($master_fileid,$master-filepath,"master")
    let $store-file:=   resource:add-file($master_file,$resource-pid,$project-pid),
        $add-fptr :=    if (exists($resource/mets:fptr[@FILEID eq $master_fileid])) 
                        then () 
                        else update insert <mets:fptr FILEID="{$master_fileid}"/> into $resource   
    return $store-file
};

(: getter and setter for dmdSec, i.e. the resources's descriptive metadata :)
declare
    %rest:GET
    %rest:path("/cr_xq/{$project-pid}/{$resource-pid}/dmd")
function resource:dmd($resource-pid as xs:string,$project-pid as xs:string) as element()? {
    let $dmdID :=   resource:get($resource-pid, $project-pid)/@DMDID,
        $dmdSec :=  doc(project:filepath($project-pid))//id($dmdID) 
    return
        if (exists($dmdSec))
        then 
            typeswitch($dmdSec/*)
                case element(mets:mdWrap) return $dmdSec//xmlData/*
                case element(mets:mdRef) return 
                    let $location := $dmdSec/mets:mdRef/@xlink:href
                    return 
                        if (util:is-binary-doc($location))
                        then ()
                        else 
                            if (doc-available($location))
                            then doc($location)/*
                            else util:log("INFO","The Metadata for resource "||$resource-pid||" could not be retrieved from "||$location)
                default return util:log("INFO","Invalid content in Metadata Section for resource "||$resource-pid||".")
        else util:log("INFO","No Metadata is registered for resource "||$resource-pid||".")
};

declare
    %rest:PUT("{$data}")
    %rest:path("/cr_xq/{$project-pid}/{$resource-pid}/dmd")
    %rest:query-param("mdtype","{$mdtype}","TEI")
function resource:dmd($resource-pid as xs:string, $project-pid as xs:string, $data as item(), $mdtype as xs:string*) as empty() {
    resource:dmd($resource-pid,$project-pid,$data,$mdtype[1],())
};

(:~
 : Registers a metdata file for a resource and optionally stores it to the db.
 : 
 : @param $resource-pid the PID of the resource
 : @param $project-pid the PID of the project
 : @param $data either a string with an db-path leading to an (existing) file, or the content of the metadata as a element or document-node.
 : @param $store-to-db if set to true(), the metdata resource is stored as an independend resource to the database () and only referenced in the mets record (default behaviour), if set to false(), the metadata is inlined in the the project's mets record.   
 : @return empty()
~:)
declare
    %rest:PUT("{$data}")
    %rest:path("/cr_xq/{$project-pid}/{$resource-pid}/dmd")
function resource:dmd($resource-pid as xs:string, $project-pid as xs:string, $data as item(), $mdtype as xs:string, $store-to-db as xs:boolean?) as empty() {
    let $doc:=          project:get($project-pid),
        $current :=     resource:dmd($resource-pid,$project-pid),
        $data-location:=base-uri($current),
        $dmdid :=       $resource-pid||$config:RESOURCE_DMDID_SUFFIX,
        $dmdSec :=      $doc//id($dmdID)
    return 
        switch (true())
            (: wrong declaration of Metadata Format :)
            case not($mdtype=$resource:mdtypes) return util:log("INFO","invalid value for parameter $mdtype for resource "||$resource-pid)
            
            (: $data is not a document, element node or string :)
            case (not($data instance of document-node()) and not($data instance of element()) and not($data instance of xs:string)) return util:log("INFO","parameter $data has invalid type (resource "||$resource-pid||") allowed are: document-node() or element() for content, or xs:string for db-path.") 
            
            (: $data is empty > remove current content of dmd, external files and references to this dmd :)
            case (not(exists($data)) and exists($current)) return 
                let $rm-data := if ($data-location eq base-uri($doc)) 
                                then update delete $current
                                else xmldb:remove(util:collection-name($data),util:document-name($data)),
                    $rm-dmdSec:=update delete $doc//id($dmdid),
                    $rm-ref-attrs:= update delete $doc//@DMDID[matches(.,'\s*'||$dmdid||'\s*')]
                return ()
            (: update current content or insert new :)
            case (exists($data)) return
                (: add dmdid attribute to the resource's mets:div container :)
                let $dmdidref := 
                    if (exists($doc//mets:div[matches(@DMDID,'\s*'||$dmdid||'\s*')])) 
                    then () 
                    else update insert attribute DMDID {$dmdid} into resource:get($resource-pid,$project-pid)
                return
                (: store metadata to database and add a reference in the mets record:)
                if (exists($store-to-db))
                then
                    (: the content of the metdata is already in an external file, so we just set the mdRef (again) :)
                    if ($data instance of xs:string)
                    then  
                        if (doc-available(normalize-space($data)))
                        then 
                            let $mdRef:= <mdRef MDTYPE="{$mdtype}" LOCTYPE="URL" xmlns="http://www.loc.gov/METS/" xlink:href="{normalize-space($data)}"/>
                            return
                                switch(true())
                                    case (exists($dmdSec/node())) return (update delete $dmdSec/node(), update insert $mdRef into $dmdSec)
                                    case (exists($dmdSec)) return update insert $mdRef into $dmdSec
                                    default return update insert <dmdSec ID="{$dmdid}" xmlns="http://www.loc.gov/METS/">{$mdRef}</dmdSec> preceding $doc//mets:fileSec
                        else 
                            util:log("INFO", "The metdata resource referenced in "||$data||"is not available. dmdSec-Update aborted for resource "||$resource-pid)
                    else 
                        (: $data contains metadata content, so we store it to the db and create a new mdRef :)
                        let $mdpath := resource:store-dmd(if ($data instance of document-node()) then $data else document{$data},$resource-pid,$project-pid),
                            $mdRef:= <mdRef MDTYPE="{$mdtype}" LOCTYPE="URL" xmlns="http://www.loc.gov/METS/" xlink:href="{$mdpath}"/>
                        return
                            if ($mdpath!='')
                            then 
                                switch(true())
                                    case (exists($dmdSec/node())) return (update delete $dmdSec/node(), update insert $mdRef into $dmdSec)
                                    case (exists($dmdSec)) return update insert $mdRef into $dmdSec
                                    default return update insert <dmdSec ID="{$dmdid}" xmlns="http://www.loc.gov/METS/">{$mdRef}</dmdSec> preceding $doc//mets:fileSec
                            else util:log("INFO","could not store metadata resource at "||$dmdSec)
                
                (: move metadata into mets container :)
                else
                    if ($data instance of xs:string)
                    then  
                        let $doc := if (doc-available(normalize-space($data))) then doc(normalize-space($data)) else ()
                        return 
                        if (exists($doc))
                        then 
                            (: store content of the external file into the mets container ... :)
                            let $mdWrap := <mdWrap MDTYPE="{$mdtype}" xmlns="http://www.loc.gov/METS/"><xmlData>{$doc}</xmlData></mdWrap>
                            let $update-mets:= 
                                switch(true())
                                    case (exists($dmdSec/node())) return (update delete $dmdSec/node(), update insert $mdWrap into $dmdSec)
                                    case (exists($dmdSec)) return update insert $mdWrap into $dmdSec
                                    default return update insert <dmdSec ID="{$dmdid}" xmlns="http://www.loc.gov/METS/">{$mdWrap}</dmdSec> preceding $doc//mets:fileSec
                            (: ... and delete the external file :)
                            return xmldb:remove(util:collection-name($doc),util:document-name($doc))
                        else util:log("INFO", "The metdata resource referenced in "||$data||"is not available. dmdSec-Update aborted for resource "||$resource-pid)
                    
                    (: $data is metadata content :)
                    else
                        let $mdWrap := <mdWrap MDTYPE="{$mdtype}" xmlns="http://www.loc.gov/METS/"><xmlData>{$data}</xmlData></mdWrap>
                        return
                        
                        (: metadata content already exists :)
                        if (exists($current)) 
                        then
                            (: current data lives inside the mets record, so we update it :)
                            if ($data-location eq base-uri($data)) 
                            then update replace $current with $data
                            (: data is in an external file, we store the :)
                            else   
                                (: ... otherwise fetch the content of the external file, store it into the mets record and delete the file afterwards. :)
                                let $update-mets:= 
                                    switch(true())
                                        case exists($dmdSec/node()) return 
                                            (update delete $dmdSec/node(),
                                            update insert $mdWrap into $dmdSec)
                                        case exists($dmdSec) return 
                                            update insert $mdWrap into $dmdSec
                                        default return 
                                            update insert <dmdSec ID="{$dmdid}" xmlns="http://www.loc.gov/METS/">{$mdWrap}</dmdSec> preceding $doc//mets:fileSec
                                (: ... and delete the external file :)
                                return xmldb:remove(util:collection-name($doc),util:document-name($doc))
                        
                        (: metadata content does not exist, so we just insert it :)
                        else
                            if (exists($dmdSec)) 
                            then update insert $mdWrap into $dmdSec
                            else update insert <dmdSec ID="{$dmdid}" xmlns="http://www.loc.gov/METS/">{$mdWrap}</dmdSec> preceding $doc//mets:fileSec
        default return ()
};


