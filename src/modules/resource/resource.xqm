xquery version "3.0";

(:~ a module to handle resources and their corresponding metadata

    provide a common getter
    pid-handling
    
    not TESTED yet!
    especially PID-assignement
:)
   
module namespace resource = "http://cr-xq/resource" ;
import module namespace config="http://exist-db.org/xquery/apps/config" at "../../core/config.xqm";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at  "../../core/repo-utils.xqm";
import module namespace httpclient="http://exist-db.org/xquery/httpclient";
import module namespace util="http://exist-db.org/xquery/util";
import module namespace fcs = "http://clarin.eu/fcs/1.0" at "../fcs/fcs.xqm";
import module namespace crday = "http://aac.ac.at/content_repository/data-ay" at "../aqay/crday.xqm";


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
       
    let $sanitized-id := repo-utils:sanitize-name($id),
        $data-dir := config:param-value($config-map, 'data-dir'),
        $data-coll := if ($data-dir eq "" ) then ()
                    else collection($data-dir),
    $resource-by-id := $data-coll//*[@xml:id eq $id],
    $resource := if (exists($resource-by-id)) then $resource-by-id
                 else  if ($data-dir ne  "" ) then
                    if (doc-available(concat($data-dir, '/', $sanitized-id))) then
                            doc(concat($data-dir, '/', $sanitized-id))
                 (: if not resource found, try to get a metadata-record :)
                 else resource:getMD($config-map,$id)
                    else resource:getMD($config-map,$id)
                 
    
    
    return if (exists($resource)) then $resource 
                else <diagnostics><message>Resource unavailable, id: { ($id, ' in ', data-dir) } </message></diagnostics> 

};


(:~ tries to get the metadata-record to a resource, based on ID 
but this is not clean yet 

TODO: make the query  (@xml:id) to use index!

:)
declare function resource:getMD ($config-map, $id as xs:string) {

    let $metadata-dir := config:param-value($config-map, 'metadata-path'),
        $id-cmd := concat($id, '.cmd'),
        $sanitized-id := repo-utils:sanitize-name($id-cmd),
        (: if no metadata-dir specified (or empty) dont search! (otherwise `collection('')`would go through whole db!! :)
        $md-coll := if ($metadata-dir eq "" ) then ()
                    else collection($metadata-dir),
        $md-record-by-id := $md-coll//*[@xml:id = ($id,$id-cmd)],
        (:$md-record := if (exists($md-record-by-id)) then $md-record-by-id 
                 else if (doc-available(concat($metadata-dir, '/', $sanitized-id))) then
                            doc(concat($metadata-dir, '/', $sanitized-id))
                 else ():)
         $md-record := if (exists($md-record-by-id)) then $md-record-by-id 
                        else  if ($metadata-dir ne  "" ) then  
                                    if (doc-available(concat($metadata-dir, '/', $sanitized-id))) then
                                            doc(concat($metadata-dir, '/', $sanitized-id))
                 else ()
                              else ()
    
    return if (exists($md-record)) then $md-record 
                else <diagnostics><message>MD-record unavailable, id: { ($id, ' in ', $metadata-dir) } </message></diagnostics> 

};


(:~ overload function with default format-param = htmlpage:)
(:declare function crday:display-overview($config-path as xs:string) as item()* {
 crday:display-overview($config-path, 'htmlpage')
};:)

declare function resource:display-overview($config) as item()* {
 resource:display-overview($config, '', 'htmlpage')
};


(:~ creates a html-overview of the datasets based on the defined mappings (as linked to from config)

@param config config-object (not map)
@param format [raw, htmlpage, html] - raw: return only the produced table, html* : serialize as html   
@returns a html-table with overview of the datasets
:)
declare function resource:display-overview($config, $x-context as xs:string, $format as xs:string ) as item()* {

(:       let $config := doc($config-path), 
         let $config := repo-utils:config($config-path),:)
(:         let $mappings := doc(repo-utils:config-value($config, 'mappings')),:)
          let $context-mapping := fcs:get-mapping('',$x-context, $config),
          (: if not specific mapping found for given context, use whole mappings-file :)
          $mappings := if ($context-mapping/xs:string(@key) = $x-context) then $context-mapping 
                    else doc(repo-utils:config-value($config, 'mappings')), 
           $baseadminurl := repo-utils:config-value($config, 'admin.url') 

        let $opt := util:declare-option("exist:serialize", "media-type=text/html method=xhtml")
        
let $coll-overview :=  <div id="collections-overview">
                    <h2>Collections overview</h2>
                <table class="show"><tr><th>collection</th><th>path</th><th>file</th><th>resources</th><th colspan="2">base-elem</th>
                            <th>indexes</th><th>struct</th><th>md</th></tr>
           { for $map in $mappings/descendant-or-self::map[@key]
                    let $map-key := $map/xs:string(@key),
                        $map-dbcoll-path := $map/xs:string(@path),
(:                        $map-dbcoll:= if ($map-dbcoll-path ne '' and xmldb:collection-available (($map-dbcoll-path,"")[1])) then collection($map-dbcoll-path) else (),                      :)
                          $map-dbcoll:= repo-utils:context-to-collection($map-key, $config),
                          $resources:= fcs:apply-index($map-dbcoll,'fcs.resource',$map-key,$config),
                          $base-elems:= fcs:apply-index($map-dbcoll,'cql.serverChoice',$map-key,$config),

(:                        $queries-doc-name := crday:check-queries-doc-name($config, $map-key),:)
                        $sturct-doc-name := repo-utils:gen-cache-id("structure", ($map-key,""), xs:string($crday:defaultMaxDepth)),
                        $invoke-href := concat($baseadminurl,'?x-context=', $map-key ,'&amp;action=' ),                        
                        (:$queries := if (repo-utils:is-in-cache($queries-doc-name, $config)) then 
                                                <a href="{concat($invoke-href,'xpath-queryset-view')}" >view</a>                                             
                                              else (),:)                       
                        $structure := if (repo-utils:is-in-cache($sturct-doc-name, $config)) then                                                
                                                <a href="{concat($invoke-href,'ay-xml-view')}" >view</a>                                             
                                              else (),
                        $md := resource:getMD(map { "config" := $config}, $map-key)//cmd:MdSelfLink/text()
                    return <tr>
                        <td>{$map-key}</td>
                        <td>{$map-dbcoll-path}</td>
                        <td align="right">{count($map-dbcoll)}</td>
                        <td align="right"><a href="fcs?x-context={$map-key}&amp;operation=scan&amp;scanClause=fcs.resource&amp;x-format={$format}">{count($resources)}</a></td>
                        <td>{$map/xs:string(@base_elem)}</td>
                        <td>{count($base-elems)}</td>
                        <td align="right"><a href="fcs?x-context={$map-key}&amp;operation=explain&amp;x-format={$format}">{count($map/index)}</a></td>
                        <td>{$structure} [<a href="{concat($invoke-href,'ay-xml-run')}" >run</a>]</td>
                        <td><a href="{$md}">{$md}</a></td>
                        </tr>
                        }
        </table></div>

(:                        <td align="right"><a href="fcs?x-context={$map-key}&amp;operation=explain&amp;x-format={$format}">{count($map/index)}</a></td>
                        <td><a href="{$md}">{$md}</a></td>
                        let $base-elems:= fcs:apply-index($resource,'cql.serverChoice',$x-context,$config)
                                   <td>{count($base-elems)}</td>
:)                
        let $dbcoll := repo-utils:context-to-collection($x-context, $config),
                     $resource-ids:= fcs:apply-index($dbcoll,'fcs.resource',$x-context,$config)
                     
let $resources-overview :=  <div id="resources-overview">
                    <h2>Resources overview</h2>
                <table class="show"><tr><th>resources</th><th>file</th>
                            <th>base-elem</th><th>md-id / md-selflink</th></tr>
           {  
           for $resource-id in $resource-ids
                let $resource := resource:get(map { "config" := $config}, $resource-id),
                    $pid := $resource/xs:string(@cr:pid),
                    $base-elems:= fcs:apply-index($resource,'cql.serverChoice',$x-context,$config),
                        $md := resource:getMD(map { "config" := $config}, $resource-id),
                        $md-id := $md/xs:string(@xml:id),
                        $md-selflink:= $md//cmd:MdSelfLink/text()
                        
                return <tr>
                        <td><a href="get/{$resource-id}?format=html">{$resource-id}</a><br/>
                        <a href="{$pid}">{$pid}</a>
                        </td>
                        <td>{util:document-name($resource)}</td>
                        
                        <td>{count($base-elems)}</td>
                        <td><a href="get/{$md-id}?format=html">{$md-id}</a><br/>
                        <a href="{$md-selflink}">{$md-selflink}</a></td>
                        </tr>
                        }
            
          </table></div>

 let $indexes := distinct-values($mappings//index/xs:string(@key))
 let $indexes-overview := <div><h2>Indexes overview</h2>
                     <table class="show">
                    <tr><th>collection</th>{ for $map in $mappings/descendant-or-self::map[@key]
                                return <th>{ $map/xs:string(@key)} </th>}</tr>
                  <tbody>{
                    for $index in $indexes 
                        (:let $map-key:= $index/parent::map/xs:string(@key),
                          $map-dbcoll:= repo-utils:context-to-collection($map-key, $config),
                          $resources:= fcs:apply-index($map-dbcoll,'fcs.resource',$x-context,$config),

                        $invoke-href := concat($baseadminurl,'?x-context=', $map-key ,'&amp;action=' ):)                        
                        
                    return <tr>
                        <td>{$index}</td>
                        { for $map in $mappings/descendant-or-self::map[@key]
                                let $context-key := $map/xs:string(@key)
                                (: fetch scan from cache - if available :) 
                                let $sanitized-xcontext := repo-utils:sanitize-name($context-key) 
                                let $index-doc-name := repo-utils:gen-cache-id("index", ($sanitized-xcontext, $index, 'text', 1 ))
                                let $index-scan := if (repo-utils:is-in-cache($index-doc-name, $config)) then
                                                            repo-utils:get-from-cache($index-doc-name, $config)
                                                        else ()
                                let $index-size := $index-scan//fcs:countTerms/text()
                                let $context-index := if ($index-size) then $index-size else 'run'
(:                                let $context-index := 'x':)
                                let $href := concat("fcs?operation=scan&amp;scanClause=",$index,"&amp;x-context=",$context-key, "&amp;x-format=", $format)
                                return <td>{if ($map/index[xs:string(@key)=$index]) then <a href="{$href}" >{$context-index}</a> else '' }</td> }
                        </tr>
                        }</tbody>
                 </table>
               </div>

   return ($coll-overview, $resources-overview, $indexes-overview)
       (:return if ($format eq 'raw') then
                   $overview
                else            
                   repo-utils:serialise-as($overview, $format, 'html', $config, ()):)
};


declare function resource:get-fcs-resource-scan($config, $run-flag as xs:boolean, $format as xs:string ) as item()* {

(:$config := doc($config-path),:)
  let $name := repo-utils:gen-cache-id("index", ('', 'fcs.resource', 'text'), xs:string(1)),
    $result := 
    if (repo-utils:is-in-cache($name, $config) and not($run-flag)) then
        repo-utils:get-from-cache($name, $config)
    else
        let $data := resource:gen-fcs-resource-scan($config)
        return repo-utils:store-in-cache($name, $data,$config)
        
  return if ($format eq 'raw') then
            $result
         else            
          repo-utils:serialise-as($result, $format, 'scan', $config, ())    
};

(:~ gen fcs-resource scan out of mappings 
not sure if and where currently used 
:)
declare function resource:gen-fcs-resource-scan($config as node()) as item()* {

       let $mappings := doc(repo-utils:config-value($config, 'mappings'))
           
(:        let $opt := util:declare-option("exist:serialize", "media-type=text/html method=xhtml"):)
        
let $map2terms := for $map in $mappings//map[@key]
                    let $context-key := $map/xs:string(@key),
                        $context-label := if ($map/@label) then $map/xs:string(@label) else $map/xs:string(@key), 
                        $map-dbcoll-path := $map/xs:string(@path),
(:                        $map-dbcoll:= if ($map-dbcoll-path ne '' and xmldb:collection-available (($map-dbcoll-path,"")[1])) then collection($map-dbcoll-path) else (),                      :)
                         $map-dbcoll:= repo-utils:context-to-collection($context-key, $config)                            
                     return <sru:term>
                            <sru:value>{ $context-key }</sru:value>
                            <sru:numberOfRecords>{count($map-dbcoll)}</sru:numberOfRecords>
                            <sru:displayTerm>{$context-label}</sru:displayTerm>                           
                          </sru:term>
    
    let $count-all := count($map2terms)                                        
    return
        <sru:scanResponse xmlns:sru="http://www.loc.gov/zing/srw/" xmlns:fcs="http://clarin.eu/fcs/1.0">
              <sru:version>1.2</sru:version>              
              <sru:terms>              
                {$map2terms }
               </sru:terms>
               <sru:extraResponseData>
                     <fcs:countTerms>{$count-all}</fcs:countTerms>
                 </sru:extraResponseData>
                 <sru:echoedScanRequest>                      
                      <sru:scanClause>fcs.resource</sru:scanClause>
                  </sru:echoedScanRequest>
           </sru:scanResponse>   

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
 