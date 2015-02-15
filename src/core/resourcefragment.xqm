xquery version "3.0";

module namespace rf="http://aac.ac.at/content_repository/resourcefragment";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at "repo-utils.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace resource="http://aac.ac.at/content_repository/resource" at "resource.xqm";
import module namespace wc="http://aac.ac.at/content_repository/workingcopy" at "wc.xqm";
import module namespace lt = "http://aac.ac.at/content_repository/lookuptable" at "lookuptable.xqm";
import module namespace project="http://aac.ac.at/content_repository/project" at "project.xqm";
import module namespace index="http://aac.ac.at/content_repository/index" at "index.xqm";

import module namespace fcs = "http://clarin.eu/fcs/1.0" at "../modules/fcs/fcs.xqm";

declare namespace mets="http://www.loc.gov/METS/";
declare namespace xlink="http://www.w3.org/1999/xlink";
declare namespace cr="http://aac.ac.at/content_repository";

(: declaration of helper namespaces for better code structuring :)
declare namespace param="userinput.parameters";
declare namespace this="current.object";


declare variable $rf:element-ns:=   $config:RESOURCE_RESOURCEFRAGMENT_ELEMENT_NSURI;
declare variable $rf:element-name:= $config:RESOURCE_RESOURCEFRAGMENT_ELEMENT_NAME;
declare variable $rf:default-path:= $config:default-resourcefragments-path;

declare %private function rf:make-div($resourcefragment-pid, $fileid as xs:string, $label as xs:string?) as element(mets:div) {
    <mets:div TYPE="{$config:PROJECT_RESOURCEFRAGMENT_DIV_TYPE}" ID="{$resourcefragment-pid}" LABEL="{$label}">
        <mets:fptr>
            <mets:area FILEID="{$fileid}" BEGIN="{$resourcefragment-pid}" END="{$resourcefragment-pid}" BETYPE="IDREF"/>
        </mets:fptr>
    </mets:div>
};

(:~
 : Registers the resourcefragments of a resource, stored in a fcs:Resource wrapper, 
 : with the mets record of the resource.
 :
 : @param $resource-pid the pid of the resource
 : @param $filepath the db-path to the xml file w/ extracted resourcefragments. we expect a structure like <fcs:Resource><fcs:ResourceFragment resourcefragment-pid="">...
 : @param $project-pid the ID of the project to operate in 
~:)
declare function rf:new($resource-pid as xs:string, $filepath as xs:string,$project-pid as xs:string) as xs:string* {
    let $fragments:=doc($filepath)//*[local-name(.) eq $rf:element-name and namespace-uri(.) eq $rf:element-ns]
    let $fragmentfile-id:=$resource-pid||$config:RESOURCE_RESOURCEFRAGMENT_FILEID_SUFFIX
    let $this:fragmentfile:=resource:make-file($fragmentfile-id,$filepath,'fragments')    
    let $register-fragmentfile:= resource:add-file($this:fragmentfile,$resource-pid,$project-pid)
    return 
        if (doc-available($filepath))
        then
            for $f in $fragments 
                let $this:pid:=xs:string($f/@*[name(.) eq $config:RESOURCEFRAGMENT_PID_NAME])
                let $this:label:=xs:string($f/@*[name(.) eq $config:RESOURCEFRAGMENT_LABEL_NAME])                
                let $this:div:=rf:make-div($this:pid,$fragmentfile-id, $this:label)
                 let $update:=resource:add-fragment($this:div,$resource-pid,$project-pid)
                return $this:pid
        else util:log-app("INFO",$config:app-name,"extracted resourcefragments file not found at "||$filepath)
};


(:~
 : This function removes a resourcefragment from the resources' structMap-entry (mets:div).
 : It does *not* remove the mets:file which is referenced by the fragment, as other resourcefragments
 : are likely to need it, unless it was the only, whose @FILEID pointed to this. In that case
 : also the mets:file element in the resource's mets:fileGrp is deleted.
 : 
 : @param $resourcefragment-pid the pid of the resourcefragment to work on
 : @param $resource-pid the pid of the resoruce to delete
 : @return empty sequence
~:)
declare function rf:remove($resourcefragment-pid as xs:string,$resource-pid as xs:string,$project-pid as xs:string) as empty() {
    let $mets:resource:=resource:get($resource-pid,$project-pid),
        $mets:fragment:=$mets:resource//mets:div[@TYPE eq $config:PROJECT_RESOURCEFRAGMENT_DIV_TYPE and @ID eq $resourcefragment-pid],
        $mets:fileID:=$mets:fragment/mets:fptr//@FILEID
    let $delete:=update delete $mets:fragment
    return 
        if (exists($mets:resource/root()//mets:fptr[.//@FILEID = $mets:fileID]))
        then ()
        else resource:remove-file($mets:fileID,$resource-pid,$project-pid)
};


(:~
 : The two argument version of this function removes all resourcefragments from the resource's structMap entry.
 :
 : @param $resource-pid the pid of the resoruce to delete
 : @param $project-pid the id of the project
 : @return empty sequence
~:)
declare function rf:remove($resource-pid as xs:string,$project-pid as xs:string) as empty() {
    let $mets:resource:=resource:get($resource-pid,$project-pid),
        $mets:fragments:=$mets:resource//mets:div[@TYPE eq $config:PROJECT_RESOURCEFRAGMENT_DIV_TYPE],
        $mets:fileids:=$mets:fragments//@FILEID
    return 
        (
            update delete $mets:resource//mets:div[@TYPE eq $config:PROJECT_RESOURCEFRAGMENT_DIV_TYPE],
            for $fileid in $mets:fileids 
            return resource:remove-file($file-id,$resource-pid,$project-pid)
        )
};
 

(:~
 : This function removes the data of a resourcefragment container and unregisters it in the resource's mets entry.
 : 
 : @param $resourcefragment-pid the pid of the resourcefragment to work on
 : @param $resource-pid the pid of the resoruce to delete
 : @param $project-pid the pid of the project
 : @return empty sequence
~:) 
declare function rf:remove-data($resource-pid as xs:string,$project-pid as xs:string) as empty() {
    let $rf:filepath:=  rf:path($resource-pid,$project-pid),  
        $rf:filename:=  tokenize($rf:filepath,'/')[last()],
        $rf:collection:=substring-before($rf:filepath,$rf:filename)
    return (xmldb:remove($rf:collection,$rf:filename),rf:remove($resource-pid,$project-pid))
};



(:~
 : This function returns the mets:div entry of the resource fragment.
 : 
 : @param $resourcefragment-pid the pid of the resourcefragment
 : @param $resource-pid the pid of the resource 
 : @param $project-pid the id of the project
 : @return the mets:div entry of the resourcefragment. 
~:)
declare function rf:record($resourcefragment-pid as xs:string, $resource-pid as xs:string, $project-pid as xs:string) as element(mets:div)? {
    let $resource:= resource:get($resource-pid, $project-pid)
    return $resource//mets:div[@TYPE eq $config:PROJECT_RESOURCEFRAGMENT_DIV_TYPE and @ID eq $resourcefragment-pid]
};

(:~
 : The two parameter version of this function gets the mets:file entry of the resource fragments file.
 : 
 : @param $resource-pid the pid of the resource 
 : @param $project-pid the id of the project
 : @return the mets:file element of the resourcefragments file. 
~:)
declare function rf:file($resource-pid as xs:string, $project-pid as xs:string) as element(mets:file)? {
    let $rf:fileGrp:=resource:files($resource-pid,$project-pid)
    return $rf:fileGrp/mets:file[@USE eq $config:RESOURCE_RESOURCEFRAGMENTS_FILE_USE]
};

(:~
 : Gets the database path to the resourcefragments cache of a resource.
 : 
 : @param $resource-pid the pid of the resource 
 : @param $project-pid the id of the project
 : @return   
~:)
declare function rf:path($resource-pid as xs:string, $project-pid as xs:string) as xs:string* {
    let $rf:fileGrp:=resource:files($resource-pid, $project-pid)
    return $rf:fileGrp/mets:file[@USE eq $config:RESOURCE_RESOURCEFRAGMENTS_FILE_USE]/mets:FLocat/@xlink:href
};

(:~
 : The three argument version of this function fetches content of the requested resourcefragment.
 : 
 : @param $resourcefragment-pid the pid of the resourcefragment
 : @param $resource-pid the pid of the resource 
 : @param $project-pid the pid of the project
 : @return   
~:)
declare function rf:get($resourcefragment-pid as xs:string, $resource-pid as xs:string, $project-pid as xs:string) as element()? {
    let $rf:location:=  rf:path($resource-pid, $project-pid),
        $rf:doc := if (doc-available($rf:location)) then doc($rf:location) else util:log-app("INFO",$config:app-name,"Could not locate resourcefragments from "||$rf:location) 
    return util:eval('$rf:doc//*[@'||$config:RESOURCEFRAGMENT_PID_NAME||'="'||$resourcefragment-pid||'"]') 
};

(:~ Finds the resourcefragmentS(!) containing an element with given @cr:id

 : @param $element-id the id of a xml-element expected inside some resourcefragment
 : @param $resource-pid the pid of the resource 
 : @param $project-pid the pid of the project
 : @return resourcefragment of the containing resourcefragment  
:)
declare function rf:lookup($element-id as xs:string, $resource-pid as xs:string, $project-pid as xs:string) as element()* {
(:    rf:dump($resource-pid, $project-pid)/id($element-id)/ancestor::fcs:resourceFragment    :)
(:    rf:dump($resource-pid, $project-pid)//*[@cr:id eq $element-id]/ancestor::fcs:resourceFragment    :)
    let $ids := lt:lookup($element-id,$resource-pid,$project-pid)
    let $log := util:log-app("DEBUG",$config:app-name,"$element-id ")
    let $log := util:log-app("DEBUG",$config:app-name,$element-id)
    let $log := util:log-app("DEBUG",$config:app-name,"$ids ")
    let $log := util:log-app("DEBUG",$config:app-name,$ids)
    return 
        for $i in $ids return rf:get($i,$resource-pid,$project-pid)
};

(:~ Finds the resourcefragmentS(!) containing an element with given @cr:id, returning its IDs

 : @param $element-id the id of a xml-element expected inside some resourcefragment
 : @param $resource-pid the pid of the resource 
 : @param $project-pid the pid of the project
 : @return pid of the containing resourcefragment  
:)
declare function rf:lookup-id($element-id as xs:string, $resource-pid as xs:string, $project-pid as xs:string) as xs:string* {
    (:let $rf := rf:lookup($element-id, $resource-pid, $project-pid)
    return util:eval('$rf/xs:string(@'||$config:RESOURCEFRAGMENT_PID_NAME||')'):)
    lt:lookup($element-id,$resource-pid,$project-pid)
};


(:~
 : Dumps the full content of the resourcefragments cache of a resource.
 : 
 : @param $resource-pid the pid of the resource 
 : @param $project-pid the pid of the project
 : @return the content of the resourcefragments chache 
~:)
declare function rf:dump($resource-pid as xs:string, $project-pid as xs:string) as document-node()? {
    let $rf:location:=  rf:path($resource-pid, $project-pid)
    return 
        if (doc-available($rf:location))
        then doc($rf:location)
        else util:log-app("INFO",$config:app-name, "resourcefragments cache document not available at "||$rf:location)
};


(:~
 : Generates the resourcefragments cache for a given resource, stores it to the database and 
 : registers it with the resource's structMap egentry. Gives back the database path to the cache file.
 : 
 : @param $resource-pid the pid of the resource 
 : @param $project-pid the id of the project
 : @return the database path to the resourcefragments cache  
~:)
declare function rf:generate($resource-pid as xs:string, $project-pid as xs:string) as xs:string? {
    let $master:=               resource:master($resource-pid,$project-pid),
        $master_filename :=     util:document-name($master),
        $master_collection :=   util:collection-name($master),
        $path-to-master :=      base-uri($master),  
        $config:=               config:config($project-pid),
        $stored-wc :=           wc:get-data($resource-pid,$project-pid),
        $working-copy:=         if (exists($stored-wc)) 
                                then $stored-wc
                                else 
                                    let $wc:new:= wc:generate($resource-pid,$project-pid)
                                    return wc:get-data($resource-pid,$project-pid),
        $index-name :=          $config:INDEX_RESOURCEFRAGMENT_DELIMITER,
        $rf:xpathexpr :=        index:index-as-xpath($index-name, $project-pid),        
        $rf:xpathexpr-label :=        index:index-as-xpath($index-name, $project-pid,'label-only')
    return
        if ($rf:xpathexpr = $index-name)
        then util:log-app("INFO",$config:app-name, "Could not resolve index name "||$index-name||" in mappings for project "||$project-pid)
        else 
            let $define-ns:=
                let $mappings:=     config:mappings($config),
                    $namespaces:=   $mappings//namespaces
                return 
                    for $ns in $namespaces/ns
                    let $prefix:=   $ns/@prefix,
                        $namespace-uri:=$ns/@uri
                    let $log:=util:log-app("INFO",$config:app-name, "declaring namespace "||$prefix||"='"||$namespace-uri||"'")
                    return util:declare-namespace(xs:string($prefix), xs:anyURI($namespace-uri))
           
            (: extract fragments and create wrapper elements for each :)
            (:let $all-fragments:=util:eval("$working-copy//"||$rf:xpathexpr):)
            let $all-fragments := index:apply-index($working-copy,'rf',$project-pid)
            
            (:let $fragment-element-has-content:=some $x in $all-fragments satisfies exists($x/node()):)
            let $fragments-extracted:=
                for $pb1 at $pos in $all-fragments 
(:                    let $id:=$resource-pid||$config:RESOURCE_RESOURCEFRAGMENT_FILEID_SUFFIX||format-number($pos, '00000000'):)
                    let $id := $resource-pid||$config:RESOURCE_RESOURCEFRAGMENT_ID_SUFFIX||$pos
                    (:let $label := util:eval("$pb1/"||$rf:xpathexpr-label):)
                    let $label := index:apply-index($pb1, "rf", $project-pid, "label-only")
                    let $fragment:=
                        if (exists($pb1/node()))
                        then 
                            ($pb1, util:log-app("INFO",$config:app-name,"copying resourcefragment w/ pid="||xs:string($id)))
                        else
                        let $log:=util:log-app("INFO",$config:app-name,"processing resourcefragment w/ pid="||xs:string($id)||" "||$pb1/@cr:id)
                            let $pb2:=util:eval("(for $x in $all-fragments where $x >> $pb1 return $x)[1]")
                        (: if no subsequent element, dont trying to generate fragment will fail :)
                        return
(:                            return if (empty($pb2)) then $pb1 :)
(:                                     else:)
                                        let $frag :=util:get-fragment-between($pb1, $pb2, true(), true())
                                        let $analyzed :=  analyze-string($frag,'&amp;(amp;)?')
                                        let $replaced := string-join((for $i in $analyzed/* return if($i/self::fn:non-match) then $i else '&amp;amp;'),'')
                                        return util:parse(($replaced,$frag)[1])                    
(:                                       else util:parse-html(util:get-fragment-between($pb1, $pb2, true(), true()))/HTML/BODY/*:)
                    return
                        element {
                            QName(
                                $config:RESOURCE_RESOURCEFRAGMENT_ELEMENT_NSURI,
                                $config:RESOURCE_RESOURCEFRAGMENT_ELEMENT_NAME
                            )
                        }{
                            attribute {$config:PROJECT_PID_NAME} {$project-pid},
                            attribute {$config:RESOURCE_PID_NAME} {$resource-pid},
                            attribute {$config:RESOURCEFRAGMENT_PID_NAME} {$id},
                            attribute {$config:RESOURCEFRAGMENT_LABEL_NAME} {$label},
                            $fragment
                        }
            
           (: pack extracted fragments into container and add metadata :)
           let $rf:container:= 
                    element {
                        QName(
                            $config:RESOURCE_RESOURCE_ELEMENT_NSURI,
                            $config:RESOURCE_RESOURCE_ELEMENT_NAME
                        )
                    }{
                        attribute {$config:PROJECT_PID_NAME} {$project-pid},
                        attribute {$config:RESOURCE_PID_NAME} {$resource-pid},
                        attribute timestamp {current-dateTime()},
                        attribute masterFileLastmodified {xmldb:last-modified($master_collection,$master_filename)},
                        attribute masterFilePath {$path-to-master},
                        $fragments-extracted
                    }
                    
            (: store the fragments container in the database :)
(:          first returns full path down to file, second one only the collection - complicated to handle in case, the file already exists  
            let $rf:path-param :=       (rf:path($resource-pid,$project-pid), project:path($project-pid,"resourcefragments"))[1],:)
            let $rf:path-param :=       project:path($project-pid,"resourcefragments"),
                $rf:path:=              replace($rf:path-param,'/$',''),
                $rf:current-filepath := resource:path($resource-pid,$project-pid,"resourcefragments"),
(:                $rf:filename:=          $config:RESOURCE_RESOURCEFRAGMENT_FILENAME_PREFIX||$master_filename,:)
                $rf:filename:=          if ($rf:current-filepath != '')
                                            then tokenize($rf:current-filepath,'/')[last()]
                                            else $config:RESOURCE_RESOURCEFRAGMENT_FILENAME_PREFIX||$resource-pid||".xml",    
                        
                $rf:filepath:=          $rf:path||"/"||$rf:filename
(:            let $rf:store:=repo-utils:store-in-cache($rf:filename,$rf:path,$rf:container,$config)
                allows to overwrite :)
              let $rf:store:=repo-utils:store($rf:path,$rf:filename,$rf:container,true(),$config)
            
            (: register resourcefragments with the METS record :)
            let $update-mets:=rf:new($resource-pid,$rf:filepath,$project-pid)
            return $rf:filepath
};


declare function rf:cite($resourcefragment-pid, $resource-pid, $project-pid, $config) {
let $cite-template := config:param-value($config,'cite-template')
let $ns := config:param-value($config,'mappings')//namespaces/ns!util:declare-namespace(xs:string(@prefix),xs:anyURI(@uri))
let $today := format-date(current-dateTime(),'[D]. [M]. [Y]')
let $md := resource:dmd-from-id('TEIHDR',  $resource-pid, $project-pid)
let $link := rf:link($resourcefragment-pid, $resource-pid, $project-pid, $config) 
let $entity-label := rf:record($resourcefragment-pid,$resource-pid, $project-pid)/data(@LABEL)  

(:return $md:)
return util:eval ("<bibl>"||$cite-template||"</bibl>")
};

declare function rf:link($rf-id, $resource-pid, $project-pid, $config) {
    replace(config:param-value($config, 'base-url-public'),'/$','')||'/'||$project-pid||'/'||'get/'||$rf-id
};
