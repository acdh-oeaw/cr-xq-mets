xquery version "3.0";
(:~ 
: This module provides functions for managing cr-xq projects, including:
: <ul>
:   <li>creation, modification, deletion</li> 
:   <li>import and export</li>
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
: @author Daniel Schopper, daniels.schopper@oeaw.ac.at
: @version 0.1
: @see http://www.github.com/vronk/SADE/docs/crProject-readme.md
~:)

module namespace project = "http://aac.ac.at/content_repository/project";
import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace repo-utils="http://aac.ac.at/content_repository/utils" at "repo-utils.xqm";

declare namespace mets = "http://www.loc.gov/METS/";
declare namespace mods="http://www.loc.gov/mods/v3";
declare namespace metsrights = "http://cosimo.stanford.edu/sdr/metsrights/";
declare namespace sm="http://exist-db.org/xquery/securitymanager";

(: namespaces for method and property interfaces:)
(:~
 : The function definitions in this module serve two purposes: First, they provide the low-level 
 : code to access and manipulate projects in the content repository.
 : 
 : Secondly, they define public interfaces to each project, representing 'getter' functions as 
 : so called project 'properties' and 'setter' functions as project 'methods'.
 :
 : The mapping between those two aspects is implemented with function annotations: Each function 
 : which provides the endpoint for a "project property" has the following annotations:
 :
 :      %property:name("public name")
 :      %property:realm("public|protected")
 :      %property:group("myProjectAdmin"|...)
 :
 : Project methods are described by the same annotations, yet in they own "method" namespace:
 :
 :      %method:name("public name")
 :      %method:realm("public|protected")
 :      %method:group("myProjectAdmin"|...)
 :
 : The "realm" annotation describes whether the project's property or method is publicly available ("public") 
 : or some kind of authorization is needed ("protected"). If protected, the 'group' annotation specifies a 
 : eXist user group which the calling user is required to be member of.
 :
 : The public interface to the project object is provided by 'project.xql'.  
~:)
declare namespace method = "http://aac.ac.at/content_repository/project/method";
declare namespace property = "http://aac.ac.at/content_repository/project/property";

(: declaration of helper namespaces for better code structuring :)
declare namespace param="userinput.parameters";
declare namespace this="current.object";

declare variable $project:defined-status := map {
    $config:PROJECT_STATUS_AVAILABLE     := 1,
    $config:PROJECT_STATUS_REVISION      := 2,
    $config:PROJECT_STATUS_RESTRICTED    := 3,
    $config:PROJECT_STATUS_REMOVED       := 4
};

declare variable $project:default-template as element(mets:mets) := if (doc-available(config:path('mets.template'))) then doc(config:path('mets.template'))/mets:mets else doc($config:app-root||"/project.tpl")/mets:mets;

(:~
 : generated the id for a new project
~:)
declare function project:generate-id() as xs:string {
    substring(replace(util:uuid(),'-',''),1,10)    
};

declare function project:sanitize-id($id as xs:string) as xs:string {
    replace($id,'[\s*-\.]','')
};


(:~
 : sets up two accounts plus personal groups: one with the name of the project,
 : a read-only account for public access and one admin account with full rights 
 : to all project resources.
 : The initial passwords are set to the value of $id. These are to be 
 : changed at the first login.
~:)
declare %private function project:create-accounts($id) {
    let $usernames:=(project:useraccountname($id),project:adminaccountname($id))
    let $new:=  for $username in $usernames return
                    let $password:=$id,
                        $groups:=()
                    return
                        if (sm:user-exists($username))
                        then sm:passwd($username,$password)
                        else sm:create-account($username,$password,$groups)
    return ()
};

(:~
 : deletes the two project accounts.
~:)
declare %private function project:remove-accounts($id) {
    let $usernames:=(project:useraccountname($id),project:adminaccountname($id))
    return 
        for $username in $usernames return
            if (sm:user-exists($username))
            then 
                (sm:remove-account($username),
                sm:remove-group($username))
            else ()
};


(:~
:  Instanciates a new project.
:
: @return mets:mets
~:)
declare %method:name("new") %method:realm("protected") %method:group("projectadmins")  function project:new() {
    let $defaultTpl:=$project:default-template
    return project:new($defaultTpl,())
};


declare %method:name("new") %method:realm("protected") %method:group("projectadmins")  function project:new($id as xs:string) {
    let $defaultTpl:=$project:default-template
    return project:new($defaultTpl,$id)
};
(:~
: Instanciates a new project, based on a given template at $template, and stores it in the database.
:
: @param $mets:template the template to create the mets-file from 
: @param $id the name of the project (one Token), if empty id will be generated by project:generate-id() 
: @return the new entry, or, if the project with $id already existed, the empty sequence.  
~:)
declare %method:name("new") %method:realm("protected") %method:group("projectadmins") function project:new($data as element(mets:mets),$id as xs:string?) as element(mets:mets)? {
   if (project:get($id))
   then ()
   else 
        let $this:id:=            (project:sanitize-id($id),project:generate-id())[1]
        let $setup-accounts:=        project:create-accounts($this:id)
        let $prepare-structure:=     project:structure($this:id,"prepare")
        let $project-stored:=        project:store($this:id,$data)
        let $doc:=                   doc($project-stored)
        let $sw_name :=              $config:app-name-abbreviation||" ("||$config:app-name-full||")",
            $version:=               $config:app-version,
            $instance :=             $config:app-root
        let $sw_note :=              "instance at "||$instance||"; version "||$version
        let $update-record:=         (update value $doc/mets:mets/@OBJID with $this:id,
                                     update value $doc//mets:metsHdr/@CREATEDATE with current-dateTime(),
                                     update value $doc//mets:metsHdr/@RECORDSTATUS with $config:PROJECT_STATUS_REVISION,
                                     update value $doc//mets:metsHdr/mets:agent[@ROLE='CREATOR' and @OTHERTYPE='SOFTWARE']/mets:note with $sw_note,
                                     update value $doc//mets:metsHdr/mets:agent[@ROLE='CREATOR' and @OTHERTYPE='SOFTWARE']/mets:name with $sw_name,
                                     update value $doc//mets:metsHdr/mets:agent[@ROLE='CREATOR' and @TYPE='INDIVIDUAL']/mets:name with xmldb:get-current-user())
        
                                         
        return project:get($this:id)
};

declare %property:name("label") %property:realm("public") function project:label($id as xs:string) as xs:string? {
    project:get($id)/xs:string(@LABEL)
}; 

declare %method:name("label") %method:realm("protected") %method:group("projectadmins","projecteditors") function project:label($id as xs:string, $data as xs:string?) as empty() {
    let $current := project:get($id)/@LABEL
    return update value $current with $data
}; 

declare %property:name("available") %property:realm("public") function project:available($id as xs:string) as xs:boolean {
    project:status($id) = $config:PROJECT_STATUS_AVAILABLE
};

declare %method:name("dump") %method:realm("protected") %method:group("projectadmins") function project:get($id as xs:string) as element(mets:mets)? {
    let $mets:= if (exists(collection(config:path("projects"))//mets:mets[@OBJID eq $id]))
                then collection(config:path("projects"))//mets:mets[@OBJID eq $id]
                else collection("/db")//mets:mets[@OBJID eq $id]
    return $mets 
};

declare %property:name("projectusers")  %property:realm("protected") %property:group("projectadmins") function project:useraccountname($id as xs:string) as xs:string {
    $config:PROJECT_ACCOUNTS_USER_ACCOUNTNAME_PREFIX||$id||$config:PROJECT_ACCOUNTS_USER_ACCOUNTNAME_SUFFIX
};

declare %property:name("projectadmins")  %property:realm("protected") %property:group("projectadmins") function project:adminaccountname($id as xs:string) as xs:string {
    $config:PROJECT_ACCOUNTS_ADMIN_ACCOUNTNAME_PREFIX||$id||$config:PROJECT_ACCOUNTS_ADMIN_ACCOUNTNAME_SUFFIX
};

(:~
 : Prepares the structure for a new project or deletes the data of an existing one
~:)
declare %private function project:structure($id as xs:string, $action as xs:string) {
    let $admin-accountname := project:adminaccountname($id),
        $admin-groupname := project:adminaccountname($id),
        $users-accountname := project:useraccountname($id),
        $users-groupname := project:useraccountname($id)
    let $paths:=(
        config:path("data"),
        config:path("workingcopies"),
        config:path("lookuptables"),
        config:path("resourcefragments"),
        config:path("metadata")
    )
    return
    switch($action)
    case 'prepare' return 
        for $p in $paths return
            let $uri := xs:anyURI($p||"/"||$id) 
            let $mk := repo-utils:mkcol($p,$id),
                $set-owner := sm:chown($uri, $admin-accountname),
                $set-group := sm:chgrp($uri, $admin-groupname),
                $set-acls:= (sm:add-group-ace($uri, $users-groupname, true(), 'rx'),
                            sm:add-group-ace($uri, $users-groupname, false(), 'w'),
                            sm:add-group-ace($uri, $users-groupname, true(), 'rx'),
                            sm:add-group-ace($uri, $users-groupname, false(), 'w'))
            return ()
    case 'remove' return
        let $paths:= (config:path("data")||"/"||$id,
                    config:path("workingcopies")||"/"||$id,
                    config:path("lookuptables")||"/"||$id,
                    config:path("resourcefragments")||"/"||$id,
                    config:path("metadata")||"/"||$id)
        return 
            for $p in $paths 
            return 
                if (xmldb:collection-available($p))
                then xmldb:remove($p)
                else ()
    default return ()
};

(:~
 : Stores the project's mets record in the database and returns the path 
 : to the newly created file.
 : 
 : @param $mets:record the mets:file
 : @return database path to the new file 
~:)
declare %private function project:store($id as xs:string, $mets:record as element(mets:mets)) as xs:string? {
    let $base :=    config:path('projects'),
        $mkdir:=    repo-utils:mkcol($base,$id)
    return xmldb:store($base||"/"||$id,"project.xml",$mets:record)
};

(:~
: Imports a cr-archive (a self-contained cr-project) into the content repository.
:
: @param $archive the cr-archive to be imported.
: @return the uri of the new project collection containing the cr-catalog.
~:)
declare function project:import($archive as document-node()) as xs:anyURI? {
    () (:TODO:)
};


(:~
: Renames the project and its data, setting a new identifier and renaming the 
: collection structure.
:
: @param 
: @return the uri of the new project collection containing the cr-catalog.
~:)
declare function project:rename($id) as element(mets:mets) {
    () (:TODO:)
};


(:~
: Exports a cr-catalog (a cr-project referencing data in a cr-xq repository) as a standalone cr-archive.  
:
: @param $config the uri of the cr-catalog to be exported
: @return the self-contained cr-archive.
~:)
declare function project:export($config as xs:anyURI) as document-node()? {
    ()(:TODO:)
};

declare function project:transfer($id as xs:string, $host as xs:anyURI) as xs:boolean {
    ()(:TODO:)
};


declare %property:name("collection") %property:realm("protected") %property:group("projectadmin") function project:collection($id as xs:string) as xs:string? {
    util:collection-name(project:get($id))
};

(:~
 : Returns the path to a project's mets records by retrieving via its @OBJID.
 : This enables us to set the projects own path in its mets:techMD-section. 
~:)
declare %property:name("uri") %property:realm("protected") %property:group("projectadmin")  function project:filepath($id as xs:string) as xs:string? {
    base-uri(project:get($id))
};

declare function project:filepath($id as xs:string) as xs:string? {
    if (exists(collection(config:path("projects"))//mets:mets[@OBJID = $id]))
    then base-uri(collection(config:path("projects"))//mets:mets[@OBJID = $id])
    else base-uri(collection("/db")//mets:mets[@OBJID = $id])
};

(:~
: removes the cr-project from the content repository without removing the project's resources.
:
: @param $config the uri of the cr-catalog to be removed
: @return true if projec 
~:)
declare %method:name("purge") %method:realm("restricted") %method:group("projectadmins") function project:purge($id as xs:string) as empty() {
    project:purge($id,())
};

(:~
: removes the cr-project from the content repository, possibly also removing the project's data.
: 
: @param $config the uri of the cr-catalog to be removed
: @param $delete-data should the project's data be removed?
: @return true if projec
~:)
declare %method:name("purge") %method:realm("restricted") %method:group("projectadmins") function project:purge($id as xs:string, $delete-data as xs:boolean?) as empty() {
   if (exists(project:get($id)))
   then
        let $delete-data := ($delete-data,false())[1]
        return
             if ($delete-data)
             then     
                  let $base :=          config:path('projects')
                  let $rm-structure :=  project:structure($id,'remove'),
                      $rm-indizes :=    for $x in xmldb:get-child-resources(config:path("indexes"))[starts-with(.,"index-"||$id)]
                                        return xmldb:remove(config:path("indexes"),$x)
                  let $project-dir :=    project:collection($id),
                      $rm-project-dir := if ($project-dir!='') then xmldb:remove($project-dir) else ()
                  let $rm-accounts :=   project:remove-accounts($id)
                  return ()
              else 
                 let $update-status := project:status($id,'removed')
                 return ()
    else ()
};



(:~
 : sets the status of the project
~:)
declare %method:name("status") %method:realm("restricted") %method:group("projectadmins") function project:status($id as xs:string, $data as xs:string) as empty() {
    let $project:=          project:get($id),
        $definedStatus :=   map:keys($project:defined-status)
    return
        if ($data = $definedStatus and exists($project))
        then update value $project/mets:metsHdr/@RECORDSTATUS with $data
        else ()
};

(:~
 : gets the status of the project, empty string if project does not exist
~:)
declare %property:name("status") %property:realm("public") function project:status($id as xs:string) as xs:string? {
    let $project:=project:get($id)
    return $project/mets:metsHdr/xs:string(@RECORDSTATUS)
};

(:~
 : gets the status of the project as a numerical code
~:)
declare %property:name("status-code") %property:realm("public") function project:status-code($id as xs:string) as xs:integer? {
    let $status:=project:status($id)
    return xs:integer(map:get($project:defined-status,$status))
};

(:~
 : sets the status of the project as a numerical code 
~:)
declare %method:name("status-code") %method:realm("restricted") %method:group("projectadmins") function project:status-code($id as xs:string, $data as xs:integer) as empty() {
    let $project:=          project:get($id),
        $definedStatus :=   for $k in map:keys($project:defined-status)
                            let $val:=map:get($project:defined-status,$k)
                            return 
                                if ($val = $data) 
                                then $k
                                else ()
    return
        if (exists($definedStatus) and exists($project))
        then (update value $project/mets:metsHdr/@RECORDSTATUS with $definedStatus,true())
        else ()
};



(:~
 : lists all resources of a given project as their mets:divs.
 : 
 : @param $config the mets-config of a project 
~:)
declare function project:get-resources($id as xs:string) as element(mets:div)* {
    let $doc:=project:get($id)
    let $structMap:=$doc//mets:structMap[@ID eq $config:PROJECT_STRUCTMAP_ID and @TYPE eq $config:PROJECT_STRUCTMAP_TYPE]
    return $structMap//mets:div[@TYPE eq $config:PROJECT_RESOURCE_DIV_TYPE]
};

(:~
 : lists the ids of all resources in given project.
 : 
 : @param $config the mets-config of a project 
~:)
declare %property:name("resource-pids") %property:realm("public") function project:get-resource-pids($id as xs:string) as xs:string* {
    let $resources:=project:get-resources($id)
    return $resources/xs:string(@ID)
};


(: getter and setter for dmdSec, i.e. the project's MODS record :)
declare %property:name("dmd") %property:realm("public") function project:dmd($id as xs:string) as element(mods:mods){
    let $doc:=project:get($id)
    return $doc//mets:dmdSec[@ID=$config:PROJECT_DMDSEC_ID]//mods:mods
};

declare %method:name("dmd") %method:realm("restricted") %method:group("projectadmins") function project:dmd($id as xs:string, $data as element(mods:mods)) as empty() {
    let $doc:=      project:get($id),
        $current:=  project:dmd($id)
    return 
        if (exists($current))
        then 
            if (exists($data))
            then update replace $current with $data
            else update delete $current
        else
            if (exists($doc//mets:dmdSec[@ID = $config:PROJECT_DMDSEC_ID]))
            then update value $doc//mets:dmdSec[@ID = $config:PROJECT_DMDSEC_ID] 
                 with <mdWrap MDTYPE="MODS" xmlns="http://www.loc.gov/METS/"><xmlData>{$data}</xmlData></mdWrap>
            else update insert <dmdSec ID="{$config:PROJECT_DMDSEC_ID}" xmlns="http://www.loc.gov/METS/"><mdWrap MDTYPE="MODS"><xmlData>{$data}</xmlData></mdWrap></dmdSec> following $doc//mets:metsHdr 
};



(: getter and setter for mappings :)
declare %property:name("mappings") %property:realm("public") function project:mappings($id as xs:string) as element(map)? {
    let $doc:=project:get($id)
    return $doc//mets:techMD[@ID=$config:PROJECT_MAPPINGS_ID]/mets:mdWrap/mets:xmlData/*
};

declare %method:name("mappings") %method:realm("restricted") %method:group("projectadmins") function project:mappings($id as xs:string, $data as element(map)) as empty() {
    let $doc:=      project:get($id),
        $current:=  project:mappings($id)
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
declare %property:name("parameters") %property:realm("public") function project:parameters($id as xs:string) as element(param)? {
    let $doc:=project:get($id)
    return $doc//mets:techMD[@ID=$config:PROJECT_PARAMETERS_ID]/mets:mdWrap/mets:xmlData/param
};

declare %method:name("parameters") %method:realm("restricted") %method:group("projectadmins") function project:parameters($id as xs:string, $data as element(param)*) as empty() {
    let $doc:=      project:get($id),
        $current:=  project:parameters($id)
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
declare %property:name("moduleconfig") %property:realm("public") function project:moduleconfig($id as xs:string) as element(module)* {
    let $doc:=project:get($id)
    return $doc//mets:techMD[@ID=$config:PROJECT_MODULECONFIG_ID]/mets:mdWrap/mets:xmlData/module
};

declare %method:name("moduleconfig") %method:realm("restricted") %method:group("projectadmins") function project:moduleconfig($id as xs:string, $data as element(module)*) as empty() {
    let $doc:=      project:get($id),
        $current:=  project:moduleconfig($id)
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


(: getter and setter for rightsMD :)
(: TODO settle for a metadata format, for now we assume METSRIGHTS :)
declare %property:name("license") %property:realm("public") function project:license($id as xs:string) as element(metsrights:RightsDeclarationMD)? {
    let $doc:=project:get($id)
    return $doc//mets:rightsMD[@ID=$config:PROJECT_RIGHTSMD_ID]/mets:mdWrap/mets:xmlData/metsrights:RightsDeclarationMD
};

declare %method:name("license") %method:realm("restricted") %method:group("projectadmins") function project:license($id as xs:string, $data as element(metsrights:RightsDeclarationMD)?) as empty() {
    let $doc:=      project:get($id),
        $current:=  project:license($id)
    return 
        if (exists($current))
        then 
            if (exists($data)) 
            then update replace $current with $data
            else update delete $current
        else
            if (exists($doc//mets:rightsMD[@ID=$config:PROJECT_RIGHTSMD_ID]))
            then update value $doc//mets:rightsMD[@ID=$config:PROJECT_RIGHTSMD_ID]
                 with <mdWrap MDTYPE="METSRIGHTS" xmlns="http://www.loc.gov/METS/"><xmlData>{$data}</xmlData></mdWrap>
            else update insert <techMD ID="{$config:PROJECT_RIGHTSMD_ID}" xmlns="http://www.loc.gov/METS/" GROUPID="config.xml"><mdWrap MDTYPE="METSRIGHTS"><xmlData>{$data}</xmlData></mdWrap></techMD> into $doc//mets:amdSec[@ID eq $config:PROJECT_AMDSEC_ID]
};


(:~ describes the project's Access Control List in eXist's ACL format
 : @param $id the id of the project to query
 : @return the Project's ACL in XML notation. 
:)
(: TODO settle for a metadata format, for now we assume eXist's ACL notation :)
declare %property:name("acl") %property:realm("public") function project:acl($id as xs:string) as element(sm:permission)? {
    let $doc:=project:get($id)
    return $doc//mets:rightsMD[@ID=$config:PROJECT_ACL_ID]/mets:mdWrap/mets:xmlData/sm:permission
};

declare %method:name("acl") %method:realm("restricted") %method:group("projectadmins") function project:acl($id as xs:string, $data as element(sm:permission)?) as empty() {
    let $doc:=      project:get($id),
        $current:=  project:acl($id),
        $tpl :=     <sm:permission xmlns:sm="http://exist-db.org/xquery/securitymanager" owner="{project:adminaccountname($id)}" group="{project:adminaccountname($id)}" mode="rwx------">
                        <sm:acl entries="3">
                            <!-- sm:ace/@who='other' _must_ be present  -->
                            <sm:ace index="0" target="GROUP" who="other" access_type="DENIED" mode="rwx"/>
                            <sm:ace index="1" target="GROUP" who="{project:adminaccountname($id)}" access_type="ALLOWED" mode="rwx"/>
                            <sm:ace index="2" target="GROUP" who="{project:useraccountname($id)}" access_type="ALLOWED" mode="r-x"/>
                        </sm:acl>
                    </sm:permission>
    let $insert:= 
        if (exists($current))
        then 
            if (exists($data)) 
            then update replace $current with $data
            else update replace $current with $tpl
        else
            if (exists($doc//mets:rightsMD[@ID=$config:PROJECT_ACL_ID]))
            then update value $doc//mets:rightsMD[@ID=$config:PROJECT_ACL_ID]
                 with <mdWrap MDTYPE="OTHER" OTHERMDTYPE="EXISTACL" xmlns="http://www.loc.gov/METS/"><xmlData>{$data}</xmlData></mdWrap>
            else update insert <techMD ID="{$config:PROJECT_ACL_ID}" xmlns="http://www.loc.gov/METS/" GROUPID="config.xml"><mdWrap MDTYPE="OTHER" OTHERMDTYPE="EXISTACL"><xmlData>{$data}</xmlData></mdWrap></techMD> into $doc//mets:amdSec[@ID eq $config:PROJECT_AMDSEC_ID]
    return 
        if (project:acl($id)//sm:ace[@target eq 'GROUP' and @who eq 'other'])
        then ()
        else
            (: we have to make sure that there is an ACL entry for GROUP 'other' :)
            let $updated:=project:acl($id),
                $number := $updated/sm:acl/xs:integer(@entries),
                $newNumber := xs:integer($number) + 1
            return 
                (update insert <sm:ace index="0" target="GROUP" who="other" access_type="DENIED" mode="rwx"/>
                into $updated/sm:acl,
                for $i at $pos in $updated/sm:acl/sm:ace
                return update value $i/@index with xs:integer($pos)-1,  
                update value $updated/sm:acl/@entries with $newNumber)
};

