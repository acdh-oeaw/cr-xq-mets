xquery version "3.0";

module namespace wc="http://aac.ac.at/content_repository/workingcopy";
import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm"; 
import module namespace resource="http://aac.ac.at/content_repository/resource" at "resource.xqm";
import module namespace project="http://aac.ac.at/content_repository/project" at "project.xqm";
import module namespace repo-utils="http://aac.ac.at/content_repository/utils" at "repo-utils.xqm";

(:~
 : Getter / setter / storage functions for the entity "working copy".
 :
 : Creating a working copy is the first step of ingesting data into the content repository.
 : Essentially it is an identity transformation of the data with the following information bits
 : added to each element():
 : 
 : - a locally unique xml:id (@cr:id)
 : - the project wide unique pid of the cr resource which it represents (@cr:resource-pid)
 : - the content repository wide unique id of the project the resource is part of (@cr:project-id)
 :
 : All queries which are performed on a project's dataset, are performed on working copies, while 
 : the master of the data is just kept as reference. This is crucial as it facilitates 
 : mapping the arbitrary search result on the FCS data structure (i.e. 'resources' and 
 : 'resource fragments'), as well as consistent match higlighting between structural searches (i.e. 
 : standard xpath) and fulltext or ngram searches which do not offer match highlighting for attribute 
 : values.
 :
 : Stored working copies have to be registered with a resource in the project's mets:record by adding a
 : mets:file element to the resource's mets:fileGrp with an appropriate value in its @USE attribute. 
 : This value is globally set in the variable $config:RESOURCE_WORKINGCOPY_FILE_USE, by default it is 'WORKING COPY'.
 :
 : The storage path of a working copy may be defined in the project's config, in a parameter 
 : with the key 'working-copies.path'. The default path is set globally in the 
 : variable $config:default-working-copy-path.
 :
 : @author daniel.schopper@oeaw.ac.at
 : @since 2013-11-08
~:)



(: declaration of helper namespaces for better code structuring :)
declare namespace param="userinput.parameters";
declare namespace this="current.object";

declare namespace mets="http://www.loc.gov/METS/";
declare namespace xlink="http://www.w3.org/1999/xlink";
declare namespace fcs = "http://clarin.eu/fcs/1.0";
declare namespace cr="http://aac.ac.at/content_repository";


(:~
 : Path to the stylesheet which creates the working copy.
~:)
declare variable $wc:path-to-xsl:=      $config:app-root||"/core/wc.xsl";
declare variable $wc:default-path:=     $config:default-workingcopy-path;
declare variable $wc:filename-prefix:=  $config:RESOURCE_WORKINGCOPY_FILENAME_PREFIX;

declare variable $wc:behavior-btype :=  "wc_generation";

(:~
 : Generates a working copy from the $resource-pid, stores it in the database and 
 : registers it with the resources entry.
 : 
 : @param $resource-pid the pid of the resource 
 : @param $project-id the id of the project to work in
 : @return the path to the working copy
~:)
declare function wc:generate($resource-pid as xs:string, $project-pid as xs:string) as xs:string? {
    let $config:=           config:config($project-pid),
        (: look for the wc:path: either it is already registered and can be retrieved with resource:path() 
        or we have to construct it anew with project:path() :)
        $wc:path:=          (util:collection-name(resource:path($resource-pid,$project-pid,'workingcopy')),
                            project:path($project-pid,'workingcopies'))[1],
        $wc:path-create :=  if (doc-available(resource:path($resource-pid,$project-pid,'workingcopy')) or xmldb:collection-available($wc:path))
                            then ()
                            else 
                                let $fstStep:=tokenize($wc:path,'/')[1],
                                    $rest := substring-after($wc:path,$fstStep)
                                return (
                                    repo-utils:mkcol($fstStep,$rest),
                                    sm:chown($wc:path,project:adminsaccountname($project-pid)),
                                    sm:chgrp($wc:path,project:adminsaccountname($project-pid)),
                                    sm:add-user-ace($wc:path,$config:cr-writer-accountname,true(),'rwx'),
                                    sm:add-group-ace($wc:path,$config:cr-writer-accountname,true(),'rwx')
                                 ),
        $master:=           resource:master($resource-pid,$project-pid),
        $master_filename:=  util:document-name($master),
        $wc:filename :=     $wc:filename-prefix||$master_filename
    let $preprocess-xsl :=  resource:get-preprocess-xsl-path($resource-pid,$project-pid)
    return 
    switch(true())
            case $wc:path eq '' 
                return util:log("INFO","$wc-path empty!")
            default 
                return 
                    let $xsl-params:=
                                <parameters>
                                    <param name="resource-pid" value="{$resource-pid}"/>
                                    <param name="project-id" value="{$project-pid}"/>
                                </parameters>
                    let $preprocess := 
                        if ($preprocess-xsl = '' or not(doc-available($preprocess-xsl))) 
                        then $master 
                        else (transform:transform($master,doc($preprocess-xsl),()),
                              util:log-app("INFO",$config:app-name,"resource "||$resource-pid||"(project "||$project-pid||") has been preprocessed by "||$preprocess-xsl))
                    let $wc:generated := transform:transform($preprocess,doc($wc:path-to-xsl),$xsl-params),
                        $store-wc := repo-utils:store($wc:path,$wc:filename,$wc:generated,true(),$config),
                        $wc:filepath := base-uri($store-wc),
                        $log := util:log-app("INFO",$config:app-name,"working copy for "||$resource-pid||" has been stored to "||$wc:filepath),
                        $wc:chown := (sm:chown($wc:filepath,project:adminsaccountname($project-pid)),
                                      sm:chgrp($wc:filepath,project:adminsaccountname($project-pid)),
                                      sm:add-user-ace($wc:filepath,$config:cr-writer-accountname,true(),'rwx'),
                                      sm:add-group-ace($wc:filepath,$config:cr-writer-accountname,true(),'rwx')) 
                    (: register working copy with :)
                    let $update-mets:= 
                        if ($wc:filepath!='') 
                        then wc:add($wc:filepath,$resource-pid,$project-pid) 
                        else util:log-app("ERROR",$config:app-name,"$wc:filepath is empty")
                    return $wc:filepath 
};

(:~
 : Removes the data of a working copy from the database.
 :  
 : @param $resource-pid pid of the resource 
 : @param $project-pid id of the project
 : @return empty()
~:)
declare function wc:remove-data($resource-pid as xs:string,$project-pid as xs:string) as empty() {
    let $wc:path:=          wc:get-path($resource-pid, $project-pid),
        $wc:filename:=      tokenize($wc:path,'/')[last()],
        $wc:collection:=    substring-before($wc:path,$wc:filename)
    return xmldb:remove($wc:collection,$wc:filename)
};

(:~
 : Gets the registered working copy as its mets:file.
 : 
 : @param $resource-pid pid of the resource 
 : @param $project-pid id of the project
 : @return the mets:file entry of the working copy.
~:)
declare function wc:get($resource-pid as xs:string,$project-pid as xs:string) as element(mets:file)? {
    let $mets:resource:=resource:get($resource-pid,$project-pid),
        $mets:resource-files:=resource:files($resource-pid,$project-pid)
        (: the working copy is one of several <fptr> elements directly under the resource's mets:div, e.g. :)
        (: <div TYPE='resource'>
                    <fptr FILEID="id-of-masterfile"/>
                    <fptr FILEID="id-of-workingcopy"/>
                    <fptr FILEID="id-of-resourcefragments-file"/>
                    ....
                </div>
        :)
        (: we have to find the right <file> element by looking at all of them and determining each one's @USE attribute :)
    let $mets:workingcopy:=$mets:resource-files/mets:file[@USE eq $config:RESOURCE_WORKINGCOPY_FILE_USE]
    return switch (true())
        case not($mets:resource) return util:log-app("ERROR", $config:app-name,'Unknown resource with PID '||$resource-pid)
        case not($mets:resource-files) return util:log-app("ERROR", $config:app-name,'Resource files mets entries not found for '||$resource-pid)
        case not($mets:workingcopy) return util:log-app("ERROR", $config:app-name,'Working copy mets file entry not found for '||$resource-pid)
        default return $mets:workingcopy
};

(:~
 : Returns the database path to the content of the resource's working copy.
 : 
 : @param $resource-pid the pid of the resource
 : @param $project-pid: the id of the current project
 : @return the path the workingcopy of the resource as xs:anyURI 
~:)
declare function wc:get-path($resource-pid,$project-pid) as xs:anyURI? {
    let $wc:=wc:get($resource-pid,$project-pid)
    return xs:anyURI($wc/mets:FLocat/@xlink:href)
};

(:~
 : Returns the content of a working copy as a document-node().
 : 
 : @param $resource-pid the pid of the resource
 : @param $project-pid: the id of the current project
 : @return if available, the document node of the working copy, otherwise an empty sequence. 
~:)
declare function wc:get-data($resource-pid,$project-pid) as document-node()? {
    let $wc-path:=wc:get-path($resource-pid,$project-pid)
    return 
        if (doc-available($wc-path))
        then doc($wc-path)
        else util:log-app("INFO",$config:app-name,"requested working copy  at "||$wc-path||" is not available.")
};


(:~
 : Registers the data of a working copy with the resource by appending a mets:file element to
 : the resources mets:fileGrp.
 : If there is already a working copy registered with this resource, it will be replaced.
 : Note that this function does not actually create and store the working copy. This is done by 
 : wc:generate() which calls this function.
 : 
 : @param $path the path to the stored working copy
 : @param $resource-pid the pid of the resource
 : @param $project-pid: the id of the current project
 : @return the added mets:file element 
~:)
declare function wc:add($path as xs:string, $resource-pid as xs:string, $project-pid as xs:string) as element(mets:file)? {
    let $mets:resource:=resource:get($resource-pid,$project-pid)
    let $mets:wc-file:=wc:get($resource-pid,$project-pid),
        (: get the fileptr to an existing wc :)
        $mets:wc-fptr:=$mets:resource//mets:fptr[@FILEID eq $mets:wc-file/@ID]
    (: construct new wc node :)
    let $this:wc-fileid:=$resource-pid||$config:RESOURCE_WORKINGCOPY_FILEID_SUFFIX,
        $this:wc-file:=resource:make-file($this:wc-fileid,$path,"wc"), 
        $this:wc-fptr:=<mets:fptr FILEID="{$this:wc-fileid}"/>
    return
        if (exists($mets:wc-file))
        then 
            let $replace-file:=update replace $mets:wc-file with $this:wc-file
            let $replace-fileptr:=update replace $mets:wc-fptr with $this:wc-fptr
            let $log := util:log-app("DEBUG", $config:app-name, "mets:wc-file exists")
            return $this:wc-file
        else 
            let $log := util:log-app("DEBUG", $config:app-name, exists(resource:files($resource-pid,$project-pid)))
            let $log := util:log-app("DEBUG", $config:app-name, "resource-pid:" ||$resource-pid||" project-pid: "||$project-pid)
            let $master := resource:get-master($resource-pid,$project-pid)
            (: we insert the wc <file> right after the resource's master <file> :)
            let $insert-file:= update insert $this:wc-file following $master
            (: we insert the wc <fptr> right after the <fptr> to the resource's master file :)
            let $insert-fileptr:=update insert $this:wc-fptr following $mets:resource/mets:fptr[1]
            return $this:wc-file            
};

(:~
 : looks up a specific element in the working copy via it's document-wide unique @cr:id attribute.
 : @param $cr:id the cr:id of the elment to find
 : @param $resource-pid the pid of the resource
 : @param $project-pid: the id of the current project
 : @return zero or one element in the working copy 
~:)
declare function wc:lookup($cr:id as xs:string, $resource-pid as xs:string, $project-pid as xs:string) as element()? {
    let $wc:=wc:get-data($resource-pid,$project-pid)
    return $wc//*[@cr:id eq $cr:id]
};