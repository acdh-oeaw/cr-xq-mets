xquery version "3.0";

module namespace rf="http://aac.ac.at/content_repository/resourcefragment";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at "repo-utils.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace resource="http://aac.ac.at/content_repository/resource" at "resource.xqm";
import module namespace wc="http://aac.ac.at/content_repository/workingcopy" at "wc.xqm";

declare namespace mets="http://www.loc.gov/METS/";
declare namespace xlink="http://www.w3.org/1999/xlink";
declare namespace fcs = "http://clarin.eu/fcs/1.0";
declare namespace cr="http://aac.ac.at/content_repository";

(: declaration of helper namespaces for better code structuring :)
declare namespace param="userinput.parameters";
declare namespace this="current.object";


declare variable $rf:element-ns:=   $config:RESOURCE_RESOURCEFRAGMENT_ELEMENT_NSURI;
declare variable $rf:element-name:= $config:RESOURCE_RESOURCEFRAGMENT_ELEMENT_NAME;
declare variable $rf:default-path:= $config:default-resourcefragments-path;
declare variable $rf:use:=          $config:RESOURCE_RESOURCEFRAGMENTS_FILE_USE;

declare %private function rf:make-div($param:resourcefragment-pid as xs:string, $param:fileid as xs:string) as element(mets:div) {
    <mets:div TYPE="{$config:PROJECT_RESOURCEFRAGMENT_DIV_TYPE}" ID="{$param:resourcefragment-pid}">
        <mets:fptr>
            <mets:area FILEID="{$param:fileid}" BEGIN="{$param:resourcefragment-pid}" END="{$param:resourcefragment-pid}" BETYPE="IDREF"/>
        </mets:fptr>
    </mets:div>
};

(:~
 : Registers the resourcefragments of a resource, stored in a fcs:Resource wrapper, 
 : with the mets record of the resource.
 :
 : @param $param:resource-pid the pid of the resource
 : @param $param:filepath the db-path to the xml file w/ extracted resourcefragments. we expect a structure like <fcs:Resource><fcs:ResourceFragment resourcefragment-pid="">...
 : @param $param:context the ID of the project to operate in 
~:)
declare function rf:new($param:resource-pid as xs:string,$param:filepath as xs:string,$param:context as xs:string) as xs:string* {
    let $fragments:=doc($param:filepath)//*[QName($rf:element-ns,$rf:element-name)]
    let $fragmentfile-id:=$param:resource-pid||$config:RESOURCE_RESOURCEFRAGMENT_FILEID_SUFFIX
    let $this:fragmentfile:=resource:make-file($fragmentfile-id,$param:filepath,'fragments')    
    let $register-fragmentfile:= resource:add-file($this:fragmentfile,$param:resource-pid,$param:context)
    return 
        if (doc-available($param:filepath))
        then
            for $f in $fragments 
                let $this:pid:=xs:string($f/@resourcefragment-pid)
                let $log:=util:log("INFO","registered resourcefragment "||$this:pid||" with resource "||$param:resource-pid)
                let $this:div:=rf:make-div($this:pid,$fragmentfile-id)
                let $update:=resource:add-fragment($this:div,$param:resource-pid,$param:context)
                return $this:pid
        else util:log("INFO","extracted resourcefragments file not found at "||$param:filepath)
};



(:~
 : This function removes a resourcefragment from the resources' structMap-entry (mets:div).
 : It does *not* remove the mets:file which is referenced by the fragment, as other resourcefragments
 : are likely to need it, unless it was the only, whose @FILEID pointed to this. In that case
 : also the mets:file element in the resource's mets:fileGrp is deleted.
 : 
 : @param $param:resourcefragment-pid the pid of the resourcefragment to work on
 : @param $param:resource-pid the pid of the resoruce to delete
 : @return empty sequence
~:)
declare function rf:remove($param:resourcefragment-pid as xs:string,$param:resource-pid as xs:string,$param:context as xs:string) as empty() {
    let $mets:resource:=resource:get($param:resource-pid,$param:context),
        $mets:fragment:=$mets:resource//mets:div[@TYPE eq $config:PROJECT_RESOURCEFRAGMENT_DIV_TYPE and @ID eq $param:resourcefragment-pid],
        $mets:fileID:=$mets:fragment/mets:fptr//@FILEID
    let $delete:=update delete $mets:fragment
    return 
        if (exists($mets:resource/root()//mets:fptr[.//@FILEID = $mets:fileID]))
        then ()
        else resource:remove-file($mets:fileID,$param:resource-pid,$param:context)
};


(:~
 : The two argument version of this function removes all resourcefragments from the resource's structMap entry.
 :
 : @param $param:resource-pid the pid of the resoruce to delete
 : @param $param:context the id of the project
 : @return empty sequence
~:)
declare function rf:remove($param:resource-pid as xs:string,$param:context as xs:string) as empty() {
    let $mets:resource:=resource:get($param:resource-pid,$param:context),
        $mets:fragments:=$mets:resource//mets:div[@TYPE eq $config:PROJECT_RESOURCEFRAGMENT_DIV_TYPE],
        $mets:fileids:=$mets:fragments//@FILEID
    return 
        (
            update delete $mets:resource//mets:div[@TYPE eq $config:PROJECT_RESOURCEFRAGMENT_DIV_TYPE],
            for $fileid in $mets:fileids 
            return resource:remove-file($file-id,$param:resource-pid,$param:context)
        )
};


(:~
 : This function removes the data of a resourcefragment container and unregisters it in the resource's mets entry.
 : 
 : @param $param:resourcefragment-pid the pid of the resourcefragment to work on
 : @param $param:resource-pid the pid of the resoruce to delete
 : @param $param:context the id of the project
 : @return empty sequence
~:)
declare function rf:remove-data($param:resource-pid as xs:string,$param:context as xs:string) as empty() {
    let $rf:filepath:=  rf:get-path($param:resource-pid,$param:context),  
        $rf:filename:=  tokenize($rf:filepath,'/')[last()],
        $rf:collection:=substring-before($rf:filepath,$rf:filename)
    return (xmldb:remove($rf:collection,$rf:filename),rf:remove($param:resource-pid,$param:context))
};



(:~
 : This function returns the mets:div entry of the resource fragment.
 : 
 : @param $param:resourcefragment-pid the pid of the resourcefragment
 : @param $param:resource-pid the pid of the resource 
 : @param $param:context the id of the project
 : @return the mets:div entry of the resourcefragment. 
~:)
declare function rf:get($param:resourcefragment-pid as xs:string, $param:resource-pid as xs:string, $param:context as xs:string) as element(mets:div)? {
    let $resource:= resource:get($param:resource-pid, $param:context)
    return $resource//mets:div[@TYPE eq $config:PROJECT_RESOURCEFRAGMENT_DIV_TYPE and @ID eq $param:resourcefragment-pid]
};

(:~
 : The two parameter version of this function gets the mets:file entry of the resource fragments file.
 : 
 : @param $param:resource-pid the pid of the resource 
 : @param $param:context the id of the project
 : @return the mets:file element of the resourcefragments file. 
~:)
declare function rf:get-file($param:resource-pid as xs:string, $param:context as xs:string) as element(mets:file)? {
    let $rf:fileGrp:=resource:get-resourcefiles($param:resource-pid,$param:context)
    return $rf:fileGrp/mets:file[@USE eq $rf:use]
};

(:~
 : Gets the database path to the resource fragments cache of a resource.
 : 
 : @param $param:resource-pid the pid of the resource 
 : @param $param:context the id of the project
 : @return   
~:)
declare function rf:get-path($param:resource-pid as xs:string, $param:context as xs:string) as xs:string? {
    let $rf:fileGrp:=resource:get-resourcefiles($param:resource-pid,$param:context)
    return $rf:fileGrp/mets:file[@USE eq $rf:use]/mets:FLocat/@xlink:href
};

(:~
 : The three argument version of this function fetches content of the requested resourcefragment.
 : 
 : @param 
 : @param $param:resource-pid the pid of the resource 
 : @param $param:context the id of the project
 : @return   
~:)
declare function rf:get-data($param:resourcefragment-pid as xs:string, $param:resource-pid as xs:string, $param:context as xs:string) as element()? {
    let $rf:data:=rf:get-data($param:resource-pid, $param:context)
    return $rf:data//*[@resourcefragment-pid eq $param:resourcefragment-pid]
};

(:~
 : Gets the full content of the resourcefragments cache of a resource.
 : 
 : @param $param:resource-pid the pid of the resource 
 : @param $param:context the id of the project
 : @return the content of the resourcefragments chache
~:)
declare function rf:get-data($param:resource-pid as xs:string, $param:context as xs:string) as document-node() {
    let $rf:location:=  rf:get-path($param:resource-pid, $param:context)
    return 
        if (doc-available($rf:location))
        then doc($rf:location)
        else util:log("INFO", "resourcefragments cache document not available at "||$rf:location)
};

(:~
 : Generates the resourcefragments cache for a given resource, stores it to the database and 
 : registers it with the resource's structMap entry. Gives back the database path to the cache file.
 : 
 : @param $param:resource-pid the pid of the resource 
 : @param $param:context the id of the project
 : @return the database path to the resourcefragments cache  
~:)
declare function rf:generate($param:resource-pid as xs:string, $param:path-to-master as xs:string, $param:context as xs:string) as xs:string? {
    let $master-data:=  doc($param:path-to-master),
        $config:=       config:config($param:context),
        $stored-wc :=   wc:get-data($param:resource-pid,$param:context),
        $working-copy:= if (exists($stored-wc)) 
                        then $stored-wc
                        else wc:generate($param:resource-pid,$param:context)
    return
        let $define-ns:=
            let $mappings:=config:mappings($config),
                $namespaces:=$mappings//namespaces
            return 
                for $ns in $namespaces/ns
                let $prefix:=$ns/@prefix,
                    $namespace-uri:=$ns/@uri
                let $log:=util:log("INFO", "declaring namespace "||$prefix||"='"||$namespace-uri||"'")
                return util:declare-namespace(xs:string($prefix), xs:anyURI($namespace-uri))
       
       (: extract fragments and create wrapper elements for each :)
       let $all-fragments:=util:eval("$working-copy//"||$resource-fragment-path)
            let $fragment-element-has-content:=some $x in $all-fragments satisfies exists($x/*)
            let $fragments-extracted:=
                for $pb1 at $pos in $all-fragments 
                    let $id:=$resource-pid||$config:RESOURCE_RESOURCEFRAGMENT_FILEID_SUFFIX||format-number($pos, '00000000')
                    let $fragment:=
                        if ($fragment-element-has-content)
                        then $pb1
                        else 
                            let $pb2:=util:eval("(for $x in $all-fragments where $x >> $pb1 return $x)[1]")
                            return util:parse(util:get-fragment-between($pb1, $pb2, true(), true()))
                    let $log:=util:log("INFO","processing resourcefragment w/ pid="||xs:string($id))
                    return
                        element {
                            QName(
                                $config:RESOURCE_RESOURCEFRAGMENT_ELEMENT_NSURI,
                                $config:RESOURCE_RESOURCEFRAGMENT_ELEMENT_NAME
                            )
                        }{
                            attribute project-id {$param:context},
                            attribute resource-pid {$param:resource-pid},
                            attribute resourcefragment-pid {$id},
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
                    attribute project-id {$param:context},
                    attribute resource-pid {$param:resource-pid},
                    attribute resourcefragment-pid {$id},
                    attribute timestamp {current-dateTime()},
                    attribute masterFileLastmodified {xmldb:last-modified($collection,$filename)},
                    attribute masterFilePath {$param:path-to-master},
                    $fragments-extracted
                }
                
        (: store the fragments container in the database :)
        let $rf:path-param :=       ($config//param[@key='resourcefragments.path'],$rf:default-path)[1],
            $rf:path:=              replace($rf:path-param,'/$',''),
            $rf:filename:=          $config:RESOURCE_RESOURCEFRAGMENT_FILENAME_SUFFIX||$filename,
            $rf:filepath:=          $rf:path||"/"||$rf:filename
        let $rf:store:=repo-utils:store-in-cache($rf:filename,$rf:path,$rf:container,$config)
        
        (: register resourcefragments with the METS record :)
        let $update-mets:=rf:new($param:resource-pid,$rf:filepath,$param:context)
        return 
            switch (true())
                case (not(exists($wc))) return util:log("INFO", "working copy for resource "||$param:resource-pid||" was not found.")
                default return $rf:filepath
};
