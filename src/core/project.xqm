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
import module namespace index="http://aac.ac.at/content_repository/index" at "index.xqm";
import module namespace handle = "http://aac.ac.at/content_repository/handle" at "../modules/resource/handle.xqm";
import module namespace ixgen="http://aac.ac.at/content_repository/generate-index" at "../modules/index-functions/generate-index-functions.xqm";

declare namespace mets = "http://www.loc.gov/METS/";
declare namespace mods="http://www.loc.gov/mods/v3";
declare namespace metsrights = "http://cosimo.stanford.edu/sdr/metsrights/";
declare namespace sm="http://exist-db.org/xquery/securitymanager";
declare namespace cmd="http://www.clarin.eu/cmd/";
declare namespace xlink="http://www.w3.org/1999/xlink";
declare namespace xi="http://www.w3.org/2001/XInclude";

declare namespace fcs = "http://clarin.eu/fcs/1.0";
declare namespace sru = "http://www.loc.gov/zing/srw/";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare namespace oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/";

(: declaration of helper namespaces for better code structuring :)
declare namespace param="userinput.parameters";
declare namespace this="current.object";

declare variable $project:default-template as element(mets:mets) := 
    if (doc-available(config:path('mets.template'))) 
    then doc(config:path('mets.template'))/mets:mets 
    else doc($config:app-root||"/_project.xml")/mets:mets;
    
declare variable $project:map-template as element(map) := 
    if (doc-available(config:path('map.template'))) 
    then doc(config:path('map.template'))/map 
    else doc($config:app-root||"/_map.xml")/map;
    
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
declare %private function project:remove-accounts($project-pid as xs:string) as empty-sequence(){
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
:  Instantiates a new project.
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
            
        let $project-stored as xs:string? :=  project:store($this:id,$this:project)
        
        return
            if ($project-stored!='')
            then 
                let $project-collection:=   project:collection($this:id)
                let $setup-map :=           project:map($project:map-template, $this:id)
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
                    return project:dmd($this:id,$cmdi-seed)
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
                util:log-app("INFO",$config:app-name, "Project "||$this:id||" could not be instantiated.")
};

declare function project:label($project-pid as xs:string) as xs:string? {
    let $doc := project:get($project-pid)
    return$doc/@LABEL[.!='']/xs:string(.)
}; 


declare function project:label($data as xs:string, $project-pid as xs:string) as empty-sequence() {
    let $current := project:get($project-pid)/@LABEL
    let $update := update value $current with $data
    return ()
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
    config:project-config($project)                          
};


(:~ 
 : Helper functions that resolves a polymorph $project object to its ID.
 : @param $project may be a string, a mets element, document node containing a mets element or even a map containing a "config" key with a mets element   
 :)
declare function project:get-id($project as item()) as xs:string? {
    let $project-data := project:get($project)
    return xs:string($project-data/@OBJID)
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
    (: the path may be specified explicitly as a project configuration parameter :)
    let $project-config:=project:parameters($project-pid)//param[@key=$key||".path"]/xs:string(.)
    
    (: in some cases the path will be just a subcollection of a repo-wide path configuration, 
        so we can just concatenate it with the project-pid (see below):)
    let $global-key := 
            switch($key)
                case "workingcopy" return "workingcopies"
                case "workingcopies" return "workingcopies"
                case "lookuptable" return "lookuptables"
                case "lookuptables" return "lookuptables"
                case "master"       return "data"
                case "resourcefragment"       return "resourcefragments"
                case "resourcefragments"       return "resourcefragments"
                case "metadata"     return "metadata"
                case "data"         return  "data"
                case "home"         return "projects"
                case "indexes"      return "indexes"        
                default return ()
                
    let $global-path := if (exists($global-key)) then config:path($global-key) else ()
    
    (: for some cases we have to inject some project-specific paths here in 
        order to be able to resolve the full path with the project-agnostic 
       config:path-relative-to-absolute() function :)
       
   let $project-path :=
        if (exists($project-config) or exists($global-path))
        then ()
        else 
            let $static-paths := $config:cr-config//config:path
            let $project-paths := (
                <config:path key="project-home" base="#projects">{$project-pid}</config:path>
            )
            return config:path(($static-paths,$project-paths),$key)
    return 
        switch(true())
            case exists($project-config)    return $project-config
            case exists($global-path)       return $global-path||"/"||$project-pid
            case exists($project-path)      return $project-path
            default                         return ()
};


(:~
 : Stores the project's mets record in the database and returns the path 
 : to the newly created document. The base path is either read from the mets record
 : param 'project.home' or set by config:path('projects')
 : 
 : @param $mets:record the mets:file
 : @return database path to the new file, or empty sequence if an error occured (logged in app-log))  
~:)
declare %private function project:store($project-pid as xs:string, $mets:record as element(mets:mets)) as xs:string? {
    let $col :=     replace($mets:record//param[@key='project.home'],$project-pid||"/?$",'')
    let $base :=    if ($col!='') then $col else config:path('projects')
        
    let $path:=     try {                        
                        let $mkdir:=    repo-utils:mkcol($base,$project-pid)
                        return xmldb:store($base||"/"||$project-pid,"project.xml",$mets:record)
                    } catch * {
                        let $log := util:log-app("INFO",$config:app-name, "Could not store project "||$project-pid||" to collection "||$base||". "||string-join(($err:code , $err:description, $err:value),' - ') )
                        return ()
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
declare function project:purge($project-pid as xs:string) as empty-sequence() {
    project:purge($project-pid,())
};

(:~
: removes the cr-project from the content repository, possibly also removing the project's data.
: 
: @param $config the uri of the cr-catalog to be removed
: @param $delete-data should the project's data be removed? (default: 'no')
: @return empty-sequence()
~:)
declare function project:purge($project-pid as xs:string, $delete-data as xs:boolean*) as empty-sequence() {
   if (exists(project:get($project-pid)))
   then
        let $delete-data := ($delete-data,false())[1]
        return
             if ($delete-data)
             then     
                  let $base :=          config:path('projects')
                  let $rm-structure :=  project:structure($project-pid,'remove'),
                      $rm-indizes :=    for $x in xmldb:get-child-resources(config:path("indexes"))[starts-with(.,"index-"||$project-pid)]
                                        return (
                                            xmldb:remove(config:path("indexes"),$x),
                                            util:log-app("INFO",$config:app-name,"removed index file "||$x||".")
                                         )
                  let $project-dir :=    project:collection($project-pid),
                      $rm-project-dir := if ($project-dir!='') then xmldb:remove($project-dir) else ()
                  let $log :=           util:log-app("INFO",$config:app-name,"removed project dir "||$project-dir)
                  let $rm-accounts :=   project:remove-accounts($project-pid)
                  let $log :=           util:log-app("INFO",$config:app-name,"removed project accounts")
                  let $rebuild-index-fn := ixgen:register-project-index-functions() 
                  let $log :=           util:log-app("INFO",$config:app-name,"rebuilt system-wide index functions")
                  let $log :=           util:log-app("INFO",$config:app-name,"finished purging project "||$project-pid)
                  return ()
              else 
                 let $update-status := project:status($project-pid,'removed')
                 let $log :=           util:log-app("INFO",$config:app-name,"set status of project "||$project-pid||" to 'removed'")
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
declare function project:status-code($project-pid as xs:string, $data as xs:integer) as empty-sequence() {
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
    return $structMap//mets:div[@TYPE eq $config:PROJECT_RESOURCE_DIV_TYPE]
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
    return for $div in $structMap//mets:div[@TYPE eq $config:PROJECT_RESOURCE_DIV_TYPE]
        order by $div/xs:integer(@ORDER)
        return $div

};

declare function project:list-resources-resolved($project) as element(sru:searchRetrieveResponse)* {
    let $start-time := util:system-dateTime()
    let $doc:=  if ($project instance of xs:string) 
                then project:get($project)
                else $project
    let $ress := project:list-resources($doc)
    let $project-id := data($doc/@OBJID)
    let $count := count($ress)
    let $resources := for $res in $ress 
        let $dmd := resource:dmd($res, $project )        
        let $res-id := $res/data(@ID)
        let $res-label := $res/data(@LABEL)
        let $res-title := (if (exists($dmd)) then index:apply-index($dmd,'resource.title',$project)//text() else $res-label, $res-label)[1]
        let $res-cite := resource:cite($res-id, $project-id, $doc )
        
        let $indexImage-path := resource:path($res-id, $project-id, 'indexImage')
        order by $res/@ORDER
        return <fcs:Resource pid="{$res-id}" >
                 <fcs:DataView type="title">{$res-title}</fcs:DataView>
                 <fcs:DataView type="cite">{$res-cite}</fcs:DataView>          
                 <fcs:DataView type="metadata">{$dmd}</fcs:DataView>
                 <fcs:DataView type="image" ref="{$indexImage-path}" />
               </fcs:Resource>
    
     let $end-time := util:system-dateTime(),
(:<sru:baseUrl>{repo-utils:config-value($config, "base.url")}</sru:baseUrl>:)
         $ret := <sru:searchRetrieveResponse>
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
                        </sru:searchRetrieveResponse>,
            $logRet := util:log-app("TRACE",$config:app-name,"project:list-resources-resolved return "||substring(serialize($ret), 1, 240)) 
       return $ret
};

(:~
 : lists the ids of all resources in given project.
 : 
 : @param $config the mets-config of a project 
~:)
declare function project:resource-pids($project-pid as xs:string) as xs:string* {
    let $resources:=project:resources($project-pid)
    return $resources/@ID
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

declare function project:metsHdr($project-pid as xs:string, $data as element(mets:metsHdr)) as empty-sequence() {
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

declare function project:dmd($project, $data as element(cmd:CMD)?) as empty-sequence() {    
    let $doc:=      repo-utils:get-record($project),
        $project-pid := $doc/xs:string(@OBJID),
        $current:=  project:dmd($project),
        $dmdSec := $doc//mets:dmdSec[@ID = $config:PROJECT_DMDSEC_ID]
    return
        if (exists($current))
        then 
            if (exists($data))
            (: Update replace cannot do anything about the root element of the document and update value replaces inside the node given.
               TODO: to update any namespace, schema or attribute to cmd:CMD using this code has to be added! :)
            then update value $current with $data/*
            else (update delete $dmdSec/mets:mdRef[@MDTYPE = 'OTHER'][@OTHERMDTYPE = 'CMDI'],xmldb:remove(util:collection-name($current),util:document-name($current)))
        else
            let $path := 
                if (exists($dmdSec/mets:mdRef[@MDTYPE = 'OTHER'][@OTHERMDTYPE = 'CMDI']/@xlink:href[.!='']))
                then $dmdSec/mets:mdRef[@MDTYPE = 'OTHER'][@OTHERMDTYPE = 'CMDI']/@xlink:href
                else replace(project:path($project-pid,'metadata'),'/$','')||"/CMDI/"||$project-pid||".xml"
            let $href-toks := tokenize($path,'/'),
                $filename := $href-toks[last()],
                $collection:= substring-before($path,"/"||$filename)
            let $mk-col := repo-utils:mkcol("/",$collection),
                $store-data := repo-utils:store($collection,$filename,$data,false(),())
            return 
                switch(true())
                    case (exists($dmdSec/mets:mdRef[@MDTYPE = 'OTHER'][@OTHERMDTYPE = 'CMDI']/@xlink:href[. = $path])) 
                        return ()
                    case (exists($dmdSec/mets:mdRef[@MDTYPE = 'OTHER'][@OTHERMDTYPE = 'CMDI']/@xlink:href[. != $path])) 
                        return update value $dmdSec/mets:mdRef[@MDTYPE = 'OTHER'][@OTHERMDTYPE = 'CMDI']/@xlink:href with $path
                    case (exists($dmdSec/mets:mdRef[@MDTYPE = 'OTHER'][@OTHERMDTYPE = 'CMDI'])) 
                        return update insert attribute {"xlink:href"} {$path} into $dmdSec/mets:mdRef[@MDTYPE = 'OTHER'][@OTHERMDTYPE = 'CMDI']
                    case (exists($dmdSec))
                        return update insert <mets:mdRef MDTYPE="OTHER" OTHERMDTYPE="CMDI" LOCTYPE="URL" xlink:href="{$path}"/> into $dmdSec
                    default return update insert <mets:dmdSec ID="{$config:PROJECT_DMDSEC_ID}"><mets:mdRef MDTYPE="OTHER" OTHERMDTYPE="CMDI" LOCTYPE="URL" xlink:href="{$path}"/></mets:dmdSec> following $doc/mets:metsHdr
                        
 };


(: getter and setter for index-map :)
declare function project:map($project) as element(map)? {
    config:mappings($project)[1]
};


declare function project:map($data as element(map)?, $project-pid as xs:string) as empty-sequence() {
    let $doc:=      project:get($project-pid),
        $current:=  project:map($project-pid)
    return 
        if (exists($current))
        then 
            (update delete $current/self::map/node(),
            if ($data) then update insert $data/self::map/node() into $current/self::map else ())
        else
            let $project-home := project:path($project-pid,'home'),
                $path-to-map-instance := $project-home||"/map.xml",
                $map-file-exists := doc-available($path-to-map-instance),
                $mappings := $doc//mets:techMD[@ID=$config:PROJECT_MAPPINGS_ID]
            return 
            if (not($data/self::map[map]))
            then util:log-app($config:app-name, "ERROR", "invalid map format")
            else 
                let $store-map-instance := xmldb:store($project-home, "map.xml", $data)
                let $register-map := 
                    if (exists($mappings) and not($mappings/mets:mdRef[@xlink:href = $path-to-map-instance]))
                    then 
                        update insert <mdRef MDTYPE="OTHER" xmlns="http://www.loc.gov/METS/" xlink:href="{$path-to-map-instance}" LOCTYPE="URL"/>
                        into $doc//mets:techMD[@ID=$config:PROJECT_MAPPINGS_ID]
                    else 
                        update insert <techMD ID="{$config:PROJECT_MAPPINGS_ID}" xmlns="http://www.loc.gov/METS/"><mdRef MDTYPE="OTHER" xlink:href="{$path-to-map-instance}" LOCTYPE="URL"/></techMD> 
                        preceding $doc//mets:amdSec[@ID eq $config:PROJECT_AMDSEC_ID]/*[1]
                return ()
};

(: getter and setter for project parameters :)
declare function project:parameters($project-pid as xs:string) as element(param)* {
    let $doc:=project:get($project-pid)
    return $doc//mets:techMD[@ID=$config:PROJECT_PARAMETERS_ID]/mets:mdWrap/mets:xmlData/param
};

declare function project:parameters($project-pid as xs:string, $data as element(param)*) as empty-sequence() {
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

declare function project:moduleconfig($project-pid as xs:string, $data as element(module)*) as empty-sequence() {
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

declare function project:license($project, $data as element(cmd:License)?) as empty-sequence() {
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

declare function project:acl($project-pid as xs:string, $data as element(sm:permission)?) as empty-sequence() {
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
        $config := config:config($project-pid),
        $resourceproxy-id := config:param-value($config,"pid-resourceproxy-prefix")||$project-pid
    return
        if (exists($cmdi))
        then
            switch($type)
                (: metadata defaults to the CMDI record :)
                case "metadata" return $cmdi/cmd:Header/cmd:MdSelfLink
                case "CMDI" return $cmdi/cmd:Header/cmd:MdSelfLink
                default return ()
        else util:log-app("ERROR",$config:app-name,"No CMDI record found for project '"||$project-pid||"'")
};


declare function project:set-handle($type as xs:string, $project-pid as xs:string) as empty-sequence() {
    let $cmdi := project:dmd($project-pid),
        $config := config:config($project-pid),
        $resourceproxy-id := config:param-value($config,"pid-resourceproxy-prefix")||$project-pid
    return
        switch($type)
            (: sets handles of all resources of a the project in its ResourceProxy, without actually updating their URL :)
            case "resources" return 
                for $r in $cmdi/cmd:Resources/cmd:ResourceProxyList/cmd:ResourceProxy[cmd:ResourceType = "Metadata"]
                return
                    let $resource-pid := $r/@id
                    let $handle := resource:get-handle("CMDI",$resource-pid,$project-pid)
                    return   
                        if ($r != $handle)
                        then update value $r/cmd:ResourceRef with $handle
                        else ()
                        
            case "CMDI" return
                let $current := project:get-handle("CMDI",$project-pid)
                let $target-url := 
                        concat(
                            replace(config:param-value($config,"public-repo-baseurl"),'/$',''),
                            "/get/",$project-pid,"/",
                            switch($type)
                                case "CMDI" return "metadata/CMDI"
                                default return "metadata/CMDI"
                        )
                let $handle-url := 
                        if (exists($current) and $current != '')
                        then handle:update($target-url,$current,$project-pid)
                        else handle:create($target-url,$project-pid)
                return
                    switch (true())
                        case exists($cmdi/cmd:Header/cmd:MdSelfLink) return
                            update value $cmdi/cmd:Header/cmd:MdSelfLink with $handle-url
                        case exists($cmdi/cmd:Header) return
                            update insert <cmd:MdSelfLink>{$handle-url}</cmd:MdSelfLink> into $cmdi/cmd:Header
                        default return ()    
            
            default return util:log-app("INFO",$config:app-name,"unknown aspect "||$type||" of project "||$project-pid||". Can't set handle.")
                    
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

declare function project:dmd2dc($project-pid as xs:string) as element(oai_dc:dc){
    let $dmd := project:dmd($project-pid),
        $xsl := doc(config:path("scripts")||"/dc/cmdi2dc.xsl"),
        $params := <parameters><param name='fedora-pid-namespace-prefix' value="{config:param-value(config:module-config(),'fedora-pid-namespace-prefix')}"/></parameters>
    return transform:transform($dmd,$xsl,$params)
};




(:~
 : returns the full logical structure (table of contents if you wish) of a project
 : as generated into the structMap.logical 
 : 
 : @param $resource-pid the pid of the resource 
 : @param $project-pid the pid of the project
 : @return   
~:)
declare function project:get-toc($project-pid as xs:string) as element()* {
let $mets:record := project:get($project-pid)
    return $mets:record//mets:structMap[@TYPE=$config:PROJECT_TOC_STRUCTMAP_TYPE ]/mets:div/mets:div 
};

declare function project:get-toc-resolved($project-pid as xs:string) as element()? {
    let $mets:record := project:get($project-pid),
        $toc-struct := $mets:record//mets:structMap[@TYPE=$config:PROJECT_TOC_STRUCTMAP_TYPE ]/mets:div
    return project:do-get-toc-resolved($toc-struct,$mets:record)
};

declare function project:do-get-toc-resolved($node as node(), $mets-record as element(mets:mets)) as node() {
    project:do-get-toc-resolved($node,(),$mets-record)
};


declare function project:do-get-toc-resolved($node as node(), $resource-pid as xs:string?, $mets-record as element(mets:mets)) as node()* {
    typeswitch ($node)
        case attribute() return $node
        
        case text() return $node
        
        case processing-instruction() return $node
        
        case document-node() return project:do-get-toc-resolved($node/*, $resource-pid, $mets-record)
        
        case element(mets:fptr) return 
            for $n in $node/* 
            return project:do-get-toc-resolved($node/*, $resource-pid, $mets-record)
        
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
                        for $n in $node/node() return project:do-get-toc-resolved($n,$resource-pid,$mets-record)
                     }
                
                case ($node/@TYPE='resourcefragment') return 
                    for $n in $node/mets:* 
                    return project:do-get-toc-resolved($n,$resource-pid,$mets-record)
                
                default return 
                    element {QName(xs:string(namespace-uri($node)),local-name($node))} {
                            $node/@*,
                            for $n in $node/node() 
                            return project:do-get-toc-resolved($n,$resource-pid,$mets-record)
                       }
        
        case element() return element {QName(xs:string(namespace-uri($node)),local-name($node))} {
                            $node/@*,
                            for $n in $node/node() 
                            return project:do-get-toc-resolved($n,$resource-pid,$mets-record)
                       }

        default return $node
};




(:~ gets the mets file Group for the term labels of a project
 : @param $project-pid the id of the project to query
 : @return sequence of docs() with term labels following  
 :)
declare function project:termlabels($project-pid as xs:string) as element(mets:fileGrp)? {
    let $doc:=project:get($project-pid)
    return $doc//mets:fileGrp[@ID eq "termlabels"]
};

(:~ gets the term label data of a project
 : @param $project-pid the id of the project to query
 : @return sequence of docs() with term labels following  
 :)
declare function project:get-termlabels($project-pid as xs:string) as item()* {
    let $termlabels := project:termlabels($project-pid)
    return $termlabels/mets:file/mets:FLocat!doc(@xlink:href)
};

(:~ gets the term label data of a project, already specific for an index
 : @param $project-pid the id of the project to query
 : @param $index-key the index-key to provide labels for
 : @return sequence of docs() with term labels following  
 :)
declare function project:get-termlabels($project-pid as xs:string, $index-key) as item()* {
    let $termlabels := project:get-termlabels($project-pid)
    return $termlabels//*[@key=$index-key]
};


declare function project:add-termlabels($project-pid as xs:string, $data as element(termLib)) as item()* {
    let $termlabels-path:= project:path($project-pid,"termlabels"),
        $termlabels := project:termlabels($project-pid),
        $new-filename := 
            let $counter := count($termlabels/mets:file)+1
            return project:termlabel-new-filename($project-pid,"termlabels"||$counter||".xml") 
    return () 
};

declare %private function project:termlabel-new-filename($project-pid as xs:string, $filename as xs:string) {
    if (doc-available(project:path($project-pid,"termlabels")||"/"||$filename))
    then project:termlabel-new-filename($project-pid, replace($filename,'\.xml$','_1.xml'))
    else $filename
};

declare function project:base-url($project-pid as xs:string) as xs:string {
    config:param-value(project:get($project-pid),'base-url-public')
};