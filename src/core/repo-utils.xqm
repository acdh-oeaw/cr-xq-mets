xquery version "3.0";
module namespace repo-utils = "http://aac.ac.at/content_repository/utils";

import module namespace xdb="http://exist-db.org/xquery/xmldb";
import module namespace diag =  "http://www.loc.gov/zing/srw/diagnostic/" at  "../modules/diagnostics/diagnostics.xqm";
import module namespace request="http://exist-db.org/xquery/request";

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

declare function repo-utils:config($config-file as xs:string) as node()* {
let $sys-config := if (doc-available($repo-utils:sys-config-file)) then doc($repo-utils:sys-config-file) else (),
    $config := if (doc-available($config-file)) then (doc($config-file), $sys-config) 
                        else diag:diagnostics("general-error", concat("config not available: ", $config-file))
    return $config
};

declare function repo-utils:config-value($config, $key as xs:string) as xs:string? {
    ($config/config[not(xs:string(@type)='system' or xs:string(@type)='module')]//(param|property)[xs:string(@key)=$key],
      $config/config[xs:string(@type)='module']//(param|property)[xs:string(@key)=$key],
      $config/config[xs:string(@type)='system']//(param|property)[xs:string(@key)=$key],
      $config//(param|property)[xs:string(@key)=$key]  (: accept also top-level param|property :)
      )[1]
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
    return if ($param) then $param else $config//(param|property)[@key=$key]
};

(:~ returns db-collection (as nodeset) based on the identifier in x-context, looked up in the mapping or default collection as defined in config 

@returns nodeset of given context 
 if no x-context match or no context provided returns default collection from the config (data.path ) 
 (if available, otherwise again empty result)

WATCHME: changed to lax handling of the context (if no match - go to default)
        gives better recall, but may confuse - alternatively: strict: empty result if x-context does not match 
TODO: accept $x-context as xs:string*
:)
declare function repo-utils:context-to-collection($x-context as xs:string, $config) as node()* {
(:      let $mappings := doc(repo-utils:config-value($config, 'mappings')):)
      let $dbcoll-path := repo-utils:context-to-collection-path($x-context, $config)
    return if ($dbcoll-path eq "" ) then ()
                else collection($dbcoll-path)                    
};

(:~ returns path to db-collection (as nodeset) based on the identifier in x-context, 
looked up in the mapping or default data.path as defined in config

@returns dbcoll-path of given context
 if no x-context match or no context provided returns default collection from the config (data.path ) 
 (if available, otherwise again empty result)

WATCHME: changed to lax handling of the context (if no match - go to default)
        gives better recall, but may confuse - alternatively: strict: empty result if x-context does not match
changed again: only give default if x-context is empty string or 'default'-string.        
T
:)
declare function repo-utils:context-to-collection-path($x-context as xs:string, $config) as xs:string {
      let $mappings:= doc(repo-utils:config-value($config, 'mappings'))
    return    (: if ($x-context) then :) 
            if (exists($mappings//map[xs:string(@key) eq $x-context]/@path)) then 
                    $mappings//map[xs:string(@key) eq $x-context]/xs:string(@path)
                (: else "" :)
                  else if (exists(repo-utils:config-value($config, 'data.path')) and 
                            ($x-context = ('', 'default'))) then  
                        repo-utils:config-value($config, 'data.path')
                  else ""
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
    
    return 
        try {
           if (doc-available($path)) then
            fn:doc($path)
            else ()
        } catch * {         
           if (util:binary-doc-available($path)) then
                util:binary-doc($path)
           else ()
        }
};

(:~ Store the data in cache. Uses own writer-account
:)
declare function repo-utils:store-in-cache($doc-name as xs:string, $data as node(),$config) as item()* {
  
  let $clarin-writer := fn:doc(repo-utils:config-value($config, 'writer.file')),
  $cache-path := repo-utils:config-value($config, 'cache.path'),
  $dummy := xdb:login($cache-path, $clarin-writer//write-user/text(), $clarin-writer//write-user-cred/text()),
  $store := (: util:catch("org.exist.xquery.XPathException", :) xdb:store($cache-path, $doc-name, $data), (: , ()) :)
  $stored-doc := if ( util:is-binary-doc(concat($cache-path, "/", $doc-name))) then util:binary-doc(concat($cache-path, "/", $doc-name))
                        else fn:doc(concat($cache-path, "/", $doc-name))
  return $stored-doc
(:  ():)
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

(:~ transform result to HTML, JSON, or leave as XML - according to format parameter

@param $parameters optional additional parameters to be passed to xsl  
:)
declare function repo-utils:serialise-as($item as node()?, $format as xs:string, $operation as xs:string, $config, $parameters as node()* ) as item()? {        
        if ($format eq $repo-utils:responseFormatJSon) then
	       
	       let $xslDoc := repo-utils:xsl-doc($operation, $format, $config )
	       let $res := if ($xslDoc) then
	                           let $option := util:declare-option("exist:serialize", "method=text media-type=application/json")
	                           return       transform:transform($item,$xslDoc, 
                                 			<parameters><param name="format" value="{$format}"/>
                                 			            <param name="x-context" value="{repo-utils:param-value($config, 'x-context', '' )}"/>
                                 			            <param name="base_url" value="{repo-utils:base-url($config)}"/>
                                 			            <param name="mappings-file" value="{repo-utils:config-value($config, 'mappings')}"/>
                                 			            <param name="scripts_url" value="{repo-utils:config-value($config, 'scripts.url')}"/>
                                 			             <param name="site_name" value="{repo-utils:config-value($config, 'site.name')}"/>
                                 			             <param name="site_logo" value="{repo-utils:config-value($config, 'site.logo')}"/>
                                 			             {$parameters/param}
                                 			</parameters>)
                            else 
                                let $option := util:declare-option("exist:serialize", "method=json media-type=application/json")    
                                return $item
	       return $res
	    else if (contains($format, $repo-utils:responseFormatHTML)) then
	           let $xslDoc := repo-utils:xsl-doc($operation, $format, $config )
	           let $res := if (exists($xslDoc)) then transform:transform($item,$xslDoc, 
              			<parameters><param name="format" value="{$format}"/>
              			           <param name="operation" value="{$operation}"/>
              			            <param name="x-context" value="{repo-utils:param-value($config, 'x-context', '' )}"/>
              			            <param name="base_url" value="{repo-utils:base-url($config)}"/>
              			            <param name="mappings-file" value="{repo-utils:config-value($config, 'mappings')}"/>
              			            <param name="scripts_url" value="{repo-utils:config-value($config, 'scripts.url')}"/>
              			             <param name="site_name" value="{repo-utils:config-value($config, 'site.name')}"/>
              			             <param name="site_logo" value="{repo-utils:config-value($config, 'site.logo')}"/>
              			             {$parameters/param}
              			</parameters>)          
              		        else diag:diagnostics("unsupported-param-value",concat('$operation: ', $operation, ', $format: ', $format))
(:               let $option := util:declare-option("exist:serialize", "method=xml media-type=text/html"):)
let $option := util:declare-option("exist:serialize", "method=xhtml media-type=text/html")
	           return $res
	   else
	       let $option := util:declare-option("exist:serialize", "method=xml media-type=application/xml")
	    return $item
};
(: $repo-utils:responseFormatXml, $repo-utils:responseFormatText:)	     
       
	    (:let $option := 
	              if (contains($format, $repo-utils:responseFormatHTML)) then
	                  util:declare-option("exist:serialize", "method=xml media-type=text/xhtml")
	              else 
    	              util:declare-option("exist:serialize", "method=xml media-type=application/xml")
:)


(:~ get appropriate xsl-stylesheet (based on operation and format);
(handles multiple scripts-paths from config)
preference for a specific for operation-format, 
default: operation :)
declare function repo-utils:xsl-doc($operation as xs:string, $format as xs:string, $config) as item()? {        
(:    let $scripts-path := repo-utils:config-value($config, 'scripts.path'),:)
    let $scripts-paths := repo-utils:config-values($config, 'scripts.path'),
    
        $xsldoc := (for $scripts-path in $scripts-paths
                      return if (doc-available(concat($scripts-path, repo-utils:config-value($config, concat($operation, '-', $format, ".xsl"))))) then
                          doc(concat($scripts-path, repo-utils:config-value($config, concat($operation, '-', $format, ".xsl"))))
                      else if (doc-available(concat($scripts-path, repo-utils:config-value($config, concat($operation, ".xsl"))))) then
                            doc (concat($scripts-path, repo-utils:config-value($config, concat($operation, ".xsl"))))
                       else ()
                      )[1]
        return $xsldoc
};
	          	(: $item :)

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


(: Helper function to recursively create a collection hierarchy. :)
declare function repo-utils:mkcol($collection, $path) {
    local:mkcol-recursive($collection, tokenize($path, "/"))
};

declare function local:mkcol-recursive($collection, $components) {
    if (exists($components)) then
        let $newColl := concat($collection, "/", $components[1])
        return (
            xdb:create-collection($collection, $components[1]),
            local:mkcol-recursive($newColl, subsequence($components, 2))
        )
    else
        ()
};



(:
testing when trying to log import 2012-10-24 - not used
declare function repo-utils:write-log ($action as xs:string, $dataset as xs:string) {

			let $log-doc := repo-utils:config 
			let $data := <log timestamp="{$timestamp}">{current-dateTime()}
			             </log>
			  return	xmldb:store($data-path, "test.log", $data )
			  
	let $time := util:system-dateTime()	
    let $upd-dummy :=  
        update insert <xpath key="{$xpath/@key}" label="{$xpath/@label}" dur="{$duration}">{$answer}</xpath> into $result-doc/result

    return $result-doc
			  
};:)