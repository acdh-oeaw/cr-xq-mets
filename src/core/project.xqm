xquery version "3.0";
(:~ 
: This module provides functions for managing cr-xq objects (so called 'projects'), including:
: <ul>
:   <li>creation, modification, deletion</li> 
:   <li>import, export and exchange</li>
:   <li>validation and sanity checking</li>
: </ul>
:
: It relies on the cr-project data definion version 1.0, as expressed 
: in the mets profile at http://www.github.com/vronk/SADE/docs/crProject-profile.xml. 
: The profile also contains a sample instance which my be used for testing purposes.   
:
: It is designed to be used with a version of the cr-xq content 
: repository from September 2013 or later.
:
: @author Daniel Schopper
: @version 0.1
: @see http://www.github.com/vronk/SADE/docs/crProject-readme.md
~:)

module namespace project = "http://aac.ac.at/content_repository/project";
import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace repo-utils="http://aac.ac.at/content_repository/utils" at "repo-utils.xqm";
import module namespace resource="http://aac.ac.at/content_repository/resource" at "resource.xqm";

declare namespace mets = "http://www.loc.gov/METS/";
declare namespace mods="http://www.loc.gov/mods/v3";
declare namespace metsrights = "http://cosimo.stanford.edu/sdr/metsrights/";
declare namespace sm="http://exist-db.org/xquery/securitymanager";
declare namespace cmd="http://www.clarin.eu/cmd/";
declare namespace xlink="http://www.w3.org/1999/xlink";
declare namespace xi="http://www.w3.org/2001/XInclude";

declare namespace fcs = "http://clarin.eu/fcs/1.0";
declare namespace sru = "http://www.loc.gov/zing/srw/";
declare namespace rest="http://exquery.org/ns/restxq";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";


(: declaration of helper namespaces for better code structuring :)
declare namespace param="userinput.parameters";
declare namespace this="current.object";

declare variable $project:default-template as element(mets:mets) := 
    if (doc-available(config:path('mets.template'))) 
    then doc(config:path('mets.template'))/mets:mets 
    else doc($config:app-root||"/_project.xml")/mets:mets;
    
declare variable $project:cmdi-template as element(cmd:CMD) := 
    if (doc-available(config:path('cmd.template'))) 
    then doc(config:path('cmd.template'))/cmd:CMD 
    else doc($config:app-root||"/_cmd.xml")/cmd:CMD;

(:~
 : generated the id for a new project
~:)
declare %private function project:generate-id() as xs:string {
    'o'||translate(util:uuid(),' :','_')    
};

declare %private function project:sanitize-id($project-pid as xs:string) as xs:string {
    let $replace:=translate($project-pid,' :','_')
    return 
        xs:string(
            if (not(matches($replace,'\p{L}'))) 
            then 'o'||$replace 
            else $replace
        )
};


(:~
 : sets up two accounts plus personal groups: one with the name of the project,
 : a read-only account for public access, and one admin account with full rights 
 : to all project resources.
 : The initial passwords are set to the project-id. These are to be 
 : changed at the first login.
 : Returns true if the creation was successful, otherwise the empty sequence 
~:)
declare %private function project:create-accounts($project-pid as xs:string) as xs:boolean? {
    let $usernames:=(project:usersaccountname($project-pid),project:adminsaccountname($project-pid))
    let $new:=  
        for $username in $usernames return
            let $password:=$project-pid,
                $groups:=()
            return
                if (sm:user-exists($username))
                then (sm:passwd($username,$password),true())
                else (sm:create-account($username,$password,$groups),sm:user-exists($username))
    return ()
};

(:~
 : deletes the two project accounts. Returns true if the deletion was successful.
~:)
declare %private function project:remove-accounts($project-pid as xs:string) as empty(){
    let $usernames:=(project:usersaccountname($project-pid),project:adminsaccountname($project-pid))
    return 
        for $username in $usernames return
            if (sm:user-exists($username))
            then 
                let $rm-group := sm:remove-group($username),
                    $rm-account:= sm:remove-account($username)
                return ()
            else util:log("INFO", "user "||$username||" does not exist.")
};


(:~
:  Instanciates a new project.
:
: @return mets:mets
~:)
declare function project:new() {
    let $defaultTpl:=       $project:default-template
    return project:new($defaultTpl,())
};


declare function project:new($project-pid as xs:string) {
    let $defaultTpl:=$project:default-template
    return project:new($defaultTpl,$project-pid)
};
(:~
: Instanciates a new project, based on a given template at $template, and stores it in the database.
:
: @param $mets:template the template to create the mets-file from 
: @param $project-pid the name of the project (one Token), if empty id will be generated by project:generate-id() 
: @return the new entry, or, if the project with $project-pid already existed, the empty sequence.  
~:)
declare function project:new($data as element(mets:mets),$project-pid as xs:string?) as element(mets:mets)?  {
   if (project:get($project-pid))
   then util:log-app("INFO",$config:app-name,"Project "||$project-pid||" already exists.")
   else 
        let $this:id:=      (project:sanitize-id($project-pid),project:generate-id())[1]
        let $this:project:=     
            let $xsl:=              doc($config:app-root||'/core/'||'initProject.xsl')
            let $sw_name :=         $config:app-name-abbreviation||" ("||$config:app-name-full||")"
            let $sw_note :=         "instance at "||$config:app-root||"; version "||$config:app-version
            let $xslParams:=        <parameters>
                                        <param name="OBJID" value="{$this:id}"/>
                                        <param name="CREATEDATE" value="{current-dateTime()}"/> 
                                        <param name="RECORDSTATUS" value="{$config:PROJECT_STATUS_REVISION}"/>
                                        <param name="CREATOR.SOFTWARE.NOTE" value="{$sw_note}"/>
                                        <param name="CREATOR.SOFTWARE.NAME" value="{$sw_name}"/>
                                        <param name="CREATOR.INDIVIDUAL.NAME" value="{xmldb:get-current-user()}"/>
                                    </parameters>
            let $seed-template := transform:transform($data,$xsl,$xslParams)
            return $seed-template
            
        let $project-stored as xs:string :=  project:store($this:id,$this:project)
        return
            if ($project-stored!='')
            then 
                let $project-collection:=   project:collection($this:id)
                let $setup-accounts:=        project:create-accounts($this:id)
                let $users-groupname :=      project:usersaccountname($this:id)
                let $admin-groupname :=      project:adminsaccountname($this:id)
                let $cmdi-path := project:path($this:id,"metadata")||"/CMDI/"
                let $cmdi :=                
                    let $xsl:= doc($config:app-root||'/core/'||'initCMDI.xsl'),
                        $xs_params := <parameters>
                                        <param name="project-pid" value="{$this:id}"/>
                                        <param name="MdCreationDate" value="{fn:format-date(current-date(),'[Y0000]-[M00]-[D00]')}"/>  
                                        <param name="MdCreator" value="{xmldb:get-current-user()}"/>
                                        <param name="MdCollectionDisplayName" value="{config:param-value($this:project,"public-repo-displayname")}"/>
                                        <param name="project-LandingPage" value="{config:param-value($this:project,"public-project-baseurl")}"/>
                                        <param name="project-Website" value="{config:param-value($this:project,"public-project-baseurl")}"/>
                                    </parameters>
                    let $cmdi-seed := transform:transform($project:cmdi-template,$xsl,$xs_params)
                    let $stored := repo-utils:store($cmdi-path,$this:id||".xml",$cmdi-seed,true(),())
                    return () 
                let $set-permissions:=       ((: set permissions on project.xml document :)
                                              sm:chown(xs:anyURI($project-stored),$admin-groupname),
                                              sm:chgrp(xs:anyURI($project-stored),$admin-groupname),
                                              sm:chmod(xs:anyURI($project-stored),'rwxrwxr-x'),
                                              sm:add-user-ace(xs:anyURI($project-stored), $users-groupname, true(), 'r-x'),
                                              sm:add-group-ace(xs:anyURI($project-stored), $users-groupname, true(), 'r-x'),
                                              sm:add-user-ace(xs:anyURI($project-stored), $config:cr-writer-accountname, true(), 'rwx'),
                                              if (sm:user-exists("cr-xq"))
                                              then sm:add-user-ace(xs:anyURI($project-stored), "cr-xq", true(), 'rwx')
                                              else (),
                                              
                                              (: set permissions on {$cr-projects}/project collection :)
                                              sm:chown(xs:anyURI($project-collection),$admin-groupname),
                                              sm:chgrp(xs:anyURI($project-collection),$admin-groupname),
                                              sm:chmod(xs:anyURI($project-collection),'rwxrwxr-x'),
                                              sm:add-user-ace($project-collection, $users-groupname, true(), 'r-x'),
                                              sm:add-group-ace($project-collection, $users-groupname, true(), 'r-x'),
                                              sm:add-user-ace($project-collection, $config:cr-writer-accountname, true(), 'rwx'),
                                              if (sm:user-exists("cr-xq"))
                                              then sm:add-user-ace($project-collection, "cr-xq", true(), 'rwx')
                                              else (),
                                              
                                              (: set permissions on CMDI record and collection :)
                                              sm:chown(xs:anyURI($cmdi-path||$this:id||".xml"),$admin-groupname),
                                              sm:chgrp(xs:anyURI($cmdi-path||$this:id||".xml"),$admin-groupname),
                                              sm:chmod(xs:anyURI($cmdi-path||$this:id||".xml"),'rwxrwxr-x'),
                                              sm:chown(xs:anyURI($cmdi-path),$admin-groupname),
                                              sm:chgrp(xs:anyURI($cmdi-path),$admin-groupname),
                                              sm:chmod(xs:anyURI($cmdi-path),'rwxrwxr-x'),
                                              sm:add-user-ace($cmdi-path, $users-groupname, true(), 'r-x'),
                                              sm:add-group-ace($cmdi-path, $users-groupname, true(), 'r-x'),
                                              sm:add-user-ace($cmdi-path, $config:cr-writer-accountname, true(), 'rwx'),
                                              if (sm:user-exists("cr-xq"))
                                              then sm:add-user-ace($cmdi-path, "cr-xq", true(), 'rwx')
                                              else ()
                                             )
                let $prepare-structure:=     project:structure($this:id,"prepare")
                let $content-acl :=          project:acl($this:id,project:default-acl($this:id))
                return project:get($this:id)
            else 
                util:log("INFO","Project "||$this:id||" could not be instanciated.")
};

declare function project:label($project-pid as xs:string) as element(data) {
    let $doc := project:get($project-pid)
    return <data request="/cr_xq/{$project-pid}/label" datatype="xs:string">{$doc/xs:string(@LABEL)}</data>
}; 


declare function project:label($project-pid as xs:string, $data as document-node()) as document-node() {
    let $current := project:get($project-pid)/@LABEL
    let $update := update value $current with xs:string($data)
    return $data
}; 

declare function project:available($project-pid as xs:string) as xs:boolean {
    project:status($project-pid) = $config:PROJECT_STATUS_AVAILABLE
};

(:~
 : Getter function for projects: Every cr_xq project must have a repository-wide unique PID of type xs:string, 
 : which is stored in mets:mets/@OBJID.
 : The lookup is performed first in the path configured as config:path("projects"), 
 : if this lookup returns nothing, the lookup context is extended to the database root.
 :
 : @param $project the PID of the project to look up (or the already looked-up project
 : @return zero or one cr_xq object.
~:)
declare function project:get($project) as element(mets:mets)? {
    if ($project instance of  element(mets:mets)) then $project
        else 
           let $project_ := collection(config:path("projects"))//mets:mets[@OBJID eq $project]    
           return
            if (count($project) gt 1)
            then 
                let $log:=(util:log-app("WARN",$config:app-name, "project-id corruption: found more than 1 project with id "||$project||"."),for $p in $project return base-uri($p))
                return $project_[1]
            else $project_
            
                          
};

declare function project:usersaccountname($project-pid as xs:string) as xs:string {
    $config:PROJECT_ACCOUNTS_USER_ACCOUNTNAME_PREFIX||$project-pid||$config:PROJECT_ACCOUNTS_USER_ACCOUNTNAME_SUFFIX
};

declare function project:adminsaccountname($project-pid as xs:string) as xs:string {
    $config:PROJECT_ACCOUNTS_ADMIN_ACCOUNTNAME_PREFIX||$project-pid||$config:PROJECT_ACCOUNTS_ADMIN_ACCOUNTNAME_SUFFIX
};

(:~
 : Prepares the structure for a new project or deletes the data of an existing one
~:)
declare %private function project:structure($project-pid as xs:string, $action as xs:string) {
    let $admin-accountname := project:adminsaccountname($project-pid),
        $admin-groupname := project:adminsaccountname($project-pid),
        $users-accountname := project:usersaccountname($project-pid),
        $users-groupname := project:usersaccountname($project-pid)
    let $paths:=(
        project:path($project-pid,"data"),
        project:path($project-pid,"workingcopies"),
        project:path($project-pid,"lookuptables"),
        project:path($project-pid,"resourcefragments"),
        project:path($project-pid,"metadata")
    )
    return
    switch($action)
    case 'prepare' return 
        for $p in $paths return
            let $uri := xs:anyURI($p),
                (:paths returned by project:path() are always up to the project's specific collection, 
    so we strip the last step here:)
                $col := replace($p,$project-pid||"/?$","")
            let $mk :=  repo-utils:mkcol("/",$col||"/"||$project-pid),
                $set-owner := sm:chown($uri, $admin-accountname),
                $set-group := sm:chgrp($uri, $admin-groupname),
                $set-acls:= (
                             sm:add-group-ace($uri, $users-groupname, true(), 'rx'),
                             sm:add-group-ace($uri, $users-groupname, true(), 'rx'),
                             sm:add-group-ace($uri, $users-groupname, false(), 'w'),
                             if (sm:user-exists("cr-xq"))
                             then sm:add-user-ace($uri, "cr-xq", true(), 'rwx')
                             else (),
                             sm:add-user-ace($uri, $config:cr-writer-accountname, true(), 'rwx'))
            return ()
    case 'remove' return
        let $paths:= (config:path("data")||"/"||$project-pid,
                    config:path("workingcopies")||"/"||$project-pid,
                    config:path("lookuptables")||"/"||$project-pid,
                    config:path("resourcefragments")||"/"||$project-pid,
                    config:path("metadata")||"/"||$project-pid)
        return 
            for $p in $paths 
            return 
                if (xmldb:collection-available($p))
                then xmldb:remove($p)
                else ()
    default return ()
};

(:~
 : returns the paths to various contents of a project by configuration. 
 : This function does not check existence of collections, nor does it 
 : check whether the paths are registered in the mets object. It can be 
 : used as a constructor function for new resources.
~:)
declare function project:path($project-pid as xs:string, $key as xs:string) as xs:string? {
    let $project-config:=project:parameters($project-pid)//param[@key=$key||".path"]/xs:string(.),
        $global-key := 
            switch($key)
                case "workingcopy" return "workingcopies"
                case "lookuptable" return "lookuptables"
                case "master"       return "data"
                case "resourcefragment"       return "resourcefragments"
                case "home"         return "projects"
                default return $key
    let $default := config:path($global-key)
    return 
        switch(true())
            case exists($project-config) return $project-config
            case exists($default)        return $default||"/"||$project-pid
            default                      return ()
};

(:~
 : Stores the project's mets record in the database and returns the path 
 : to the newly created document. The base path is either read from the mets record
 : param 'project.home' or set by config:path('projects')
 : 
 : @param $mets:record the mets:file
 : @return database path to the new file 
~:)
declare %private function project:store($project-pid as xs:string, $mets:record as element(mets:mets)) as xs:string? {
    let $col :=     replace($mets:record//param[@key='project.home'],$project-pid||"/?$",'')
    let $base :=    if ($col!='') then $col else config:path('projects'),
        $mkdir:=    repo-utils:mkcol($base,$project-pid)
    let $path:=     try {
                        xmldb:store($base||"/"||$project-pid,"project.xml",$mets:record)
                    } catch * {
                        ()
                    }
    return 
        if ($path='')
        then
            let $rm-col := xmldb:remove($base||"/"||$project-pid) 
            return util:log("INFO","Could not store project "||$project-pid||" to collection "||$base||".") 
        else $path
};



(:~
: Renames the project and its data, setting a new identifier and renaming the 
: collection structure.
: 
: @return the uri of the new project collection containing the cr-catalog.
~:)
declare function project:rename($project-pid as xs:string, $newId as xs:string) as element(mets:mets) {
    () (:TODO:)
};



(:~
: Imports a cr-archive (a zip file containing a whole cr-project) into the content repository.
:
: @param $archive the zipped cr-archive to be imported.
: @return the project.xml of the imported project
~:)
declare function project:import($archive as xs:base64Binary) as element(mets:mets)? {
    
    () (:TODO:)
};


(:~
: Exports the whole content of a project as a zip file. 
: This includes: 
:    - the content of project-home, including the project.xml METS record 
:    - content of every mets:file reference, when it's @xlink:href starts with "/db"
:    - content of relevant xconfig-files in /db/system/config/db... 
: The files 
:
: @param $project-pid the PID of the cr-project to be exported
: @return the self-contained cr-archive.
~:)
declare function project:export($project-pid as xs:string) as xs:base64Binary? {
    let $doc := project:get($project-pid)
    let $grammar-location := $config:app-root||"/mets.xsd"
    let $files-project-home := for $f in xmldb:xcollection(config:path("project-home")) return base-uri($f)  
    (:TODO validate:)
    return ()
};

(:~
 : Sends
~:)
declare function project:publish($project-pid as xs:string, $archive as xs:base64Binary, $cr-endpoint as xs:anyURI) as xs:boolean {
    ()(:TODO:)
};


declare function project:collection($project-pid as xs:string) as xs:string? {
    util:collection-name(project:get($project-pid))
};

(:~
 : Returns the path to a project's mets records by retrieving via its @OBJID.
 : This enables us to set the projects own path in its mets:techMD-section. 
~:)
declare function project:filepath($project-pid as xs:string) as xs:string? {
    base-uri(project:get($project-pid))
};

declare function project:filepath($project-pid as xs:string) as xs:string? {
    if (exists(collection(config:path("projects"))//mets:mets[@OBJID = $project-pid]))
    then base-uri(collection(config:path("projects"))//mets:mets[@OBJID = $project-pid])
    else base-uri(collection("/db")//mets:mets[@OBJID = $project-pid])
};

(:~
: removes the cr-project from the content repository without removing the project's resources.
:
: @param $config the uri of the cr-catalog to be removed
: @return true if projec 
~:)
declare function project:purge($project-pid as xs:string) as empty() {
    project:purge($project-pid,())
};

(:~
: removes the cr-project from the content repository, possibly also removing the project's data.
: 
: @param $config the uri of the cr-catalog to be removed
: @param $delete-data should the project's data be removed? (default: 'no')
: @return empty()
~:)
declare function project:purge($project-pid as xs:string, $delete-data as xs:boolean*) as empty() {
   if (exists(project:get($project-pid)))
   then
        let $delete-data := ($delete-data,false())[1]
        return
             if ($delete-data)
             then     
                  let $base :=          config:path('projects')
                  let $rm-structure :=  project:structure($project-pid,'remove'),
                      $rm-indizes :=    for $x in xmldb:get-child-resources(config:path("indexes"))[starts-with(.,"index-"||$project-pid)]
                                        return xmldb:remove(config:path("indexes"),$x)
                  let $project-dir :=    project:collection($project-pid),
                      $rm-project-dir := if ($project-dir!='') then xmldb:remove($project-dir) else ()
                  let $log :=           util:log("INFO","current user: "||xmldb:get-current-user())
                  let $log :=           util:log("INFO","project-dir: "||$project-dir)
                  let $rm-accounts :=   project:remove-accounts($project-pid)
                  return ()
              else 
                 let $update-status := project:status($project-pid,'removed')
                 return ()
    else ()
};



(:~
 : sets the status of the project
~:)
declare function project:status($project-pid as xs:string, $data as xs:string) as xs:string {
    let $project:=          project:get($project-pid),
        $definedStatus :=   project:statusmap()
    return
        if (exists($project))
        then 
            let $update := update value $project/mets:metsHdr/@RECORDSTATUS with $data
            return $data
        else util:log("INFO","unknown project '"||$project-pid||"'.")
};

(:~
 : gets the status of the project, empty string if project does not exist
~:)
declare function project:status($project-pid as xs:string) as element(data) {
    let $project:=project:get($project-pid)
    let $status:=$project/mets:metsHdr/xs:string(@RECORDSTATUS)
    return <data request="/cr_xq/{$project-pid}/status" datatype="xs:string">{$status}</data>
};

declare %private function project:statusmap() as map() {
    map:new(
        for $s at $pos in (
            $config:PROJECT_STATUS_AVAILABLE,
            $config:PROJECT_STATUS_REVISION,
            $config:PROJECT_STATUS_RESTRICTED,
            $config:PROJECT_STATUS_REMOVED)
        return map:entry($s, $pos)
    )
};


(:~
 : gets the status of the project as a numerical code
~:)
declare function project:status-code($project-pid as xs:string) as element(data) {
    let $status:=project:status($project-pid),
        $code := map:get(project:statusmap(),$status)
    return <data request="/cr_xq/{$project-pid}/status-code" datatype="xs:integer">{$code}</data>
};



(:~
 : sets the status of the project as a numerical code 
~:)
declare function project:status-code($project-pid as xs:string, $data as xs:integer) as empty() {
    let $project:=          project:get($project-pid),
        $definedStatus :=   for $k in map:keys(project:statusmap())
                            let $val:=map:get(project:statusmap(),$k)
                            return 
                                if ($val = $data) 
                                then $k
                                else ()
    return
        if (exists($definedStatus) and exists($project))
        then (update value $project/mets:metsHdr/@RECORDSTATUS with $definedStatus,true())
        else ()
};

declare function project:list-defined-status() as element(status){
    <list>{
        for $name in map:keys(project:statusmap())
        let $code := map:get(project:statusmap(),$name)
        order by $code ascending
        return <status code="{$code}">{$name}</status>
    }</list>
};


(:~
 : lists all resources of a given project as their mets:divs.
 : 
 : @param $config the mets-config of a project 
~:)
declare function project:resources($project-pid as xs:string) as element(mets:div)* {
    let $doc:=project:get($project-pid)
    let $structMap:=$doc//mets:structMap[@ID eq $config:PROJECT_STRUCTMAP_ID and @TYPE eq $config:PROJECT_STRUCTMAP_TYPE]
    return <data>{$structMap//mets:div[@TYPE eq $config:PROJECT_RESOURCE_DIV_TYPE]}</data>
};

(:~ reads the resource sequence from the project-configuration
CHECK: need wrapped in mets:structMap element or just sequence? 
@param $project if $project is string, it is treated as project-id and the project-config is fetched otherwise treated as already resolved project-config document
:)
declare function project:list-resources($project) as element(mets:div)* {
    let $doc:=  if ($project instance of xs:string) 
                then project:get($project)
                else $project   
    let $structMap:=$doc//mets:structMap[@ID eq $config:PROJECT_STRUCTMAP_ID and @TYPE eq $config:PROJECT_STRUCTMAP_TYPE]
(:    return <mets:structMap>{$structMap//mets:div[@TYPE eq $config:PROJECT_RESOURCE_DIV_TYPE]}</mets:structMap>:)
    return $structMap//mets:div[@TYPE eq $config:PROJECT_RESOURCE_DIV_TYPE]

};

declare function project:list-resources-resolved($project) as element(sru:searchRetrieveResponse)* {
    let $start-time := util:system-dateTime()
    let $doc:=  if ($project instance of xs:string) 
                then project:get($project)
                else $project
    let $ress := project:list-resources($doc)
    let $project-id := $doc/@OBJID
    let $count := count($ress)
    let $resources := for $res in $ress 
        let $dmd := resource:dmd($res, $project )
        let $res-id := $res/data(@ID)
        let $indexImage-path := resource:path($res-id, $project-id, 'indexImage')
        order by $res/@ORDER
        return <fcs:Resource pid="{$res-id}" >
                 <fcs:DataView type="metadata">{$dmd}</fcs:DataView>
                 <fcs:DataView type="image" ref="{$indexImage-path}" />
               </fcs:Resource>
    
     let $end-time := util:system-dateTime()
(:<sru:baseUrl>{repo-utils:config-value($config, "base.url")}</sru:baseUrl>:)
return <sru:searchRetrieveResponse>
            <sru:version>1.2</sru:version>
            <sru:numberOfRecords>{$count}</sru:numberOfRecords>
                            <sru:echoedSearchRetrieveRequest>
                                <sru:version>1.2</sru:version>
                                <sru:query>*</sru:query>
                                <fcs:x-context>{$project-id}</fcs:x-context>
                                <fcs:x-dataview>metadata</fcs:x-dataview>
                                <sru:startRecord>1</sru:startRecord>
                                <sru:maximumRecords>0</sru:maximumRecords>
                            </sru:echoedSearchRetrieveRequest>
                            <sru:extraResponseData>
                              	<fcs:returnedRecords>{$count}</fcs:returnedRecords>                                
                                <fcs:duration>{$end-time - $start-time }</fcs:duration>                                
                            </sru:extraResponseData>
                            <sru:records>
                            {for $res at $pos in $resources
                                    return  <sru:record>
                                	              <sru:recordSchema>http://clarin.eu/fcs/1.0/Resource.xsd</sru:recordSchema>
                                	              <sru:recordPacking>xml</sru:recordPacking>
                                	              <sru:recordData>{$res}</sru:recordData>
                                	              <sru:recordPosition>{$pos}</sru:recordPosition>
                                	              <sru:recordIdentifier>{xs:string($res/@pid)}</sru:recordIdentifier>
                                	          </sru:record> }                                	          
                             </sru:records>                            
                        </sru:searchRetrieveResponse>
};

(:~
 : lists the ids of all resources in given project.
 : 
 : @param $config the mets-config of a project 
~:)
declare function project:resource-pids($project-pid as xs:string) as xs:string* {
    let $resources:=project:resources($project-pid)
    return $resources//@ID
};

(:~ returns the resource-pids based on the resource sequence from the project-configuration, wrapped in mets:structMap element 
@param $project if $project is string, it is treated as project-id and the project-config is fetched otherwise treated as already resolved project-config document
:)
declare function project:list-resource-pids($project) as xs:string* {
    let $doc:=if ($project instance of xs:string) then project:get($project)
                   else $project
                   
    let $structMap:=$doc//mets:structMap[@ID eq $config:PROJECT_STRUCTMAP_ID and @TYPE eq $config:PROJECT_STRUCTMAP_TYPE]
    return $structMap//mets:div[@TYPE eq $config:PROJECT_RESOURCE_DIV_TYPE]/xs:string(@ID)
};



(: getter and setter for mets Header :)
declare function project:metsHdr($project-pid as xs:string) as element(mets:metsHdr){
    let $doc:=project:get($project-pid)
    return $doc/mets:metsHdr
};

declare function project:metsHdr($project-pid as xs:string, $data as element(mets:metsHdr)) as empty() {
    let $doc:=      project:get($project-pid),
        $current:=  project:metsHdr($project-pid)
    let $update := 
        if (exists($current))
        then 
            if (exists($data))
            then update replace $current with $data
            else update delete $current
        else update insert $data into $doc
    return ()
};



(:~ getter and setter for mets dmdSec, i.e. the project's CMDI record
 : @param $project the PID of the project or the mets:mets entry
 :)
declare function project:dmd($project) as element(cmd:CMD)? {
    let $project := repo-utils:get-record($project),
        $dmdSec := $project//mets:dmdSec[@ID = $config:PROJECT_DMDSEC_ID]
    return 
        if (doc-available($dmdSec/mets:mdRef[@MDTYPE = 'OTHER'][@OTHERMDTYPE = 'CMDI']/@xlink:href))
        then doc($dmdSec/mets:mdRef[@MDTYPE = 'OTHER'][@OTHERMDTYPE = 'CMDI']/@xlink:href)/cmd:CMD
        else ()
};

declare function project:dmd($project, $data as element(cmd:CMD)?) as empty() {    
    let $doc:=      repo-utils:get-record($project),
        $project-pid := $doc/xs:string(@OBJID),
        $current:=  project:dmd($project),
        $dmdSec := $doc//mets:dmdSec[@ID = $config:PROJECT_DMDSEC_ID]
    return
        if (exists($current))
        then 
            if (exists($data))
            then update value $current with $data
            else (update delete $dmdSec/mets:mdRef[@MDTYPE = 'OTHER'][@OTHERMDTYPE = 'CMDI'],xmldb:remove(util:collection-name($current),util:document-name($current)))
        else
            let $path := 
                if (exists($dmdSec/mets:mdRef[@MDTYPE = 'OTHER'][@OTHERMDTYPE = 'CMDI']/@xlink:href))
                then $dmdSec/mets:mdRef[@MDTYPE = 'OTHER'][@OTHERMDTYPE = 'CMDI']/@xlink:href
                else replace(project:path($project-pid,'metadata'),'/$','')||"/CMDI/"||$project-pid||".xml"
            let $href-toks := tokenize($path,'/'),
                $filename := $href-toks[last()],
                $collection:= substring-before($path,"/"||$filename)
            let $mk-col := repo-utils:mkcol("/",$collection),
                $store-data := repo-utils:store($collection,$filename,$data,false(),())
            return 
                switch(true())
                    case (exists($dmdSec/mets:mdRef[@MDTYPE = 'OTHER'][@OTHERMDTYPE = 'CMDI']/@xlink:href)) 
                        return ()
                    case (exists($dmdSec/mets:mdRef[@MDTYPE = 'OTHER'][@OTHERMDTYPE = 'CMDI'])) 
                        return update insert attribute {"xlink:href"} {$path} into $dmdSec/mets:mdRef[@MDTYPE = 'OTHER'][@OTHERMDTYPE = 'CMDI']
                    case (exists($dmdSec))
                        return update insert <mets:mdRef MDTYPE="OTHER" OTHERMDTYPE="CMDI" LOCTYPE="URL" xlink:href="{$path}"/> into $dmdSec
                    default return update insert <mets:dmdSec ID="{$config:PROJECT_DMDSEC_ID}"><mets:mdRef MDTYPE="OTHER" OTHERMDTYPE="CMDI" LOCTYPE="URL" xlink:href="{$path}"/></mets:dmdSec> following $doc/mets:metsHdr
                        
 };


(: getter and setter for index-map :)
declare function project:map($project) as element(map)? {
    let $doc:=project:get($project)
    return $doc//mets:techMD[@ID=$config:PROJECT_MAPPINGS_ID]/mets:mdWrap/mets:xmlData/*
};

declare function project:map($project-pid as xs:string, $data as element(map)) as empty() {
    let $doc:=      project:get($project-pid),
        $current:=  project:map($project-pid)
    return 
        if (exists($current))
        then
            if (exists($data))
            then update replace $current with $data
            else update delete $current
        else
            if (exists($doc//mets:techMD[@ID=$config:PROJECT_MAPPINGS_ID]))
            then update value $doc//mets:techMD[@ID=$config:PROJECT_MAPPINGS_ID]
                 with <mdWrap MDTYPE="OTHER" xmlns="http://www.loc.gov/METS/"><xmlData>{$data}</xmlData></mdWrap>
            else update insert <techMD ID="{$config:PROJECT_MAPPINGS_ID}" xmlns="http://www.loc.gov/METS/"><mdWrap MDTYPE="OTHER"><xmlData>{$data}</xmlData></mdWrap></techMD> into $doc//mets:amdSec[@ID eq $config:PROJECT_AMDSEC_ID]
};

(: getter and setter for project parameters :)
declare function project:parameters($project-pid as xs:string) as element(param)* {
    let $doc:=project:get($project-pid)
    return $doc//mets:techMD[@ID=$config:PROJECT_PARAMETERS_ID]/mets:mdWrap/mets:xmlData/param
};

declare function project:parameters($project-pid as xs:string, $data as element(param)*) as empty() {
    let $doc:=      project:get($project-pid),
        $current:=  project:parameters($project-pid)
    return 
        if (exists($current))
        then 
            if (exists($data))
            then update replace $current with $data
            else update delete $current
        else
            if (exists($doc//mets:techMD[@ID=$config:PROJECT_PARAMETERS_ID]))
            then
                update value $doc//mets:techMD[@ID=$config:PROJECT_PARAMETERS_ID]
                with <mdWrap MDTYPE="OTHER" xmlns="http://www.loc.gov/METS/"><xmlData>{$data}</xmlData></mdWrap>
            else update insert <techMD ID="{$config:PROJECT_PARAMETERS_ID}" xmlns="http://www.loc.gov/METS/" GROUPID="config.xml"><mdWrap MDTYPE="OTHER"><xmlData>{$data}</xmlData></mdWrap></techMD> into $doc//mets:amdSec[@ID eq $config:PROJECT_AMDSEC_ID]
};

(: getter and setter for a project's module configuration :)
(: TODO WRITE ACTUAL PATHS AT PROJECT INITIALIZATION :)
declare function project:moduleconfig($project-pid as xs:string) as element(module)* {
    let $doc:=project:get($project-pid)
    return $doc//mets:techMD[@ID=$config:PROJECT_MODULECONFIG_ID]/mets:mdWrap/mets:xmlData/module
};

declare function project:moduleconfig($project-pid as xs:string, $data as element(module)*) as empty() {
    let $doc:=      project:get($project-pid),
        $current:=  project:moduleconfig($project-pid)
    return 
        if (exists($current))
        then 
            if (exists($data))
            then update replace $current with $data
            else update delete $current
        else
            if (exists($doc//mets:techMD[@ID=$config:PROJECT_MODULECONFIG_ID]))
            then
                update value $doc//mets:techMD[@ID=$config:PROJECT_MODULECONFIG_ID]
                with <mdWrap MDTYPE="OTHER" xmlns="http://www.loc.gov/METS/"><xmlData>{$data}</xmlData></mdWrap>
            else 
                let $wrapped := <techMD ID="{$config:PROJECT_MODULECONFIG_ID}" xmlns="http://www.loc.gov/METS/" GROUPID="config.xml"><mdWrap MDTYPE="OTHER"><xmlData>{$data}</xmlData></mdWrap></techMD>
                return 
                    update insert $wrapped 
                    into $doc//mets:amdSec[@ID eq $config:PROJECT_AMDSEC_ID]
};

declare %private function project:default-acl($project-pid as xs:string) as element(sm:permission) {
    <sm:permission xmlns:sm="http://exist-db.org/xquery/securitymanager" owner="{project:adminsaccountname($project-pid)}" group="{project:adminsaccountname($project-pid)}" mode="rwx------">
        <sm:acl entries="3">
            <!-- sm:ace/@who='other' _must_ be present  -->
            <sm:ace index="0" target="GROUP" who="other" access_type="DENIED" mode="rwx"/>
            <sm:ace index="1" target="GROUP" who="{project:adminsaccountname($project-pid)}" access_type="ALLOWED" mode="rwx"/>
            <sm:ace index="2" target="GROUP" who="{project:usersaccountname($project-pid)}" access_type="ALLOWED" mode="r-x"/>
        </sm:acl>
    </sm:permission>
};


(: getter and setter for rightsMD :)
declare function project:license($project) as element(cmd:License)? {
    let $dmd := project:dmd($project)
    return $dmd//cmd:License
};

declare function project:license($project, $data as element(cmd:License)?) as empty() {
     let $dmd := project:dmd($project),
         $doc:=repo-utils:get-record($project),
         $current:=  project:license($project)
    return 
        if (exists($current))
        then 
            if (exists($data)) 
            then 
                let $update-data := update replace $current with $data
                return 
                    switch(true())
                        case (exists($doc//mets:rightsMD[@ID=$config:PROJECT_RIGHTSMD_ID]/*)) 
                            return update value $doc//mets:rightsMD[@ID=$config:PROJECT_RIGHTSMD_ID]
                                   with <mets:mdRef MDTYPE="OTHER" OTHERMDTYPE="CMDI" LOCTYPE="URL" xlink:href="{base-uri($dmd)}" XPTR="xpointer(/cmd:CMD/cmd:Components/cmd:collection/cmd:License) xmlns(cmd=http://www.clarin.eu/cmd/)"/>
                        case (exists($doc//mets:rightsMD[@ID=$config:PROJECT_RIGHTSMD_ID]))
                            return update insert <mets:mdRef MDTYPE="OTHER" OTHERMDTYPE="CMDI" LOCTYPE="URL" xlink:href="{base-uri($dmd)}" XPTR="xpointer(/cmd:CMD/cmd:Components/cmd:collection/cmd:License) xmlns(cmd=http://www.clarin.eu/cmd/)"/>
                                   into $doc//mets:rightsMD[@ID=$config:PROJECT_RIGHTSMD_ID]
                        default 
                            return update insert 
                                        <mets:techMD ID="{$config:PROJECT_RIGHTSMD_ID}">
                                            <mets:mdRef MDTYPE="OTHER" OTHERMDTYPE="CMDI" LOCTYPE="URL" xlink:href="{base-uri($dmd)}" XPTR="xpointer(/cmd:CMD/cmd:Components/cmd:collection/cmd:License) xmlns(cmd=http://www.clarin.eu/cmd/)"/>
                                        </mets:techMD>
                                    into $doc//mets:amdSec[@ID eq $config:PROJECT_AMDSEC_ID]
            else (update delete $doc//mets:rightsMD[@ID=$config:PROJECT_RIGHTSMD_ID]/*, update delete $current/cmd:*/node())
        else
            let $update-dmd :=
                if (exists($dmd))
                then update insert $data into $dmd/cmd:CMD/cmd:Components/cmd:collection
                else ()
            return
                switch(true())
                    case (exists($doc//mets:rightsMD[@ID=$config:PROJECT_RIGHTSMD_ID]/*)) 
                        return update value $doc//mets:rightsMD[@ID=$config:PROJECT_RIGHTSMD_ID]
                               with <mets:mdRef MDTYPE="OTHER" OTHERMDTYPE="CMDI" LOCTYPE="URL" xlink:href="{base-uri($dmd)}" XPTR="xpointer(/cmd:CMD/cmd:Components/cmd:collection/cmd:License) xmlns(cmd=http://www.clarin.eu/cmd/)"/>
                    case (exists($doc//mets:rightsMD[@ID=$config:PROJECT_RIGHTSMD_ID]))
                        return update insert <mets:mdRef MDTYPE="OTHER" OTHERMDTYPE="CMDI" LOCTYPE="URL" xlink:href="{base-uri($dmd)}" XPTR="xpointer(/cmd:CMD/cmd:Components/cmd:collection/cmd:License) xmlns(cmd=http://www.clarin.eu/cmd/)"/>
                               into $doc//mets:rightsMD[@ID=$config:PROJECT_RIGHTSMD_ID]
                    default 
                        return update insert 
                                    <mets:techMD ID="{$config:PROJECT_RIGHTSMD_ID}">
                                        <mets:mdRef MDTYPE="OTHER" OTHERMDTYPE="CMDI" LOCTYPE="URL" xlink:href="{base-uri($dmd)}" XPTR="xpointer(/cmd:CMD/cmd:Components/cmd:collection/cmd:License) xmlns(cmd=http://www.clarin.eu/cmd/)"/>
                                    </mets:techMD>
                                into $doc//mets:amdSec[@ID eq $config:PROJECT_AMDSEC_ID]
                     
};


(:~ describes the project's Access Control List in eXist's ACL format
 : @param $project-pid the id of the project to query
 : @return the Project's ACL in XML notation. 
:)
(: TODO settle for a metadata format, for now we assume eXist's ACL notation :)
declare function project:acl($project-pid as xs:string) as element(sm:permission)? {
    let $doc:=project:get($project-pid)
    return $doc//mets:rightsMD[@ID eq $config:PROJECT_ACL_ID]/mets:mdWrap/mets:xmlData/sm:permission
};

declare function project:acl($project-pid as xs:string, $data as element(sm:permission)?) as empty() {
    let $doc:=      project:get($project-pid),
        $current:=  project:acl($project-pid)
    let $insert:= 
        if (exists($current))
        then 
            if (exists($data)) 
            then update replace $current with $data
            else update replace $current with project:default-acl($project-pid)
        else
            if (exists($doc//mets:rightsMD[@ID=$config:PROJECT_ACL_ID]))
            then update value $doc//mets:rightsMD[@ID=$config:PROJECT_ACL_ID]
                 with <mdWrap MDTYPE="OTHER" OTHERMDTYPE="EXISTACL" xmlns="http://www.loc.gov/METS/"><xmlData>{$data}</xmlData></mdWrap>
            else update insert <techMD ID="{$config:PROJECT_ACL_ID}" xmlns="http://www.loc.gov/METS/" GROUPID="config.xml"><mdWrap MDTYPE="OTHER" OTHERMDTYPE="EXISTACL"><xmlData>{$data}</xmlData></mdWrap></techMD> into $doc//mets:amdSec[@ID eq $config:PROJECT_AMDSEC_ID]
    return 
        if (project:acl($project-pid)//sm:ace[@target eq 'GROUP' and @who eq 'other'])
        then ()
        else
            (: we have to make sure that there is an ACL entry for GROUP 'other' :)
            let $updated:=project:acl($project-pid),
                $number := $updated/sm:acl/xs:integer(@entries),
                $newNumber := xs:integer($number) + 1
            return 
                (update insert <sm:ace index="0" target="GROUP" who="other" access_type="DENIED" mode="rwx"/>
                into $updated/sm:acl,
                for $i at $pos in $updated/sm:acl/sm:ace
                return update value $i/@index with xs:integer($pos)-1,  
                update value $updated/sm:acl/@entries with $newNumber)
};




(:~
 : Returns the handle to the given project.
 : Handles are stored directly in the CMDI metadata of the resoruce as we cannot 
 : assign handles without a CMDI record.
 : 
 : @param $type: The aspect of the resource to get the handle for. Currently only metdata / CMDI records can be get/set.  
 : @param $project-pid: The PID of the project 
:)
declare function project:get-handle($type as xs:string, $project-pid as xs:string) as xs:string* {
    let $cmdi := project:dmd($project-pid),
        $resourceproxy-id := config:param-value((),"pid-resourceproxy-prefix")||$project-pid
    return
        if (exists($cmdi))
        then
            switch($type)
                (: metadata defaults to the CMDI record :)
                case "metadata" return $cmdi/cmd:Header/cmd:MdSelfLink
                default return ()
        else util:log-app("ERROR",$config:app-name,"No CMDI record found for project '"||$project-pid||"'")
};


(:generates a basic CMDI record based on the data in project.xml:)
declare function project:mets2cmdi($project-pid as xs:string) as element(cmd:CMD)? {
    (: make sure all resource's metata has CMDI records and handles :)
    let $resource-md-handles := 
        for $r-pid in project:resource-pids($project-pid)
        let $handle-uri := resource:get-handle("metadata",$r-pid,$project-pid) 
        return 
            if ($handle-uri)
            then ()
            else ()
    let $project-handle := 
        let $current := project:get-handle("metadata",$project-pid)
        return 
            if ($current)
            then $current
            else ()
    return ()
};