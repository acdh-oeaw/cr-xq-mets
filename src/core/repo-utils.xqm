xquery version "3.0";
module namespace repo-utils = "http://aac.ac.at/content_repository/utils";
declare namespace mets="http://www.loc.gov/METS/";
declare namespace xlink="http://www.w3.org/1999/xlink";
declare namespace fcs = "http://clarin.eu/fcs/1.0";
declare namespace cr="http://aac.ac.at/content_repository";



import module namespace xdb="http://exist-db.org/xquery/xmldb";
import module namespace diag =  "http://www.loc.gov/zing/srw/diagnostic/" at  "../modules/diagnostics/diagnostics.xqm";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace project="http://aac.ac.at/content_repository/project" at "project.xqm";
import module namespace resource="http://aac.ac.at/content_repository/resource" at "resource.xqm";

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
(:~ HELPER functions - configuration, caching, data-access
:)

(:
: this all cannot be defined as global variable, because we want different configurations,
: thus the $config has to be sent as param everywhere
: declare variable $repo-utils:config := doc("config.xml");
: declare variable $repo-utils:mappings := doc(repo-utils:config-value('mappings'));
: declare variable $repo-utils:data-collection := collection(repo-utils:config-value('data.path'));
: declare variable $repo-utils:md-collection := collection(repo-utils:config-value('metadata.path'));
: declare variable $repo-utils:cachePath as xs:string := repo-utils:config-value('cache.path');
:)

declare variable $repo-utils:xmlExt as xs:string := ".xml";
declare variable $repo-utils:responseFormatXml as xs:string := "xml";
declare variable $repo-utils:responseFormatJSon as xs:string := "json";
declare variable $repo-utils:responseFormatText as xs:string := "text";
declare variable $repo-utils:responseFormatHTML as xs:string := "html";
declare variable $repo-utils:responseFormatHTMLpage as xs:string := "htmlpage";

declare variable $repo-utils:sys-config-file := "conf/config-system.xml";

(:~ not solved yet - look at cr-xq/core/config.xqm: config:param-value('base-url') !  :)
declare function repo-utils:base-url($config as item()*) as xs:string* {
    (:let $server-base := if (repo-utils:config-value($config, 'server.base') = '') then ''  else repo-utils:config-value($config, 'server.base')
    let $config-base-url := if (repo-utils:config-value($config, 'base.url') = '') then request:get-uri() else repo-utils:config-value($config, 'base.url')
    return concat($server-base, $config-base-url):)
(:    let $url := request:get-url():)
let $url := request:get-uri()
    return $url
};  


(:~
 : Helper function which programmatically defines prefix-namespace-bindings 
 : in a project map.
 : 
 : @param $config: the config of the current project.
~:)
declare function repo-utils:declare-namespaces($config as item()*) as empty() {
    let $mappings:=config:mappings($config),
        $namespaces:=$mappings//namespaces
    return 
        for $ns in $namespaces/ns
        let $prefix:=$ns/@prefix,
            $namespace-uri:=$ns/@uri
        let $log:=util:log("INFO", "declaring namespace "||$prefix||"='"||$namespace-uri||"'")
        return util:declare-namespace(xs:string($prefix), xs:anyURI($namespace-uri))
};

declare function repo-utils:config($config-file as xs:string) as node()* {
let $sys-config := if (doc-available($repo-utils:sys-config-file)) then doc($repo-utils:sys-config-file) else (),
    $config := if (doc-available($config-file)) then (doc($config-file), $sys-config) 
                        else diag:diagnostics("general-error", concat("config not available: ", $config-file))
    return $config
};

declare function repo-utils:config-value($config, $key as xs:string) as xs:string? {
    let $project-config:=$config/config[not(xs:string(@type)='system' or xs:string(@type)='module')]//(param|property)[xs:string(@key)=$key],
        $module-config:=$config/config[xs:string(@type)='module']//(param|property)[xs:string(@key)=$key],
        $system-config:=$config/config[xs:string(@type)='system']//(param|property)[xs:string(@key)=$key],
        $top-level-config:=$config//(param|property)[xs:string(@key)=$key]
    return ($project-config,$module-config,$system-config,$top-level-config)[1]
};

declare function repo-utils:config-values($config, $key as xs:string) as xs:string* {
    ($config/config[not(xs:string(@type)='system' or xs:string(@type)='module')]//(param|property)[xs:string(@key)=$key],
      $config/config[xs:string(@type)='module']//(param|property)[xs:string(@key)=$key],
      $config/config[xs:string(@type)='system']//(param|property)[xs:string(@key)=$key],
      $config//(param|property)[xs:string(@key)=$key]  (: accept also top-level param|property :)
      )
};

(:declare function repo-utils:config-value($config, $key as xs:string) as xs:string* {
    ($config[not(@type='system')]//(param|property)[@key=$key], $config[@type='system']//property[@key=$key])[1]
};
:)
(:~ Get value of a param based on a key, from config or from request-param (precedence) :)
declare function repo-utils:param-value($config, $key as xs:string, $default as xs:string) as xs:string* {
    let $param := request:get-parameter($key, $default)
    return 
        if ($param) 
        then $param 
        else $config//(param|property)[@key=$key]
};

(:~ This function returns a node set consisting of all available documents of the project as listed in mets:fileGrp[@USE="Project Data"]     
 : 
 : @param $project-pid: The CR-Context
 : @param $config: The mets-config of the project
~:)
declare function repo-utils:context-to-collection($project-pid as xs:string, $config) as node()* {
    let $dbcoll-path := repo-utils:context-to-collection-path($project-pid, $config)
    let $docs:= 
        if ($dbcoll-path = "" ) then ()
        else
            for $p in $dbcoll-path
            return
                if (ends-with($p,'.xml'))
                then doc($p)
                else ()
     return ($docs)
};

(:~ This function returns paths to all available data files of the given project.  
 :
 : @param $project-pid: The CR-Context
 : @param $config: The mets-config of the project
~:)
declare function repo-utils:context-to-collection-path($project-pid as xs:string, $config) as xs:string* {
    let $projectData:=$config//mets:fileGrp[@USE="Project Data"]//mets:file/mets:FLocat
    return 
        for $d in $projectData/@xlink:href return
            if (doc-available($d)) 
            then xs:string($d)
            else ()
};
(:~
 : Retrieves the id of the resourcefragment(s) a given element is part of.
 : 
 : @param $resource-pid: the PID of the resource to be looked into
 : @param $x-elementID: the internal cr:id of the element to be looked up
 : @param $project-pid: the context/project
 : @param $config: the mets-config of the project 
 : @return one or more resourcefragment-pids 
~:)
declare function repo-utils:element-pid-to-resourcefragment-pid($resource-pid as xs:string, $x-element-pid as xs:string, $project-pid as xs:string, $config) as xs:string* {
    let $tables-path:=$config//param[@key='lookuptable.path']/xs:string(.)
    let $lookup-table:=repo-utils:get-from-cache($project-pid||"-"||$resource-pid||".xml",$tables-path,$config)
    let $fragments:=$lookup-table//fcs:ResourceFragment[cr:id=$x-element-pid]
    return $fragments/xs:string(@pid)
};
(:
(\:~ This function returns paths to all available resources of the given project by looking at the 
 : projects struct map.
 : 
 : a resource may consist of 
 :      - a single xml instance 
 :      - multiple fragment instances, which constitute the resource in sum
 : 
 : Here we only sum up only the the _full_ resources.  
 :
 : @param $project-pid: The CR-Context
 : @param $config: The mets-config of the project
 : @return 
~:\)
declare function repo-utils:resources-in-project($project-pid as xs:string, $config)  {
    let $projectResources:=project:resources($config//mets:mets)
    return 
    for $d in $projectResources return
        if ($d/mets:fptr/@FILEID) 
        then 
            let $resource-pid := xs:string($d/@ID) 
            let $fileID:=xs:string($d/mets:fptr/@FILEID)
            let $file:=$config//mets:file[@ID eq $fileID]
            return 
                if (doc-available($file/mets:FLocat/@xlink:href))
                then 
                    map{
                        "resource-pid" := $resource-pid,
                        "content" := doc($file/mets:FLocat/@xlink:href)
                    }
                else util:log("INFO","document "||$file||" not available")
        else ()
};:)

declare function repo-utils:fileuri-to-resource-pid($filepath as xs:string, $project-pid as xs:string, $config) as xs:string? {
    let $fileID:=$config//mets:file[mets:FLocat/@xlink:href eq $filepath]/@ID
    return $config//mets:div[@TYPE='resource' and mets:fptr/@FILEID eq $fileID]/xs:string(@ID) 
};

(:~ Get the resource by PID/handle/URL or some known identifier.
  TODO: NOT ADAPTED YET! (taken from CMD)
  TODO: be clear about resource itself and metadata-record!
:)
(:declare function repo-utils:get-resource-by-id($id as xs:string) as node()* {
  let $collection := collection($cr:dataPath)
  return 
    if ($id eq "" or $id eq $cr:collectionRoot) then
    $collection//IsPartOf[. = $cr:collectionRoot]/ancestor::CMD
  else
    util:eval(concat("$collection/ft:query(descendant::MdSelfLink, <term>", xdb:decode($id), "</term>)/ancestor::CMD"))
 (\: $collection/descendant::MdSelfLink[. = xdb:decode($id)]/ancestor::CMD :\)
};
:)

(:~ Checks whether the document is available or not.
  generic, currently not used
:)
declare function repo-utils:is-doc-available($collection as xs:string, $doc-name as xs:string) as xs:boolean {
  fn:doc-available(fn:concat($collection, "/", $doc-name))
};

declare function repo-utils:is-in-cache($doc-name as xs:string,$config) as xs:boolean {
  fn:doc-available(fn:concat(repo-utils:config-value($config, 'cache.path'), "/", $doc-name))
};


declare function repo-utils:get-from-cache($doc-name as xs:string,$config) as item()* {
    let $path := fn:concat(repo-utils:config-value($config, 'cache.path'), "/", $doc-name)
    return repo-utils:get-from-cache($doc-name, $path,$config)
};

declare function repo-utils:get-from-cache($doc-name as xs:string,$path,$config) as item()* {
    if (util:is-binary-doc($path))
    then util:binary-doc($path)
    else fn:doc($path)
};

(:~ 
 : Store the data in Cache, which is set in the parameter "cache.path" in the config. 
 : The function uses its own writer-account. 
 :  
 : @param $doc-name: the filename of the resource to create/update.
 : @param $data: the data to store
 : @param $config: the config for the current project  
~:)
declare function repo-utils:store-in-cache($doc-name as xs:string, $data as node(),$config) as item()* {
  repo-utils:store-in-cache($doc-name,$data,repo-utils:config-value($config, 'cache.path'))
};

(:~ 
 : Store the data in Cache to the specified collection. 
 : The function uses its own writer-account. 
 :  
 : @param $doc-name: the filename of the resource to create/update.
 : @param $cache-collection: the name of the collection (non-existent collections will be created)
 : @param $data: the data to store
 : @param $config: the config for the current project  
~:)
declare function repo-utils:store-in-cache($doc-name as xs:string, $cache-path as xs:string, $data as node(),$config) as item()* {
  let   $clarin-writer := fn:doc(repo-utils:config-value($config, 'writer.file')),
        $dummy := xdb:login($cache-path, $clarin-writer//write-user/text(), $clarin-writer//write-user-cred/text()),
        $mkcol :=   if (xmldb:collection-available($cache-path))
                    then ()
                    else local:mkcol-recursive(tokenize($cache-path,'/')[1],tokenize($cache-path,'/')[position() gt 1]),
        $store := xdb:store($cache-path, $doc-name, $data), 
        $stored-doc := 
            if (util:is-binary-doc(concat($cache-path, "/", $doc-name))) 
            then util:binary-doc(concat($cache-path, "/", $doc-name))
            else fn:doc(concat($cache-path, "/", $doc-name))
  return $stored-doc
};


(: 
this tries to create sub-collections in index for
individual data-collection - but it makes the retrieval etc. also more complicated 
so rather encoding the data-collection also in the name  

declare function repo-utils:store-in-cache($data-collection as item(), $doc-name as xs:string, $data as node()) as item()* {
    let $data-coll-name := collection-name($data-collection) 
    let $index-coll-path := concat($repo-utils:cachePath, "/", $data-coll-name )
   let $create-coll := if (not(xmldb:collection-available($index-coll-path ))) then 
                           xmldb:create-collection($repo-utils:cachePath, $data-collname) else ()
  let $store-result := repo-utils:store($index-coll-path, $doc-name, $data, true())

return $store-result
};
:)

(:~ Store the data somewhere (in $collection)
checks for logged in user and only tries to use the internal writer, if no user logged in.
:)
(:<options><option key="update">yes</option></options>:)
declare function repo-utils:store($collection as xs:string, $doc-name as xs:string, $data as node(), $overwrite as xs:boolean, $config) as item()* {
  let $writer := fn:doc(repo-utils:config-value($config, 'writer.file')),
  $dummy := if (request:get-attribute("org.exist.demo.login.user")='') then
                xdb:login($collection, $writer//write-user/text(), $writer//write-user-cred/text())
             else ()  

(:  let $rem := if ($overwrite and doc-available(concat($collection, $doc-name))) then xdb:remove($collection, $doc-name) else () :)

let $rem :=if (util:is-binary-doc(concat($collection, $doc-name)) and $overwrite) then
                        xdb:remove($collection, $doc-name)
                      else if ($overwrite and doc-available(concat($collection, $doc-name))) 
                        then xdb:remove($collection, $doc-name)  
                        else ()
  
  
  let $store := (: util:catch("org.exist.xquery.XPathException", :) xdb:store($collection, $doc-name, $data),  
  $stored-doc := if (util:is-binary-doc(concat($collection, "/", $doc-name))) then  util:binary-doc(concat($collection, "/", $doc-name)) else fn:doc(concat($collection, "/", $doc-name))
  return $stored-doc
  
};


declare function repo-utils:gen-cache-id($type-name as xs:string, $keys as xs:string+, $depth as xs:string) as xs:string {   
    repo-utils:gen-cache-id($type-name , ($keys, $depth) )
};  
(:~ Create document name with md5-hash for selected collections (or types) for reuse.
:)
declare function repo-utils:gen-cache-id($type-name as xs:string, $keys as xs:string+) as xs:string {  
       let $sanitized-names := for $key in $keys return repo-utils:sanitize-name($key)
    return
(:    fn:concat($name-prefix, "-", util:hash(string-join($sorted-names, ""), "MD5"), $repo-utils:xmlExt):)
    fn:concat($type-name, "-", string-join($sanitized-names, "-"), $repo-utils:xmlExt)
};

(:~ wipes out problematic characters from names
:)
declare function repo-utils:sanitize-name($name as xs:string) as xs:string {
    translate($name, ":/",'_')
};

declare function repo-utils:serialise-as($item as node()?, $format as xs:string, $operation as xs:string, $config) as item()? {
    repo-utils:serialise-as($item, $format, $operation, $config, ())
};

(:~ 
 : Generic formating function which transforms results into the following formats, according to the function's 2nd parameter.
 :
 : Currently implemented formats are: 
 : <ul>
 :  <li>JSON</li>
 :  <li>HTML (fragment or full page)</li>
 :  <li>XML (default)</li>
 : </ul>
 : 
 : Possible names for each format are defined in the following module variables:
 : @see $repo-utils:responseFormatXml
 : @see $repo-utils:responseFormatJSon
 : @see $repo-utils:responseFormatText
 : @see $repo-utils:responseFormatHTML
 : @see $repo-utils:responseFormatHTMLpage
 : 
 : @param $item the data to be output
 : @param $format the output format  
 : @param $parameters optional additional parameters to be passed to xsl  
~:)
declare function repo-utils:serialise-as($item as node()?, $format as xs:string, $operation as xs:string, $config, $parameters as node()* ) as item()? {
    switch(true())
        case ($format eq $repo-utils:responseFormatJSon) return	       
	       let $xslDoc := repo-utils:xsl-doc($operation, $format, $config),
	           $xslParams:=    <parameters>
	                               <param name="format" value="{$format}"/>
	                               <param name="x-context" value="{repo-utils:param-value($config, 'x-context', '' )}"/>
	                               <param name="base_url" value="{repo-utils:base-url($config)}"/>
	                               <param name="mappings-file" value="{repo-utils:config-value($config, 'mappings')}"/>
	                               <param name="scripts_url" value="{repo-utils:config-value($config, 'scripts.url')}"/>
	                               <param name="site_name" value="{repo-utils:config-value($config, 'site.name')}"/>
	                               <param name="site_logo" value="{repo-utils:config-value($config, 'site.logo')}"/>
	                               {$parameters/param}
	                           </parameters>
	       let $res := if ($xslDoc) 
	                   then
	                       let $option := util:declare-option("exist:serialize", "method=text media-type=application/json")
	                       return transform:transform($item,$xslDoc,$xslParams)
                       else 
                           let $option := util:declare-option("exist:serialize", "method=json media-type=application/json")    
                           return $item
	       return $res
	    case (contains($format, $repo-utils:responseFormatHTML)) return
	       let $xslDoc :=      repo-utils:xsl-doc($operation, $format, $config),
	           $xslParams:=    <parameters>
	                               <param name="format" value="{$format}"/>
              			           <param name="operation" value="{$operation}"/>
              			           <param name="x-context" value="{repo-utils:param-value($config, 'x-context', '' )}"/>
              			           <param name="base_url" value="{repo-utils:base-url($config)}"/>
              			           <param name="mappings-file" value="{repo-utils:config-value($config, 'mappings')}"/>
              			           <param name="scripts_url" value="{repo-utils:config-value($config, 'scripts.url')}"/>
              			           <param name="site_name" value="{repo-utils:config-value($config, 'site.name')}"/>
              			           <param name="site_logo" value="{repo-utils:config-value($config, 'site.logo')}"/>
              			           {$parameters/param}
              			       </parameters>
	       let $res := if (exists($xslDoc)) 
	                   then transform:transform($item,$xslDoc, $xslParams)
	                   else 
	                       let $log:=util:log("ERROR", "repo-utils:serialise-as() could not find stylesheet '"||$xslDoc||"' for $operation: "||$operation||", $format: "||$format||".")
	                       return diag:diagnostics("unsupported-param-value",concat('$operation: ', $operation, ', $format: ', $format))
	       let $option := util:declare-option("exist:serialize", "method=xhtml media-type=text/html")
	       return $res
	   default return
	       let $option := util:declare-option("exist:serialize", "method=xml media-type=application/xml")
	       return $item
};


(:~
 : Getter function for output formatting stylesheets: returns an document node() with the appropriate stylesheet
 : given the current operation ($operation) and the desired output format ($format).
 : 
 : It tries to determine the best fitting XSL file by looking in any db collection mentioned 
 : in any <code>param key='scripts.path'</code> in $config (this includes project configs as well as module configs). 
 : In there tries to fetch files witch are mentioned in any config param named  
 : <ul>
 :      <li>'$operation-$format.xsl' or </li>
 :      <li>'$operation.xsl' or </li>
 : <ul>
 : 
 : It returns the <b>first</b> document in the resulting sequence.
 :
 :  
 : @param $operation the operation which produced the result to be output. (no restriction)
 : @param $format the name of the desired output format
 : @param $config the global configuration map.
 : @return zero or one XSL documents 
~:)
declare function repo-utils:xsl-doc($operation as xs:string, $format as xs:string, $config) as document-node()? {        
    let $scripts-paths := repo-utils:config-values($config, 'scripts.path'),
        $xsldoc :=  for $scripts-path in $scripts-paths
                    return 
                        let $operation-format-xsl:= $scripts-path||repo-utils:config-value($config, $operation||'-'||$format||".xsl"),
                            $operation-xsl:= $scripts-path||repo-utils:config-value($config, $operation||".xsl")
                        return 
                        switch(true())
                            case (doc-available($operation-format-xsl)) return doc($operation-format-xsl)
                            case (doc-available($operation-xsl)) return doc($operation-xsl)
                            default return ()
    return ($xsldoc)[1]
};

(:~ helper function. Performs multiple replacements, using pairs of replace parameters. based on standard xpath2 function replace() 
taken from: http://www.xqueryfunctions.com/xq/functx_replace-multi.html
:)
declare function repo-utils:replace-multi   ( $arg as xs:string? ,    $changeFrom as xs:string* ,    $changeTo as xs:string* )  as xs:string? {
       
   if (count($changeFrom) > 0)
   then repo-utils:replace-multi(
          replace($arg, $changeFrom[1],
                  repo-utils:if-absent($changeTo[1],'')),
          $changeFrom[position() > 1],
          $changeTo[position() > 1])
   else $arg
 } ;
 
 (:~ used by replace-multi()
taken from: http://www.xqueryfunctions.com/xq/functx_if-absent.html
:)
declare function repo-utils:if-absent ( $arg as item()* , $value as item()* )  as item()* {
    if (exists($arg)) then $arg else $value
 } ;


(: Helper function to recursively create a collection hierarchy. 
xmldb:create-collection actually obviously can do this - no need for recursive call (anymore?) :)
declare function repo-utils:mkcol($collection as xs:string, $path as xs:string) {
   xmldb:create-collection($collection, $path)
(:    local:mkcol-recursive($collection, tokenize($path, "/")):)
};

(:~
OBSOLETED by xmldb:create-collection()
:)
declare function local:mkcol-recursive($collection, $components) {
    if (exists($components) and exists($collection)) 
    then
        let $newColl := concat($collection, "/", $components[1])
        return (
            xdb:create-collection($collection, $components[1]),
            local:mkcol-recursive($newColl, subsequence($components, 2))
        )
    else ()
};