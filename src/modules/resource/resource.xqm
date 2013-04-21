xquery version "3.0";

(:~ a module to handle resources and their corresponding metadata

    provide a common getter
    pid-handling
    
    not TESTED yet!
:)
   
module namespace resource = "http://cr-xq/resource" ;
import module namespace config="http://exist-db.org/xquery/apps/config" at "../../core/config.xqm";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at  "../../core/repo-utils.xqm";
import module namespace httpclient="http://exist-db.org/xquery/httpclient";
import module namespace util="http://exist-db.org/xquery/util"; 

(:declare namespace tei = "http://www.tei-c.org/ns/1.0" ;:)
declare namespace templates="http://exist-db.org/xquery/templates";
declare namespace cmd= "http://www.clarin.eu/cmd/"; 
declare namespace cr = "http://aac.ac.at/content-repository";
declare namespace xhtml = "http://www.w3.org/1999/xhtml";


(:~ default viewer, fetching data, transforming with xslt 
based on text-viewer 
tries to get the resources matching the @xml:id, then the filename (in the data- and metadata-path)

@param $id id can be @xml:id or file-name
:)

declare function resource:get ($config-map, $id as xs:string) {

    let $data-dir := config:param-value($config-map, 'data-dir'),
    $resource-by-id := collection($data-dir)//*[@xml:id eq $id],
    $resource := if (exists($resource-by-id)) then $resource-by-id
                 else if (doc-available(concat($data-dir, '/', $id))) then
                            doc(concat($data-dir, '/', $id))
                 (: if not resource found, try to get a metadata-record :)
                 else resource:getMD($config-map,$id)
                 
    
    
    return if (exists($resource)) then $resource 
                else <diagnostics><message>Resource unavailable, id: { ($id, ' in ', data-dir) } </message></diagnostics> 

};


declare function resource:getMD ($config-map, $id as xs:string) {

    let $metadata-dir := config:param-value($config-map, 'metadata-path'),
        $id-cmd := concat($id, '.cmd'),
        $md-record-by-id := collection($metadata-dir)//*[@xml:id = ($id,$id-cmd)],
        $md-record := if (exists($md-record-by-id)) then $md-record-by-id 
                 else if (doc-available(concat($metadata-dir, '/', $id-cmd))) then
                            doc(concat($metadata-dir, '/', $id-cmd))
                 else ()
    
    return if (exists($md-record)) then $md-record 
                else <diagnostics><message>MD-record unavailable, id: { ($id, ' in ', $metadata-dir) } </message></diagnostics> 

};


 (:~ add an id to given resources (expect one per file, or per given element?)
@param $path (relative) xpath to the resource-nodes, if empty or '' root-elements of files in project-data-directory are assumed
               always evaluated in the context of project-data-dir, path-separators ('/' or '//') will be added
@param $mode add-only, replace, dry-run 
@prefix for the id
 @return number of processed resources :) 
 declare function resource:addID($config-map, $path as xs:string?, $mode as xs:string?, $prefix as xs:string,  $log-doc as node()*) as item()* {
 
 let $resolved-path := if ($path='' or not(exists($path ))) then '/*' else concat('//', $path) 
 
 let $data-dir := config:param-value($config-map, 'data-dir'),    
     $resources := util:eval(concat("collection($data-dir)", $resolved-path))
    
   let $result :=count($resources) 
 
    let $update := if ($mode='replace') then  		
		                    
		                    for $resource at $pos in $resources
		                      return update insert attribute xml:id {concat($prefix, $pos)} into $resource
                        else ()
 
    return  ($result, $update)
 
 };
 
 (:~ add PID to given resources (expect one per file, or per given element?)
@param $path (relative) xpath to the resource-nodes, if empty or '' root-elements of files in project-data-directory are assumed
               always evaluated in the context of project-data-dir, path-separators ('/' or '//') will be added
@param $mode add-only, replace, dry-run 
@prefix for the id
 @return number of processed resources :) 
 declare function resource:addPID($config-map, $path as xs:string?, $mode as xs:string?, $prefix as xs:string,  $log-doc as node()*) as item()* {
 
 let $resolved-path := if ($path='' or not(exists($path ))) then '/*[@xml:id]' else concat('//', $path) 
 
 let $data-dir := config:param-value($config-map, 'data-dir'),    
     $resources := util:eval(concat("collection($data-dir)", $resolved-path))
    
   let $result :=count($resources) 
 
    let $update := if ($mode='replace') then  		
		                    
		                    for $resource at $pos in $resources
		                      let $pid := resource:getPID($config-map, $resource/@xml:id)
		                      return update insert attribute cr:pid {$pid} into $resource
                        else ()
 
    return  ($result, $update)
 
 };
 
 (:~ send a request to PID-service, to receive a new PID for given resource, 
 send target-url as param
 http://clarin.aac.ac.at/cr/get?id=$id

corresponds to:
curl -o create-output.html -v -u 'USERNAME:PASSWORD' -H "Accept:application/json" -H "Content-Type:application/json" -X POST --data '[{"type":"URL","parsed_data":"http://www.gwdg.de/TEST/1234"}]' "http://pid.gwdg.de/handles/11022/"

requires credentials to be set in the config
        <param key="pid-service">http://pid-test.gwdg.de/handles/11022/</param>
        <param key="pid-resolver">http://</param>
        <param key="pid-username">1013-01</param>
        <param key="pid-pwd">pwd</param>
        
:)
 declare function resource:getPID($config-map, $id as xs:string) as xs:anyURI? {
 
(: xs:anyURI(concat( 'pid:icltt:', $id)):)
 
(: PID-service :)
    let $pid-service := config:param-value($config-map, 'pid-service'),
        $pid-resolver := config:param-value($config-map, 'pid-resolver'),
        $username := config:param-value($config-map, 'pid-username'),
        $password := config:param-value($config-map, 'pid-pwd')
        
(:        declare variable $baseurl  := 'http://clarin.aac.ac.at/cr/get/';:)
    let $baseurl  := config:param-value($config-map, 'base-url'),
        $target-url  := concat($baseurl, $id)

    let $auth := concat("Basic ", util:string-to-binary(concat($username, ':', $password)))
    let $headers := <headers><header name="Authorization" value="{$auth}"/>
                    <header name="Content-Type" value="application/json"/> 
                </headers>
  
    let $post-data := concat('[{"type":"URL","parsed_data":"', $url , '"}]')
    let $result := httpclient:post(xs:anyURI($rest), $data, true(), $headers),
    (: fish the new pid out of the html-result:
            <dl class="rackful-object"><dt>location</dt><dd><a href="0000-0000-0028-3">0000-0000-0028-3</a></dd> :)
      $new-pid := $result//xhtml:dl/xhtml:dd/xhtml:a/text()    
    
    return if (exists($new-pid)) then 
                concat($pid-resolver, $new-pid)
              else ()
    
 };
 
 (:~ match resource and metadata 
 based on resource-filename or -id
 
 stub - NOT FINISHED!
 
@param $mode add-only, replace, dry-run 
@prefix for the id
 @return number of processed resources :) 
 declare function resource:mapMD($config-map, $path as xs:string?, $mode as xs:string?, $prefix as xs:string,  $log-doc as node()*) as item()* {
 
 let $resolved-path := if ($path='' or not(exists($path ))) then '/*[@xml:id]' else concat('//', $path) 
 
 let $data-dir := config:param-value($config-map, 'data-dir'),    
     $metadata-path := config:param-value($config-map, 'metadata-path'),
     $resources := util:eval(concat("collection($data-dir)", $resolved-path)),
     $resource-ids := $resources/xs:string(@xml:id), 
     $metadata := collection($metadata-path)
    
   let $result :=count($resources) 
 
    let $map := $metadata/cmd:CMD[.//cmd:ResourceProxy/xs:string(@id)=$resource-ids]/cmd:Header/cmd:MdSelfLink/text()
(:    let $map := $metadata/cmd:CMD//cmd:ResourceProxy/xs:string(@id):)
      		
    return  ($result, $resource-ids, $map)
 
 };
 