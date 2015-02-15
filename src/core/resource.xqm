xquery version "3.0";

module namespace resource="http://aac.ac.at/content_repository/resource";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at "repo-utils.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
(:import module namespace master = "http://aac.ac.at/content_repository/master" at "master.xqm";:)
import module namespace project = "http://aac.ac.at/content_repository/project" at "project.xqm";
import module namespace handle = "http://aac.ac.at/content_repository/handle" at "../modules/resource/handle.xqm";
import module namespace toc = "http://aac.ac.at/content_repository/toc" at "toc.xqm";
import module namespace rf = "http://aac.ac.at/content_repository/resourcefragment" at "resourcefragment.xqm";
import module namespace wc="http://aac.ac.at/content_repository/workingcopy" at "wc.xqm";
import module namespace lt = "http://aac.ac.at/content_repository/lookuptable" at "lookuptable.xqm";
import module namespace facs = "http://aac.ac.at/content_repository/facs" at "facs.xqm";


declare namespace mets="http://www.loc.gov/METS/";
declare namespace xlink="http://www.w3.org/1999/xlink";
declare namespace fcs = "http://clarin.eu/fcs/1.0";
declare namespace cr="http://aac.ac.at/content_repository";
declare namespace cmd="http://www.clarin.eu/cmd/";
declare namespace oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/";
declare namespace xi = "http://www.w3.org/2001/XInclude";

(: declaration of helper namespaces for better code structuring :)
declare namespace param="userinput.parameters";
declare namespace this="current.object";

declare variable $resource:mdtypes := ("MARC","MODS","EAD","DC","NISOIMG","LC-AV","VRA","TEIHDR","DDI","FGDC","LOM","PREMIS","PREMIS:OBJECT","PREMIS:AGENT","PREMIS:RIGHTS","PREMIS:EVENT","TEXTMD","METSRIGHTS","ISO 19115:2003 NAP","OTHER");

declare variable $resource:othermdtypes := ("CMDI"); 

(: default location when storing md with resource:dmd#5 :)
declare variable $resource:defaultMDStoreLocation := "db";


declare function resource:make-file($fileid as xs:string, $filepath as xs:string, $type as xs:string) as element(mets:file) {
    let $USE:=
        switch($type)
            case "workingcopy"          return $config:RESOURCE_WORKINGCOPY_FILE_USE
            case "wc"                   return $config:RESOURCE_WORKINGCOPY_FILE_USE
            case "resourcefragments"    return $config:RESOURCE_RESOURCEFRAGMENTS_FILE_USE            
            case "fragments"            return $config:RESOURCE_RESOURCEFRAGMENTS_FILE_USE
            case "lookuptable"          return $config:RESOURCE_LOOKUPTABLE_FILE_USE
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


(:~We might want to transform a resource's master document before indexing, extracting fragments etc. 
 : This can be done by overing the transform templates of the working stylesheet. This function sets the 
 : path of a XSL file with those templates. 
~:)
declare function resource:set-preprocess-xsl-path($path as xs:string, $resource-pid as xs:string, $project-pid as xs:string) as empty() {
    let $project:= project:get($project-pid),
        $current-path := resource:get-preprocess-xsl-path($resource-pid,$project-pid),
        $behavior-by-current-path := $project//mets:behavior[mets:mechanism/@xlink:href = $current-path][@BTYPE = $wc:behavior-btype],
        $behavior-by-new-path := $project//mets:behavior[mets:mechanism/@xlink:href = $path][@BTYPE = $wc:behavior-btype],
        $behaviorSec := $project//mets:behaviorSec
    return 
        if ($current-path = "")
        then 
            (:check whether there exists a new behavior element with the path to be set :)
            if (exists($behavior-by-new-path))
            (: if yes, then just add the $resource-pid to the parent::behavior's @STRUCTID attribute :)
            then 
                let $structID := $behavior-by-new-path/@STRUCTID
                return update value $structID with $structID||" "||$resource-pid
            (: otherwise check if there's a behaviorSec in the mets record :)
            else
                let $behaviorSec := $project//mets:behaviorSec,
                    $new-behaviour := <mets:behavior BTYPE="{$wc:behavior-btype}" STRUCTID="{$resource-pid}">
                                        <mets:mechanism LOCTYPE="URL" xlink:href="{$path}"/>
                                      </mets:behavior>
                return 
                    if (exists($behaviorSec)) 
                    then update insert $new-behaviour into $behaviorSec
                    else update insert <mets:behaviorSec>{$new-behaviour}</mets:behaviorSec> into $project
                        
        else 
             if ($current-path eq $path)
             then ()
             else
                (:check whether there exists a new behavior element with the path to be set :)
                if (exists($behavior-by-new-path))
                then 
                    (: if yes, then just add the $resource-pid to the parent::behavior's @STRUCTID attribute ... :)
                    let $structID := $behavior-by-new-path/@STRUCTID
                    let $rm-current := resource:remove-preprocess-xsl-path($resource-pid,$project-pid)
                    return update value $structID with $structID||" "||$resource-pid
                else
                    (: check whether the current behavior element is shared with other resources :)
                    if ($behavior-by-current-path/@STRUCTID eq $resource-pid)
                    then update value $behavior-by-current-path/mets:mechanism/@xlink:href with $path
                    else 
                        let $rm-current-behavior := resource:remove-preprocess-xsl-path($resource-pid,$project-pid)
                        let $new-behavior := <mets:behavior BTYPE="{$wc:behavior-btype}" STRUCTID="{$resource-pid}">
                                                <mets:mechanism LOCTYPE="URL" xlink:href="{$path}"/>
                                              </mets:behavior>
                        return 
                            if (exists($behaviorSec)) 
                            then update insert $new-behavior into $behaviorSec
                            else update insert <mets:behaviorSec>{$new-behavior}</mets:behaviorSec> into $project
};

(: removes the resource's PID from the list of PIDs to be pre-processed by the preprocess XSL stylesheet. :)
declare function resource:remove-preprocess-xsl-path($resource-pid as xs:string, $project-pid as xs:string) as empty() {
    let $project:= project:get($project-pid),
        $current-path := resource:get-preprocess-xsl-path($resource-pid,$project-pid),
        $behavior-by-current-path := $project//mets:behavior[mets:mechanism/@xlink:href = $current-path][@BTYPE = $wc:behavior-btype]
    return
        if ($behavior-by-current-path/@STRUCTID eq $resource-pid)
        then
            if (count($behavior-by-current-path/parent::*/*) eq 1)
            then update delete $behavior-by-current-path/parent::*
            else update delete $behavior-by-current-path
        else update value $behavior-by-current-path/@STRUCTID with string-join(tokenize($behavior-by-current-path/@STRUCTID,'\s+')[. ne $resource-pid],' ')
            
};

declare function resource:get-preprocess-xsl-path($resource-pid as xs:string, $project-pid as xs:string) as xs:string? {
    let $project:= project:get($project-pid)
    let $xsl-behavior := $project//mets:behavior[@BTYPE = $wc:behavior-btype][some $x in tokenize(@STRUCTID,'\s') satisfies $x eq $resource-pid]
    return $xsl-behavior/mets:mechanism/xs:string(@xlink:href)
};


declare function resource:purge($resource-pid as xs:string, $project-pid as xs:string) as empty() {
    resource:purge($resource-pid,$project-pid,())
};

declare function resource:purge($resource-pid as xs:string, $project-pid as xs:string, $delete-data as xs:boolean*) as empty() {
    let $log := util:log-app("INFO",$config:app-name,"Purging resource "||$resource-pid||" (project "||$project-pid||")")
    let $files := resource:files($resource-pid,$project-pid)
    let $remove-data :=  
        if ($delete-data)
        then  
            for $f in $files//mets:file/mets:FLocat/xs:string(@xlink:href)
            return
                let $filename:= tokenize($f,"/")[last()],
                    $path :=    substring-before($f,"/"||$filename)
                return
                    try {   
                        (xmldb:remove($path,$filename),util:log-app("INFO",$config:app-name,"removing "||$filename||" at "||$path))
                    } catch * {
                        ()
                    }
        else ()
    let $remove-prep-xsl-path := resource:remove-preprocess-xsl-path($resource-pid,$project-pid) 
    let $remove-files := update delete $files
    let $remove-div := update delete resource:get($resource-pid,$project-pid)
    let $log := util:log-app("INFO",$config:app-name,"deleting mets:files and mets:div for "||$resource-pid||" (project "||$project-pid||")")
    return ()
};

declare function resource:generate-pid($project-pid as xs:string) as xs:string{
    resource:generate-pid($project-pid,'')
};

declare function resource:generate-pid($project-pid as xs:string, $random-seed as xs:string?) as xs:string {
    let $project:=  project:get($project-pid),
        $r-pids:=   $project//mets:div[@TYPE eq $config:PROJECT_RESOURCE_DIV_TYPE]/@ID,
        $try-newpid := count($r-pids) + 1.,
        $this:pid := $project-pid||"."||$try-newpid||$random-seed    
    return 
        if ($this:pid = $r-pids)
        then resource:generate-pid($project-pid,substring(util:uuid($random-seed),1,4))
        else $this:pid
};

(:~ checks if the passed string is not used yet as resource-pid, 
so that it can be used as a new pid :)
declare function resource:ensure-pid($project, $resource-pid-inspe as xs:string?) as xs:string {
    let $project-mets:=  project:get($project),
        $project-pid := repo-utils:get-record-pid($project),
        $pid-exists:=   $project-mets//mets:div[@TYPE eq $config:PROJECT_RESOURCE_DIV_TYPE][@ID=$resource-pid-inspe]            
    return 
        if ($pid-exists)
        then resource:ensure-pid($project-pid,$resource-pid-inspe||substring(util:uuid(util:random()),1,4))
        else $resource-pid-inspe
};

declare function resource:new-with-label($data as document-node(), $project, $resource-label as xs:string*) {
    resource:new-with-label($data, $project, $resource-label, () )
};

declare function resource:new-with-label($data as document-node(), $project, $resource-label as xs:string*, $resource-pid-inspe as xs:string?) {
    let $log := util:log-app("INFO",$config:app-name, "*** UPLOADED DATA ***")
(:    let $log := util:log-app("INFO",$config:app-name,$data/*):)
    let $log := util:log-app("INFO",$config:app-name,"$resource-label: "||$resource-label)
    let $log := util:log-app("INFO",$config:app-name,"$user: "||xmldb:get-current-user())
    let $resource-pid := resource:new($data,$project, (),$resource-pid-inspe),
        $set-label := resource:label($resource-label,$resource-pid,$project)
    return $resource-pid
};

declare function resource:new($data as document-node(), $project){
    resource:new($data,$project,(), ())
};

declare function resource:new($data as document-node(), $project, $make-fragments as xs:boolean*) as xs:string? {
    resource:new($data,$project,$make-fragments, ())
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
 : @param $project: the id of the cr-project or already the project mets-record (idempotent project:get() is applied on the parameter)
 : @param $make-fragments: flag to also generate resource fragments right away (calls rf:generate()) 
 : @param $resource-pid-inspe: optional key to be used as resource-pid. It is checked to be unique (resource:ensure-pid()) and potentially suffixed, if left empty, automatic PID will be generated
 : @return the resource-pid of the created resource  
~:)
declare function resource:new($data as document-node(), $project, $make-fragments as xs:boolean*, $resource-pid-inspe as xs:string?) as xs:string? {
    let $mets:record := project:get($project),
        $project-pid := repo-utils:get-record-pid($project),
        $mets:projectData := $mets:record//mets:fileGrp[@ID=$config:PROJECT_DATA_FILEGRP_ID],
        $mets:structMap := $mets:record//mets:structMap[@TYPE=$config:PROJECT_STRUCTMAP_TYPE and @ID=$config:PROJECT_STRUCTMAP_ID],
        $this:resource-pid := if ($resource-pid-inspe) then resource:ensure-pid($project-pid, $resource-pid-inspe) else resource:generate-pid($project-pid) 
    return
        switch (true())
            case (not(exists($mets:record))) return util:log-app("INFO",$config:app-name,"no METS-Record found in config")
            case (not(exists($mets:projectData))) return util:log-app("INFO",$config:app-name,"project data not found in mets-record for project "||$project-pid)
            default return 
                let $master_filepath := resource:master($data, $this:resource-pid, $project-pid)    
                return
                    if ($master_filepath ne '')
                    then 
                        let $this:fileGrp:= <mets:fileGrp ID="{$this:resource-pid||$config:PROJECT_RESOURCE_FILEGRP_SUFFIX}" USE="{$config:PROJECT_RESOURCE_FILEGRP_USE}"/>,
                            $this:resource:= <mets:div TYPE="{$config:PROJECT_RESOURCE_DIV_TYPE}" ID="{$this:resource-pid}" LABEL=""/>
                        let $update-data:= (update insert $this:fileGrp into $mets:projectData,
                                            update insert $this:resource into $mets:structMap/mets:div)
                        let $master_register := resource:add-master($master_filepath, $this:resource-pid, $project-pid)
                        let $log := util:log-app("INFO",$config:app-name,"registered new resource "||$this:resource-pid||" in cr-project "||$project-pid||".")
                        return
                            if ($make-fragments eq true())
                            then rf:generate($this:resource-pid,$project-pid)
                            else $this:resource-pid
                    else util:log-app("INFO",$config:app-name,"New resource "||$this:resource-pid||" could not be created.")
};

(:~ Returns the structMap entry for the resource
:)
declare function resource:get($resource-pid as xs:string,$project) as element(mets:div)? {
    let $mets:record:=project:get($project)
    return $mets:record//mets:div[@ID eq $resource-pid][@TYPE eq $config:PROJECT_RESOURCE_DIV_TYPE]    
};


(:~
 : Returns the  mets:fileGrp which contains all files of the given resource. 
~:)
declare function resource:files($resource-pid as xs:string,$project) as element(mets:fileGrp)? {
    let $mets:record:=project:get($project),
        $mets:fileGrp-by-id:=$mets:record//mets:fileGrp[@USE=$config:PROJECT_RESOURCE_FILEGRP_USE][@ID eq $resource-pid||$config:PROJECT_RESOURCE_FILEGRP_SUFFIX]
    return 
        if (exists($mets:fileGrp-by-id))
        then $mets:fileGrp-by-id
        else 
            (: fallback solution: we just fetch one fptr in the resource data and look for the <fileGrp> which it refers to :)
            let $mets:FILEID:=$mets:record//mets:div[@TYPE eq $config:PROJECT_RESOURCE_DIV_TYPE and @ID eq $resource-pid]//mets:fptr[1]/xs:string(@FILEID)            
            return $mets:record//mets:fileGrp[@USE=$config:PROJECT_RESOURCE_FILEGRP_USE and mets:file/@ID = $mets:FILEID]
};


(:~ 
 : insert or replace mets:files of resources
 : watch out: facsimile files are handled by the facs.xqm module! 
~:)
declare function resource:add-file($file as element(mets:file),$resource-pid as xs:string,$project-pid as xs:string) {
    let $mets:resourceFiles:=resource:files($resource-pid,$project-pid)
    let $this:fileID:=$file/@ID,
        $mets:file:=
            (: we try to locate files via their @USE attribute, as the composition of @IDs might change :)
            switch (true())
                case ($file/@USE = $config:RESOURCE_RESOURCEFRAGMENTS_FILE_USE) return $mets:resourceFiles//mets:file[@USE eq $config:RESOURCE_RESOURCEFRAGMENTS_FILE_USE]
                case ($file/@USE = $config:RESOURCE_WORKINGCOPY_FILE_USE) return $mets:resourceFiles//mets:file[@USE eq $config:RESOURCE_WORKINGCOPY_FILE_USE]
                case ($file/@USE = $config:RESOURCE_LOOKUPTABLE_FILE_USE) return $mets:resourceFiles//mets:file[@USE eq $config:RESOURCE_LOOKUPTABLE_FILE_USE]
                case ($file/@USE = $config:RESOURCE_MASTER_FILE_USE) return $mets:resourceFiles//mets:file[@USE eq $config:RESOURCE_MASTER_FILE_USE]  
                default return $mets:resourceFiles//mets:file[@ID eq $this:fileID] 
    return
        if (exists($mets:file))
        then (update delete $mets:file,update insert $file into $mets:resourceFiles)
        else update insert $file into $mets:resourceFiles
};

declare function resource:add-fragment($div as element(mets:div),$resource-pid as xs:string,$project-pid as xs:string) {
    let $mets:resource:=resource:get($resource-pid,$project-pid)
    let $this:fragmentID:=$div/@ID,
        $mets:div:=$mets:resource//mets:div[@ID eq $this:fragmentID],
        $facs := root($mets:div)//mets:fileGrp[@ID = $config:PROJECT_FACS_FILEGRP_ID]//mets:file[@ID = $mets:div/mets:fptr/@FILEID]
    return
        if (exists($mets:div))
        then  
            if (exists($facs))
            then 
                let $log := util:log-app("INFO",$config:app-name, "mets:div @ID "||$mets:div/@ID||" contains refence to facs "||string-join($facs/@ID,', ')||" - inserting fptrs into generated fragment.")
                let $replace := update replace $mets:div with $div
                return 
                    for $f in $facs
                    return
                        if (exists($mets:resource//mets:div[@ID eq $this:fragmentID]/mets:fptr[@FILEID eq $f/@ID]))
                        then ()
                        else update insert <mets:fptr FILEID="{$f/@ID}"/> into $mets:resource//mets:div[@ID eq $this:fragmentID]
            else 
                let $log := util:log-app("INFO",$config:app-name,'replacing existing resource fragment mets:div ID '||$this:fragmentID)
                return update replace $mets:div with $div
        else
            if (exists($mets:resource))
            then (
                update insert $div into $mets:resource,
                util:log-app("INFO",$config:app-name,"registered resourcefragment "||$this:fragmentID||" with resource "||$resource-pid)
            )
            else util:log-app("ERROR",$config:app-name,"could not locate resource w/ ID "||$resource-pid||" in "||$project-pid||".")
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
 :  - workingcopy (or wc, workincopy, workingcopies)
 :  - lookuptable
 :  - resourcefragments  
 :
 : @param $resource-pid: the PID of the resource
 : @param $project-pid: the ID of the current project or the project-mets record
 : @param $key: the key of the data to get
~:)
declare function resource:path($resource-pid as xs:string, $project, $key as xs:string) as xs:string? {
    let $file := resource:file($resource-pid, $project, $key)
    return $file/mets:FLocat/@xlink:href
};

declare function resource:file($resource-pid as xs:string, $project, $key as xs:string) as element(mets:file)? {
    let $config:=   project:get($project),
        $file:=     resource:files($resource-pid,$project),
        $use:=  
            switch($key)
                case "master"           return $config:RESOURCE_MASTER_FILE_USE
                case "wc"               return $config:RESOURCE_WORKINGCOPY_FILE_USE
                case "working copy"     return $config:RESOURCE_WORKINGCOPY_FILE_USE
                case "workingcopy"      return $config:RESOURCE_WORKINGCOPY_FILE_USE
                case "workingcopies"    return $config:RESOURCE_WORKINGCOPY_FILE_USE
                case "lookuptable"      return $config:RESOURCE_LOOKUPTABLE_FILE_USE
                case "resourcefragments"return $config:RESOURCE_RESOURCEFRAGMENTS_FILE_USE
                default                 return $key
    return $file/mets:file[@USE=$use]
};



(:~
 :  @return the mets:file-Element of the Master File.
~:)
declare function resource:get-master($resource-pid as xs:string, $project) as element(mets:file)? {
    let $mets:resource:=resource:get($resource-pid,$project),
        $mets:resource-files:=resource:files($resource-pid,$project)
    let $mets:master:=$mets:resource-files/mets:file[@USE eq $config:RESOURCE_MASTER_FILE_USE]
    return $mets:master
};

declare function resource:master($resource-pid as xs:string, $project) as document-node()? {
    let $doc := doc(resource:path($resource-pid,$project,'master'))
    return $doc
};

declare function resource:get-data($resource-pid as xs:string, $project, $type as xs:string) as document-node()? {
    let $doc := doc(resource:path($resource-pid,$project,$type))
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
                try {repo-utils:store($master_targetpath,$this:filename,$data,true(),project:get($project-pid))
                } catch * {
                   util:log-app("ERROR", $config:app-name,"master doc of resource "||$resource-pid||" could not be stored at "||$master_targetpath)
                }, 
            $this:filepath:=$master_targetpath||"/"||$this:filename
        let $chown := sm:chown(xs:anyURI($this:filepath),project:adminsaccountname($project-pid)),
            $chgrp := sm:chgrp(xs:anyURI($this:filepath),project:adminsaccountname($project-pid)),
            $chmod := sm:chmod(xs:anyURI($this:filepath), 'rwxrwxr--')
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
declare function resource:store-dmd($data as document-node(), $mdtype as xs:string,$resource-pid as xs:string?, $project) as xs:string? {
    let $this:filename := $config:RESOURCE_DMD_FILENAME_PREFIX||$resource-pid||".xml"
    let $targetpath:= replace(project:path($project,'metadata'),'/$','')||"/"||$mdtype
    let $store:= 
            try {repo-utils:store($targetpath,$this:filename,$data,true(),project:get($project))
            } catch * {
               util:log-app("INFO", $config:app-name,"metadata for resource "||$resource-pid||" could not be stored at "||$targetpath) 
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

(:~ getter and setter for dmdSec, i.e. the resources's descriptive metadata :)
declare function resource:dmd-from-id($resource-pid as xs:string,$project-pid as xs:string) as element()* {
    resource:dmd((), resource:get($resource-pid, $project-pid), doc(project:filepath($project-pid)))
};

declare function resource:dmd-from-id($type as xs:string, $resource-pid as xs:string,$project-pid as xs:string) as element()? {
    resource:dmd($type,resource:get($resource-pid, $project-pid), doc(project:filepath($project-pid)))
};
 
 
declare function resource:dmd($resource, $project) as element()? {
    resource:dmd((),$resource,$project)    
};

(:~ if reference to $resource and $project-config already available, skip the id-based resolution :)
(:~
 : @param $type the type of metadata to retrieve ("TEIHDR", "CMDI" etc)
 : @param $resource the 
 :)
declare function resource:dmd($type as xs:string?, $resource, $project) as element()? {
    (:let $resource-pid :=   typeswitch($resource) case element(mets:div) return $resource/@ID case xs:string return $resource case text() return $resource default return (),
        $project-pid :=   typeswitch($project) case element(mets:mets) return $project/@OBJID case xs:string return $project case text() return $project case attribute(OBJID) return data($project) default return (),
        $project := if ($project instance of element(mets:mets)) then $project else project:get($project-pid),
        $resource := if ($resource instance of element(mets:div)) then $resource else resource:get($resource-pid,$project-pid),:)
    let $resource-pid := repo-utils:get-record-pid($resource),
        $resource := repo-utils:get-record($resource),
        $project-pid := repo-utils:get-record-pid($project),
        $project := repo-utils:get-record($project)
    let $dmdID :=   $resource/tokenize(@DMDID,'\s+'),
      (: workaround via attribute, as the id()-function did not work - ?
        $dmdSec :=  doc(project:filepath($project-pid))//id($dmdID) :)
        $dmdSecs :=  $project//*[some $id in $dmdID satisfies @ID  = $id],        
        $dmdSec :=  if (exists($type) and $type!='') 
                    then $dmdSecs[*/@MDTYPE = $type and */@MDTYPE != 'OTHER' or */@MDTYPE='OTHER' and */@OTHERMDTYPE = $type] 
                    else ($dmdSecs[@STATUS='default'],$dmdSecs[1])[1]
    return
        if (not(exists($resource)))
        then util:log-app("ERROR",$config:app-name,"resource:dmd 2nd parameter $resource missing")
        else
        if (not(exists($project)))
        then util:log-app("ERROR",$config:app-name,"resource:dmd 3rd parameter $project missing")
        else
        if (exists($dmdSec))
        then 
            switch(true())
                case exists($dmdSec/mets:mdWrap/mets:xmlData/xi:include) 
                    return repo-utils:xinclude-to-fragment($dmdSec/mets:mdWrap/mets:xmlData/xi:include)
            
                case exists($dmdSec/mets:mdWrap) 
                    return 
                        for $x in $dmdSec//mets:xmlData/*
                        return $x
                        
                case exists($dmdSec/mets:mdRef) return 
                    let $location := $dmdSec/mets:mdRef/@xlink:href
                    return 
                        (:if (util:is-binary-doc($location))
                        then ()
                        else:) 
                            if (doc-available($location))
                            then doc($location)/*
                        else util:log-app("INFO",$config:app-name,"The Metadata for resource "||$resource-pid||" could not be retrieved from "||$location)
                
                default return util:log-app("INFO",$config:app-name,"Invalid content in Metadata Section for resource "||$resource-pid||".")
        else util:log-app("INFO",$config:app-name,"No Metadata is registered for resource "||$resource-pid||".")
};

(:~ create an empty record for a resource
using existing mdtype specific templates 
:)
declare function resource:create-dmd-from-template($resource-pid as xs:string, $project, $dmd-template as xs:string?) as empty() {

    let $template := resource:dmd-template($dmd-template)
    let $mdtype := substring-before($dmd-template,'_')    
    return if ($template) then 
            resource:dmd($resource-pid,$project,$template,$mdtype,$resource:defaultMDStoreLocation)
        else
           util:log-app("ERROR",$config:app-name,"coulnt create a md-record, dmd-template "||$dmd-template||" not available.")
};

declare function resource:dmd($resource-pid as xs:string, $project, $data as item(), $mdtype as xs:string*) as empty() {
    resource:dmd($resource-pid,$project,$data,$mdtype[1],())    
};

(:~
 : Registers a metdata file for a resource and optionally stores it to the db.
 : 
 : @param $resource-pid the PID of the resource
 : @param $project-pid the PID of the project
 : @param $data either a string with an db-path leading to an (existing) file or a xpointer expression leading to a resource fragment, a xi:include fragment, or the content of the metadata as a element or document-node.
 : @param $store-to-db possible values are 'db' (default behaviour: metdata resource is stored as an independent resource to the database and only referenced in the mets record, 'inline' (metadata resource is embedded in the project.xml) or 'xinclude' (an xi:include element is inserted pointing to $data)
 TODO implement xinclude-storage
 : @return empty()
~:)
declare function resource:dmd($resource-pid as xs:string, $project, $data as item(), $mdtype as xs:string, $store-location as xs:string?) as empty() {
    let $doc:=          project:get($project),
        $current :=     resource:dmd($resource-pid,$project),
        $data-location:=base-uri($current),
        $dmdid :=       $resource-pid||$mdtype||$config:RESOURCE_DMDID_SUFFIX,
        $dmdSec :=      $doc//mets:dmdSec[@ID = $dmdid],
        $store-location := ($store-location_param,$resource:defaultMDStoreLocation)[1],
        $store-to-db := xs:boolean($store-location='db')
    return 
        switch (true())
            (: wrong declaration of Metadata Format :)
            case not($mdtype=($resource:mdtypes,$resource:othermdtypes)) return util:log-app("ERROR",$config:app-name,"invalid value for parameter $mdtype for resource "||$resource-pid)
            
            (: $data is not a document, element node or string :)
            case (not($data instance of document-node()) and not($data instance of element()) and not($data instance of xs:string)) return util:log-app("ERROR",$config:app-name,"parameter $data has invalid type (resource "||$resource-pid||") allowed are: document-node() or element() for content, or xs:string for db-path.") 
            
            (: $data is empty > remove current content of dmd, external files and references to this dmd :)
            case (not(exists($data)) and exists($current)) return 
                let $rm-data := switch($data-location)
                                    case ($data-location eq base-uri($doc)) return update delete $current
                                    (: in-memory fragment - get the dmdSec via its ID :)
                                    case ($data-location = ('','/')) return util:log-app("DEBUG",$config:app-name,"returning in-memory-fragments by resource:dmd() is not implemented yet.") 
                                    default return xmldb:remove(util:collection-name($data),util:document-name($data)),
                    $rm-dmdSec:=update delete $doc//mets:dmdSec[@ID = $dmdid],
                    $rm-ref-attrs:= 
                        for $mdref in $doc//@DMDREF[matches(.,'\s*'||$dmdid||'\s*')] 
                        return 
                            if ($mdref = $dmdid) 
                            then update delete $mdref 
                            else update value $mdref with replace(.,$dmdid,'') 
                return ()
            (: update current content or insert new :)
            case (exists($data)) return
                (: add dmdid attribute to the resource's mets:div container :)
                let $dmdidref := 
                    if (exists($doc//mets:div[matches(@DMDID,'\s*'||$dmdid||'\s*')])) 
                    then () 
                    else 
                        let $res-div := resource:get($resource-pid,$project)
                        let $existing-dmdid := $res-div/@DMDID
                        return if (exists($existing-dmdid)) then
                            update value $existing-dmdid with $existing-dmdid||' '||$dmdid
                          else 
                            update insert attribute DMDID {$dmdid} into $res-div
                return
                (: store metadata to database and add a reference in the mets record:)
                if (exists($store-to-db) and $store-to-db)
                then
                    (: the content of the metdata is already in an external file, so we just set the mdRef (again) :)
                    if ($data instance of xs:string)
                    then  
                        if (doc-available(normalize-space($data)))
                        then 
                            let $mdRef:= 
                                if ($mdtype = $resource:mdtypes)
                                then <mdRef MDTYPE="{$mdtype}" LOCTYPE="URL" xmlns="http://www.loc.gov/METS/" xlink:href="{normalize-space($data)}"/>
                                else <mdRef MDTYPE="OTHER" OTHERMDTYPE="{$mdtype}" LOCTYPE="URL" xmlns="http://www.loc.gov/METS/" xlink:href="{normalize-space($data)}"/>
                            return
                                switch(true())
                                    case (exists($dmdSec/node())) return (update delete $dmdSec/node(), update insert $mdRef into $dmdSec)
                                    case (exists($dmdSec)) return update insert $mdRef into $dmdSec
                                    default return update insert <dmdSec ID="{$dmdid}" xmlns="http://www.loc.gov/METS/">{$mdRef}</dmdSec> following $doc//mets:dmdSec[last()]
                        else 
                            util:log-app("INFO",$config:app-name,"The metdata resource referenced in "||$data||"is not available. dmdSec-Update aborted for resource "||$resource-pid)
                    else 
                        (: $data contains metadata content, so we store it to the db and create a new mdRef :)
                        let $mdpath := resource:store-dmd(if ($data instance of document-node()) then $data else document{$data},$mdtype,$resource-pid,$project),
                            $mdRef:= 
                                if ($mdtype = $resource:mdtypes)
                                then <mdRef MDTYPE="{$mdtype}" LOCTYPE="URL" xmlns="http://www.loc.gov/METS/" xlink:href="{normalize-space($mdpath)}"/>
                                else <mdRef MDTYPE="OTHER" OTHERMDTYPE="{$mdtype}" LOCTYPE="URL" xmlns="http://www.loc.gov/METS/" xlink:href="{normalize-space($mdpath)}"/>
                        return
                            if ($mdpath!='')
                            then 
                                switch(true())
                                    case (exists($dmdSec/node())) return (update delete $dmdSec/node(), update insert $mdRef into $dmdSec)
                                    case (exists($dmdSec)) return update insert $mdRef into $dmdSec
                                    default return update insert <dmdSec ID="{$dmdid}" xmlns="http://www.loc.gov/METS/">{$mdRef}</dmdSec> following $doc//mets:dmdSec[last()]
                            else util:log-app("INFO",$config:app-name,"could not store metadata resource at "||$dmdSec)
                
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
                                    default return update insert <dmdSec ID="{$dmdid}" xmlns="http://www.loc.gov/METS/">{$mdWrap}</dmdSec> following $doc//mets:dmdSec[last()]
                            (: ... and delete the external file :)
                            return xmldb:remove(util:collection-name($doc),util:document-name($doc))
                        else util:log-app("INFO",$config:app-name, "The metdata resource referenced in "||$data||"is not available. dmdSec-Update aborted for resource "||$resource-pid)
                    
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
                                            update insert <dmdSec ID="{$dmdid}" xmlns="http://www.loc.gov/METS/">{$mdWrap}</dmdSec> following $doc//mets:dmdSec[last()]
                                (: ... and delete the external file :)
                                return xmldb:remove(util:collection-name($doc),util:document-name($doc))
                        
                        (: metadata content does not exist, so we just insert it :)
                        else
                            if (exists($dmdSec)) 
                            then update insert $mdWrap into $dmdSec
                            else update insert <dmdSec ID="{$dmdid}" xmlns="http://www.loc.gov/METS/">{$mdWrap}</dmdSec> following $doc//mets:dmdSec[last()]
        default return ()
};


declare function resource:label($resource-pid as xs:string, $project) as xs:string? {
    let $resource := resource:get($resource-pid, $project)
    return $resource/xs:string(@LABEL)[.!=""]
};

(:declare function resource:label($data as document-node(), $resource-pid as xs:string, $project-pid as xs:string) as element(cr:response)? {
    let $resource := resource:get($resource-pid, $project-pid)
    let $update :=   
        if ($data/* instance of element(cr:data))
        then (update value $resource/@LABEL with xs:string($data), true())
        else false()
    return 
        if ($update)
        then <cr:response path="/cr_xq/{$project-pid}/{$resource-pid}/label" datatype="xs:string">{$resource/xs:string(@LABEL)}</cr:response>
        else ()
};
:)

declare function resource:label($label, $resource-pid as xs:string, $project)  {
    let $resource := resource:get($resource-pid, $project)
    let $update := update value $resource/@LABEL with xs:string($label)    
    return $update    
};

(:~  :)
declare function resource:cite($resource-pid, $project-pid, $config) {
let $cite-template := config:param-value($config,'cite-template')
let $ns := config:param-value($config,'mappings')//namespaces/ns!util:declare-namespace(xs:string(@prefix),xs:anyURI(@uri))
let $today := format-date(current-dateTime(),'[D]. [M]. [Y]')
let $md := resource:dmd-from-id('TEIHDR',  $resource-pid, $project-pid)
let $link := resource:link($resource-pid, $project-pid, $config)
let $entity-label := ""
(:return $md:)
return util:eval ("<bibl>"||$cite-template||"</bibl>")
};

declare function resource:link($resource-pid, $project-pid, $config) {
    replace(config:param-value($config, 'base-url-public'),'/$','')||'/'||$project-pid||'/'||'get/'||$resource-pid
};

(:~
 : returns the logical structure of a resource  
 : as generated in the structMap.logical 
 : 
 : @param $resource-pid the pid of the resource 
 : @param $project-pid the pid of the project
 : @return   
~:)
declare function resource:get-toc($resource-pid as xs:string, $project) as element()? {
    let $toc := project:get-toc($project),
        $mets:record := project:get($project),
        $resource-ref := '#'||$resource-pid
        (:$frgs := resource:get($resource-pid, $project-pid)//mets:div[@TYPE='resourcefragment']:)
       
    let $toc-resource := $toc[@CONTENTIDS=$resource-ref]
    return if (exists($toc-resource)) then resource:do-get-toc-resolved($toc-resource,$resource-pid,$mets:record) else ()
};

declare function resource:do-get-toc-resolved($node as node(), $resource-pid as xs:string?, $mets-record as element(mets:mets)) as node()* {
    typeswitch ($node)
        case attribute() return $node
        
        case text() return $node
        
        case processing-instruction() return $node
        
        case document-node() return resource:do-get-toc-resolved($node/*, $resource-pid, $mets-record)
        
        case element(mets:fptr) return 
            for $n in $node/* 
            return resource:do-get-toc-resolved($node/*, $resource-pid, $mets-record)
        
        case element(mets:area) return 
            let $frgs := $mets-record//mets:div[@ID = $resource-pid]//mets:div[@type=$config:PROJECT_RESOURCEFRAGMENT_DIV_TYPE]
            let $rfid-first := $node/xs:string(@BEGIN),
                $rfid-last :=  $node/xs:string(@END),
                $frg-first := $mets-record//mets:div[@ID=$rfid-first],
                $frg-last := $mets-record//mets:div[@ID=$rfid-last],
                $frgs-between := $frgs[. >> $frg-first and . << $frg-last]
            return 
            	($frg-first,$frgs-between,$frg-last)/. (: the location step after the sequence eliminates duplicates, e.g. when $frg-first and $frg-last are the same element :)

        case element(mets:div) return
            switch(true())
                case (exists($node/mets:div[@TYPE=$config:PROJECT_RESOURCE_DIV_TYPE])) return 
                    <mets:structMap>{
                        for $n in $node/mets:div[@TYPE=$config:PROJECT_RESOURCE_DIV_TYPE]
                        return project:do-get-toc-resolved($n,$resource-pid,$mets-record)
                    }</mets:structMap>
                
                case ($node/@TYPE=$config:PROJECT_RESOURCE_DIV_TYPE) return
                    (: we are shadowing the $resource-pid downwards :)
                    let $resource-pid := substring-after($node/@CONTENTIDS,'#'),
                        $resource := $mets-record//mets:div[@ID = $resource-pid]
                    return element {QName(xs:string(namespace-uri($resource)),local-name($resource))} {
                        $resource/@* except $resource/(@DMDID,@CONTENTIDS,@ID),
                        $node/@ID,
                        for $n in $node/node() return resource:do-get-toc-resolved($n,$resource-pid,$mets-record)
                     }
                
                case ($node/@TYPE='resourcefragment') return 
                    for $n in $node/mets:* 
                    return resource:do-get-toc-resolved($n,$resource-pid,$mets-record)
                
                default return 
                    element {QName(xs:string(namespace-uri($node)),local-name($node))} {
                            $node/@*,
                            for $n in $node/node() 
                            return resource:do-get-toc-resolved($n,$resource-pid,$mets-record)
                       }
        
        case element() return element {QName(xs:string(namespace-uri($node)),local-name($node))} {
                            $node/@*,
                            for $n in $node/node() 
                            return resource:do-get-toc-resolved($n,$resource-pid,$mets-record)
                       }

        default return $node
};



(:~
 : Generates additional structural components (like chapters), i.e. ToC for a given resource,
 : identifying their position relative to the base resourcefragments (based on lookuptable)
 : and registers it with the resource's structMap.logical entry.
 : 
 : REQUIRES the workingcopy and lookuptable files for given resource to be in place
 : OBSOLETED BY toc:generate() 
 
 : @param $struct-xpath the xpath for the elements to be treated as structures
 : @param $struct-type the name of the structure (e.g. 'chapter')
 : @param $resource-pid the pid of the resource 
 : @param $project-pid the id of the project
 : @return the database path to the resourcefragments cache  
~:)
declare function resource:generate-toc($struct-xpath as xs:string, $struct-type as xs:string, $resource-pid as xs:string, $project-pid as xs:string) as item()* {
 let $rf-id := $resource-pid||$config:RESOURCE_RESOURCEFRAGMENT_FILEID_SUFFIX(:$config:RESOURCE_RESOURCEFRAGMENT_ID_SUFFIX:)
 let $wc  := wc:get-data ($resource-pid,$project-pid)
 let $resource-ref := '#'||$resource-pid
 let $resource-label := resource:label($resource-pid, $project-pid)
 
 let $divs := for $div in util:eval("$wc"||$struct-xpath)
        let $div-id := $div/data(@cr:id)
        (: FIXME: this needs to be configurable :)
        let $div-label:= $div/data(@n)
        let $frags := lt:lookup($div-id,$resource-pid,$project-pid)
            return <mets:div TYPE="{$struct-type}" ID="{$div-id}" LABEL="{$div-label}">
                    <mets:fptr>
                        <mets:area FILEID="{$rf-id}" BEGIN="{$frags[1]}" END="{$frags[last()]}" BETYPE="IDREF"/>
                        </mets:fptr>
                    </mets:div>

 let $struct-div := <mets:div TYPE="resource" CONTENTIDS="{$resource-ref}" LABEL="{$resource-label/text()}" >{$divs}</mets:div>


(:return $struct-div:)

   let $mets:record := project:get($project-pid),
       $mets:structMap-exists := $mets:record//mets:structMap[@TYPE=$config:PROJECT_TOC_STRUCTMAP_TYPE]
  
 return (if (not(exists($mets:record))) then util:log-app("INFO",$config:app-name,"no METS-Record found in config for "||$project-pid )
        else if(exists($mets:structMap-exists)) then 
                    if (exists($mets:structMap-exists/mets:div/mets:div[@CONTENTIDS=$resource-ref])) then 
                        update replace $mets:structMap-exists/mets:div/mets:div[@CONTENTIDS=$resource-ref] 
                               with $struct-div
                      else 
                        update insert $struct-div 
                               into $mets:structMap-exists/mets:div 
            else update insert <mets:structMap TYPE="{$config:PROJECT_TOC_STRUCTMAP_TYPE}" >
                                   <mets:div>{$struct-div}</mets:div>
                               </mets:structMap>
                        into $mets:record,
        util:log-app("INFO",$config:app-name,"generated new structure "||$struct-type||" for resource "||$resource-pid||" in cr-project "||$project-pid||"." )
     )
};

(:~ recreates working copy, resourcefragments and lookup-tables
 : @param $resource-pid the pid of the resource 
 : @param $project-pid the id of the project
~:)
declare function resource:refresh-aux-files($resource-pid as xs:string, $project-pid as xs:string){
    resource:refresh-aux-files((),$resource-pid,$project-pid)
};

(:~ recreates auxilary files working copy, resourcefragments, lookup-tables and table of content
 : 
 : @param $struct-xpath the xpath for the elements to be treated as structures
 : @param $struct-type the name of the structure (e.g. 'chapter')
 : @param $resource-pid the pid of the resource 
 : @param $project-pid the id of the project
 : @returns a sequence consisting of the results of the partial functions (wc, rf, lt, toc) + overall duration
~:)
declare function resource:refresh-aux-files($toc-indexes as xs:string*, $resource-pid as xs:string, $project-pid as xs:string){
    let $start-time := util:system-time()
    let $log := util:log-app("INFO",$config:app-name,"rebuilding auxiliary files for resource "||$resource-pid||" (project "||$project-pid||")")
    let $log := util:log-app("INFO",$config:app-name,"please bear with me, this might take a while ... ")
    return
    	if (resource:get($resource-pid,$project-pid))
    	then 
		    let $wc := wc:generate($resource-pid,$project-pid),
		        $rf := rf:generate($resource-pid, $project-pid),
		        $lt := lt:generate($resource-pid,$project-pid)
		    let $toc := 
		        if (not(exists($toc-indexes)))
		        then ()
		        else toc:generate($toc-indexes,$resource-pid,$project-pid)
		    let $stop-time := util:system-time()
		    let $duration := $stop-time - $start-time 
		    let $log := util:log-app("INFO",$config:app-name,"finished rebuilding auxiliary files for resource "||$resource-pid||" (project "||$project-pid||" in "||$duration||")") 
		    return ($wc, $rf, $lt, 'toc:'||$toc, $duration)
		else 
			let $log := util:log-app("ERROR", $config:app-name, "resource "||$resource-pid||" not found in project "||$project-pid)
			return ()
};



declare function resource:cmd($resource-pid as xs:string, $project) as element(cmd:CMD)?{
    resource:dmd("CMDI",$resource-pid,$project)
};

declare function resource:cmd($resource-pid as xs:string, $project, $data as element(cmd:CMD)?) as empty() {
    let $doc:=      project:get($project),
        $resource := resource:get($resource-pid,$project),
        $dmdSecs :=  $project//*[some $id in $dmdID satisfies @ID  = $id],
        $dmdSec :=  $dmdSecs[*/@MDTYPE='OTHER' and */@OTHERMDTYPE = "CMDI"],
        $dmdSecID := $dmdSec/@ID,
        $current:=  resource:cmd($resource-pid,$project) 
    let $location := replace(project:path($project,'metadata'),'/$','')||"/CMDI/"||$resource-pid||".xml"
    let $update := 
        if (exists($current))
        then 
            if (exists($data))
            then update replace $current with $data
            else (update delete $doc//mets:dmdSec[@ID=$dmdSecID],
                 xmldb:remove(util:collection-name($current),util:document-name($current)))
        else
            let $update-mets:= 
                if (exists($doc//mets:dmdSec[@ID = $dmdSecID]/mets:mdRef[@MDTYPE='OTHER' and @OTHERMDTYPE='CMDI']))
                then update value $doc//mets:dmdSec[@ID = $dmdSecID]/mets:mdRef[@MDTYPE='OTHER' and @OTHERMDTYPE='CMDI']/@xlink:href 
                     with $location
                else update insert 
                        <dmdSec ID="{$config:PROJECT_DMDSEC_ID}_CMDI" xmlns="http://www.loc.gov/METS/">
                            <mdRef MDTYPE="OTHER" OTHERMDTYPE="CMDI" xlink:href="{$location}" LOCTYPE="URL"/>
                        </dmdSec> 
                     following $doc//mets:metsHdr
            return xmldb:store(replace(project:path($project,'metadata'),'/$','')||"/CMDI",$resource-pid||".xml",$data)
    return ()
};


(:~
 : Returns the handle for the given resource
 : Handles are stored directly in the CMDI metadata of the resoruce as we cannot 
 : assign handles without a CMDI record.
 : 
 : @param $type: The aspect of the resource to get the handle for (Metadata, Data etc.)
 : @param $resource-pid: The PID of the resource to attatch the handle to 
 : @param $project-pid: The PID of the project 
:)
declare function resource:get-handle($type as xs:string, $resource-pid as xs:string, $project-pid as xs:string) as xs:string* {
    let $cmdi := resource:cmd($resource-pid,$project-pid),
        $resourceproxy-id := config:param-value((),"pid-resourceproxy-prefix")||$resource-pid
    let $handle := 
        switch($type)
            (: metadata defaults to the CMDI record :)
            case "metadata" return $cmdi/cmd:Header/cmd:MdSelfLink
            case "CMDI" return $cmdi/cmd:Header/cmd:MdSelfLink
            case "data" return $cmdi/cmd:Resources/cmd:ResourceProxyList/cmd:ResourceProxy[@id eq $resourceproxy-id][cmd:ResourceType = "Resource" ]/cmd:ResourceRef
            case "project" return $cmdi/cmd:Resources/cmd:IsPartOfList/cmd:IsPartOf
            default return ()
    return
        if (exists($cmdi))
        then $handle[.!=""]
        else util:log-app("ERROR",$config:app-name,"No CMDI record found for resource '"||$resource-pid||"' in project '"||$project-pid||"'")
};

(:~
 : Updates or creates handle-uris for a resource. The resource's CMDI Record has to be in place for this.
 : The target url gets constructed automatically.     
 : @param $type The aspect of the resource the handle should point to. Possible values are limited to: 
 :     - "data" (the raw data of the resource)
 :     - "CMDI" (the CMDI record of the resource), 
 :     - "teiHdr" (the teiHeader of the resource) 
 :     - "metadata" (default metadata entry, defaults to "CMDI")
 :     - "project" (declares the resource to be part of a collection or corpus: i.e. sets the "isPartOf" element AND updates the CMDI record of the collection.)
 : @param $resoruce-pid the PID of the resource
 : @param $project-pid the PID of the project 
~:)
declare function resource:set-handle($type as xs:string, $resource-pid as xs:string, $project-pid as xs:string) as item()* {
    let $cmdi := resource:cmd($resource-pid,$project-pid),
        $current := resource:get-handle($type,$resource-pid,$project-pid),
        $config := config:config($project-pid),
        $resourceproxy-id := config:param-value($config,"pid-resourceproxy-prefix")||$resource-pid,
        (: constructing the URL :)
        $target-url :=
            if ($type = "project")
            then 
                let $project-handle := project:get-handle("CMDI",$project-pid)
                return 
                    if ($project-handle!='')
                    then $project-handle
                    else 
                        let $set-handle := project:set-handle("CMDI",$project-pid)
                        return project:get-handle("CMDI",$project-pid)
            else 
                concat(
                    replace(config:param-value($config,"public-repo-baseurl"),'/$',''),
(:                    replace(config:param-value(config:module-config(),"public-repo-baseurl"),'/$',''),:)
                    (:"/",$project-pid,:)
                    "/get/",$resource-pid,"/",
                    switch($type)
                        case "metadata" return $type
                        case "CMDI" return "metadata/CMDI"
                        case "teiHdr" return "metadata/TEIHDR"
                        default return "data"
                )
    return
        if (exists($current))
        then 
            let $update-handle := handle:update($target-url,$current,$project-pid)
            return 
                if ($type != "CMDI")
                then ()
                else 
                    let $project-cmdi := project:dmd($project-pid)
                    let $project-handle := project:get-handle("CMDI",$project-pid)
                    let $set-proxy-in-project-cmdi := 
                        if (exists($project-cmdi/cmd:Resources/cmd:ResourceProxyList/cmd:ResourceProxy[@id = $resource-pid][cmd:ResourceType = "Metadata"][. = $current]))
                        then ()
                        else 
                            if (exists($project-cmdi/cmd:Resources/cmd:ResourceProxyList/cmd:ResourceProxy[@id = $resource-pid][cmd:ResourceType = "Metadata"]))
                            then update value $project-cmdi/cmd:Resources/cmd:ResourceProxyList/cmd:ResourceProxy[@id = $resource-pid][cmd:ResourceType = "Metadata"]/cmd:ResourceRef with $current
                            else   
                                if (exists($project-cmdi/cmd:Resources/cmd:ResourceProxyList))
                                then update insert  <cmd:ResourceProxy id="{$resource-pid}">
                                                        <cmd:ResourceType mimetype="application/xml">Metadata</cmd:ResourceType>
                                                        <cmd:ResourceRef>{$current}</cmd:ResourceRef>
                                                    </cmd:ResourceProxy> into $project-cmdi/cmd:Resources/cmd:ResourceProxyList
                                else util:log-app("ERROR", $config:app-name, "No cmd:ResourceProxyList found in CMD-record "||base-uri($project-cmdi))
                     let $set-is-part-of :=  
                        if ($cmdi/cmd:Resources/cmd:IsPrtOfList/cmd:IsPartOf = $project-pid)
                        then ()
                        else 
                            if (exists($cmdi/cmd:Resources/cmd:IsPartOfList))
                            then update insert <cmd:IsPartOf>{$project-handle}</cmd:IsPartOf> into $cmdi/cmd:Resources/cmd:IsPartOfList
                            else update insert <cmd:IsPartOfList><cmd:IsPartOf>{$project-handle}</cmd:IsPartOf></cmd:IsPartOfList> into $cmdi/cmd:Resources
                     return ()
        else 
            if (exists($cmdi))
            then
                let $handle-url := handle:create($target-url,$project-pid)
                return  
                    switch($type)
                        (: type metadata defaults to the CMDI record :)
                        case "metadata" return resource:set-handle("CMDI",$resource-pid,$project-pid)
                        
                        case "CMDI" return 
                            let $set-self-link := 
                                if (exists($cmdi/cmd:Header/cmd:MdSelfLink))
                                then update value $cmdi/cmd:Header/cmd:MdSelfLink with $handle-url
                                else 
                                    if (exists($cmdi/cmd:Header))
                                    then update insert <cmd:MdSelfLink>{$handle-url}</cmd:MdSelfLink> into $cmdi/cmd:Header
                                        else update insert <cmd:Header><cmd:MdSelfLink>{$handle-url}</cmd:MdSelfLink></cmd:Header> into $cmdi
                            
                            let $set-proxy-in-project-cmdi :=
                                let $project-cmdi := project:dmd($project-pid) 
                                return 
                                    if (exists($project-cmdi/cmd:Resources/cmd:ResourceProxyList/cmd:ResourceProxy[@id = $resource-pid][cmd:ResourceType = "Metadata"][. = $handle-url]))
                                    then ()
                                    else 
                                        if (exists($project-cmdi/cmd:Resources/cmd:ResourceProxyList/cmd:ResourceProxy[@id = $resource-pid][cmd:ResourceType = "Metadata"]))
                                        then update value $project-cmdi/cmd:Resources/cmd:ResourceProxyList/cmd:ResourceProxy[@id = $resource-pid][cmd:ResourceType = "Metadata"] with $handle-url
                                        else   
                                            if (exists($project-cmdi/cmd:Resources/cmd:ResourceProxyList))
                                            then update insert  <cmd:ResourceProxy id="{$resource-pid}">
                                                                    <cmd:ResourceType mimetype="application/xml">Metadata</cmd:ResourceType>
                                                                    <cmd:ResourceRef>{$handle-url}</cmd:ResourceRef>
                                                                </cmd:ResourceProxy> into $project-cmdi/cmd:Resources/cmd:ResourceProxyList
                                            else util:log-app("ERROR", $config:app-name, "No cmd:ResourceProxyList found in CMD-record "||base-uri($project-cmdi))
                             
                             let $project-handle := project:get-handle("CMDI",$project-pid)
                             return 
                                if (exists($cmdi/cmd:Resources/cmd:IsPrtOfList/cmd:IsPartOf[. = $project-pid]))
                                then ()
                                else 
                                    if (exists($cmdi/cmd:Resources/cmd:IsPartOfList))
                                    then update insert <cmd:IsPartOf>{$project-handle}</cmd:IsPartOf> into $cmdi/cmd:Resources/cmd:IsPartOfList
                                    else update insert <cmd:IsPartOfList><cmd:IsPartOf>{$project-handle}</cmd:IsPartOf></cmd:IsPartOfList> into $cmdi/cmd:Resources
                        
                        
                        case "data" return
                            let $resources := $cmdi/cmd:Resources/cmd:ResourceProxyList
                            return 
                            if (exists($resources/cmd:ResourceProxy[@id eq $resourceproxy-id][cmd:ResourceType = "Resource" ]/cmd:ResourceRef))
                            then update value $resources/cmd:ResourceProxy[@id eq $resourceproxy-id][cmd:ResourceType = "Resource" ]/cmd:ResourceRef with $handle-url
                            else
                                if (exists($resources/cmd:ResourceProxy[@id eq $resourceproxy-id][cmd:ResourceType = "Resource"]))
                                then update insert <cmd:ResourceRef>{$handle-url}</cmd:ResourceRef> following $resources/cmd:ResourceProxy[@id eq $resourceproxy-id]/cmd:ResourceType
                                else 
                                    if (exists($resources))
                                    then update insert <cmd:ResourceProxy id="{$resourceproxy-id}">
                                                            <cmd:ResourceType>Resource</cmd:ResourceType>
                                                            <cmd:ResourceRef>{$handle-url}</cmd:ResourceRef>
                                                        </cmd:ResourceProxy>
                                         into $resources
                                    else update insert <cmd:Resources>
                                                            <cmd:ResourceProxy id="{$resourceproxy-id}">
                                                                <cmd:ResourceType>Resource</cmd:ResourceType>
                                                                <cmd:ResourceRef>{$handle-url}</cmd:ResourceRef>
                                                            </cmd:ResourceProxy>
                                                       </cmd:Resources>
                                         into $cmdi
                                
                        case "project" return
                            let $set-is-part-of := 
                                (: WATCHME possibly we want one resource to be part of more than one project :)
                                if (exists($cmdi/cmd:Resources/cmd:IsPartOfList/cmd:IsPartOf))
                                then update value $cmdi/cmd:Resources/cmd:IsPartOfList/cmd:IsPartOf with $handle-url
                                else 
                                    if (exists($cmdi/cmd:Resources/cmd:IsPartOfList))
                                    then update insert <cmd:IsPartOf>{$handle-url}</cmd:IsPartOf> into $cmdi/cmd:Resources/cmd:IsPartOfList
                                    else 
                                        if (exists($cmdi/cmd:Resources))
                                        then update insert <cmd:IsPartOfList><cmd:IsPartOf>{$handle-url}</cmd:IsPartOf></cmd:IsPartOfList> into $cmdi/cmd:Resources
                                        else update insert <cmd:Resources><cmd:IsPartOfList><cmd:IsPartOf>{$handle-url}</cmd:IsPartOf></cmd:IsPartOfList></cmd:Resources> into $cmdi
                            
                            let $update-collection-cmdi := 
                                let $project-cmdi := project:dmd($project-pid),
                                    $resource-in-project := $project-cmdi//cmd:ResourceProxy[@id = $resource-pid][cmd:ResourceType="Metadata"]
                                return
                                    switch (true())
                                        case (exists($resource-in-project/cmd:ResourceRef))
                                            return update value $resource-in-project/cmd:ResourceRef with $handle-url
                                        case (exists($resource-in-project))
                                            return update insert <cmd:ResourceRef>{$handle-url}</cmd:ResourceRef> following $resource-in-project/cmd:ResourceType
                                        case (exists($cmdi/cmd:Resources/cmd:ResourceProxyList)) return
                                            update insert <cmd:ResourceProxy id="{$resource-pid}">
                                                            <cmd:ResourceType mimetype="application/xml">Metadata</cmd:ResourceType>
                                                            <cmd:ResourceRef>{$handle-url}</cmd:ResourceRef>
                                                          </cmd:ResourceProxy>
                                            into $cmdi//cmd:ResourceProxyList
                                        default return util:log-app("ERROR",$config:app-name,"No element cmd:ResourceProxyList found in CMDI Record at "||base-uri($cmdi))
                           return ()
                        
                        default return util:log-app("INFO",$config:app-name,"Unknown resource aspect '"||$type||"' in resource:set-handle() for resource '"||$resource-pid||"' in project '"||$project-pid||"'.")
            
            else util:log-app("ERROR",$config:app-name,"Can't store handle-uri for resource "||$resource-pid||" because of missing CMDI record.")
};

declare function resource:remove-handle($type as xs:string, $resource-pid as xs:string, $project-pid as xs:string) as empty() {
    let $handle-url := resource:get-handle($type,$resource-pid,$project-pid)
    return handle:remove($handle-url,$project-pid)
};


declare function resource:dmd2dc($resource-pid as xs:string, $project-pid as xs:string) as element(oai_dc:dc){
    let $dmd := resource:dmd-from-id($resource-pid,$project-pid),
        $xsl := doc(config:path("scripts")||"/dc/cmdi2dc.xsl"),
        $params := <parameters><param name='fedora-pid-namespace-prefix' value="{config:param-value(config:module-config(),'fedora-pid-namespace-prefix')}"/></parameters>
    return transform:transform($dmd,$xsl,$params)
};

(:~ this allows to fetch one of the packaged templates for metadata.
The function may move to a metadata-module yet to be created.
:)
declare function resource:dmd-template($dmd-type) {
    let $path := $config:app-root||"/modules/md/"||$dmd-type||".xml" 
    return if (doc-available($path)) then 
                doc($path)
            else
               util:log-app("ERROR",$config:app-name,"dmd-template "||$dmd-type||" not available.")
};
