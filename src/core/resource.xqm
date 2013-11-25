xquery version "3.0";

module namespace resource="http://aac.ac.at/content_repository/resource";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at "repo-utils.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace master = "http://aac.ac.at/content_repository/master" at "master.xqm";


declare namespace method="http://aac.ac.at/content_repository/resource/method";
declare namespace property="http://aac.ac.at/content_repository/resource/property";
declare namespace mets="http://www.loc.gov/METS/";
declare namespace xlink="http://www.w3.org/1999/xlink";
declare namespace fcs = "http://clarin.eu/fcs/1.0";
declare namespace cr="http://aac.ac.at/content_repository";

(: declaration of helper namespaces for better code structuring :)
declare namespace param="userinput.parameters";
declare namespace this="current.object";

declare function resource:make-file($fileid as xs:string, $filepath as xs:string, $type as xs:string) as element(mets:file) {
    let $USE:=
        switch($type)
            case "wc"           return $config:RESOURCE_WORKINGCOPY_FILE_USE
            case "fragments"    return $config:RESOURCE_RESOURCEFRAGMENTS_FILE_USE
            case "orig"         return $config:RESOURCE_MASTER_FILE_USE
            case "master"       return $config:RESOURCE_MASTER_FILE_USE 
            default             return ()
    return 
        if ($USE!='')
        then 
            <mets:file ID="{$fileid}" MIMETYPE="application/xml" USE="{$USE}">
                <mets:FLocat LOCTYPE="URL" xlink:href="{$filepath}"/>
            </mets:file>
        else ()
};


declare %method:name("purge") %method:realm("restricted") %method:groups("projecteditors,projectadmins") function resource:purge($resource-pid as xs:string, $project-pid as xs:string){
    resource:purge($resource-pid,$project-pid,())
};

declare %method:name("purge") %method:realm("restricted") %method:groups("projecteditors,projectadmins") function resource:purge($resource-pid as xs:string, $project-pid as xs:string, $delete-data as xs:boolean?) as empty() {
    if ($delete-data)
    then
        let $files := resource:get-resourcefiles($resource-pid,$project-pid)
        return  
            for $f in $files//mets:file/mets:FLocat/@xlink:href
            return
                let $filename:=tokenize($f,'/')[last()],
                    $path := substring-before($f,$filename)
                return xmldb:remove($filename,$path)
    else 
    ()
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
declare %method:name("new") %method:realm("restricted") %method:groups("projecteditors,projectadmins") function resource:new($data as document-node(), $project-pid as xs:string) as xs:string? {
    let $master:=master:store($content,current-dateTime()||".xml",(),$project-pid)
    let $mets:record:=config:config($project-pid),
        $mets:projectData:=$mets:record//mets:fileGrp[@ID=$config:PROJECT_DATA_FILEGRP_ID],
        $mets:file:=$mets:projectData//mets:file[mets:FLocat/@xlink:href=$filepath],
        $mets:structMap:=$mets:record//mets:structMap[@TYPE=$config:PROJECT_STRUCTMAP_TYPE and @ID=$config:PROJECT_STRUCTMAP_ID],
        $this:resource-pid:=
            if (exists($mets:file)) 
            then
                let $mets:resource-pid:=$mets:record//mets:div[@TYPE=$config:PROJECT_RESOURCE_DIV_TYPE and mets:fptr/@FILEID eq $mets:file/@ID]/xs:string(@ID)
                return 
                    if ($mets:resource-pid!='')
                    then ($mets:resource-pid,util:log("INFO",concat("the file ",$filepath," is already registered with cr-resource ",$mets:resource-pid)))
                    else util:uuid($filepath) 
            else "res"||substring(replace(util:uuid(),'-',''),1,20) 
    return
        switch (true())
            case (not(exists($mets:record))) return util:log("INFO","no METS-Record found in config")
            case (not(exists($mets:projectData))) return util:log("INFO","project data not found in mets-record for project "||$project-pid)
            case (util:is-binary-doc($filepath)) return util:log("INFO","the file "||$filepath||" can't be used as a cr-resource because it's a binary file")
            case not(doc-available($filepath)) return util:log("INFO","file "||$filepath||" does not exist, aborting registration")
            default return
                let $mets:projectData:=$mets:record//mets:fileGrp[@ID=$config:PROJECT_DATA_FILEGRP_ID] 
                let $this:file:= <mets:file ID="{$this:resource-pid}_master" MIMETYPE="application/xml" USE="MASTER"><mets:FLocat LOCTYPE="URL" xlink:href="{$filepath}"/></mets:file>
                let $this:fileGrp:= <mets:fileGrp ID="{$this:resource-pid}_files" USE="resourceFiles">{$this:file}</mets:fileGrp>
                let $this:div:= <mets:div TYPE="resource" ID="{$this:resource-pid}">
                                    <mets:fptr FILEID="{$this:resource-pid}_master"/>
                                </mets:div>
                
                let $update-data:= 
                    if (exists($mets:file)) 
                    then ()
                    else 
                        (util:log("INFO","registered new resource "||$this:resource-pid||" in cr-project "||$project-pid||" and associated the file "||$filepath||" with it."),
                         update insert $this:fileGrp into $mets:projectData)
                
                let $update-structure := 
                    if (exists($mets:structMap//mets:div[@ID eq $this:resource-pid]))
                    then ()
                    else
                        (update insert $this:div into $mets:structMap/mets:div,
                        util:log("INFO","added structmap for resource "||$this:resource-pid||" in cr-project "||$project-pid||".")) 
                
                return $this:resource-pid
};

declare function resource:get($resource-pid,$project-pid) as element(mets:div)? {
    let $mets:record:=config:config($project-pid)
    return $mets:record//mets:div[@TYPE eq $config:PROJECT_RESOURCE_DIV_TYPE and @ID eq $resource-pid]    
};


(:~
 : Returns the  mets:fileGrp which contains all files of the given resource. 
~:)
declare %property:name("files") %property:realm("restricted") %property:groups("projectadmins projecteditors") function resource:get-resourcefiles($resource-pid,$project-pid) as element(mets:fileGrp)? {
    let $mets:record:=config:config($project-pid),
        (: we just fetch one fptr in the resource data and look for the <fileGrp> which it refers to :)
        $mets:FILEID:=$mets:record//mets:div[@TYPE eq $config:PROJECT_RESOURCE_DIV_TYPE and @ID eq $resource-pid]//mets:fptr[1]/xs:string(@FILEID)
    return $mets:record//mets:fileGrp[@USE=$config:PROJECT_RESOURCE_FILEGRP_USE and mets:file/@ID = $mets:FILEID]    
};


declare function resource:add-file($file as element(mets:file),$resource-pid as xs:string,$context as xs:string) {
    let $mets:resourceFiles:=resource:get-resourcefiles($resource-pid,$context)
    let $this:fileID:=$file/@ID,
        $mets:file:=$mets:resourceFiles//mets:file[@ID eq $this:fileID]
    return
        if (exists($mets:file))
        then update replace $mets:file with $file
        else update insert $file into $mets:resourceFiles
};

declare function resource:add-fragment($div as element(mets:div),$resource-pid as xs:string,$context as xs:string) {
    let $mets:resource:=resource:get($resource-pid,$context)
    let $this:fragmentID:=$div/@ID,
        $mets:div:=$mets:resource//mets:div[@ID eq $this:fragmentID]
    return
        if (exists($mets:div))
        then update replace $mets:div with $div
        else update insert $div into $mets:resource
};

declare function resource:remove-file($fileid as xs:string,$resource-pid as xs:string,$context as xs:string){
    let $mets:resourceFiles:=resource:get-resourcefiles($resource-pid,$context)
    return update delete $mets:resourceFiles//mets:file[@ID eq $fileid]
}; 

(:~
 : Gets the path to the resources data specified as the third argument. 
 : This currently may be one of the following: 
 :  - master
 :  - workingcopies
 :  - lookuptables
 :  - resourcefragments  
 :
 : @param $resource-pid: the PID of the resource
 : @param $project-pid: the ID of the current project
 : @param $key: the key of the data to get
~:)
declare function resource:path($resource-pid as xs:string, $project-pid as xs:string, $key as xs:string) as xs:string? {
    let $config:=config:config($project-pid)
    let $path-from-project:=$config//param[@key=$key||".path"]/xs:string(.) 
    let $std-path :=config:path($key)
    return ($path-from-project,$std-path)[1] 
};
