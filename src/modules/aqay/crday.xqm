module namespace crday  = "http://aac.ac.at/content_repository/data-ay";

import module namespace repo-utils =  "http://aac.ac.at/content_repository/utils" at  "../../core/repo-utils.xqm";
import module namespace diag =  "http://www.loc.gov/zing/srw/diagnostic/" at  "../diagnostics/diagnostics.xqm";
import module namespace fcs = "http://clarin.eu/fcs/1.0" at "../fcs/fcs.xqm";

import module namespace xdb="http://exist-db.org/xquery/xmldb";
(:import module namespace diag =  "http://www.loc.gov/zing/srw/diagnostic/" at  "modules/diagnostics/diagnostics.xqm";
import module namespace util="http://exist-db.org/xquery/util";
import module namespace kwic="http://exist-db.org/xquery/kwic";
:)
declare namespace sru = "http://www.loc.gov/zing/srw/";
(:declare namespace fcs = "http://clarin.eu/fcs/1.0";:)
declare namespace cmd = "http://www.clarin.eu/cmd/";
(:declare namespace tei = "http://www.tei-c.org/ns/1.0";:)

declare variable $crday:docTypeTerms := "Terms";
declare variable $crday:defaultMaxDepth:= 8;
(: just analyze a subsequence of: :)
declare variable $crday:maxAyRecords:= 1000;  
declare variable $crday:restrictAyRecordsSize:= true();


(:~ overload function with default format-param = htmlpage:)
(:declare function crday:display-overview($config-path as xs:string) as item()* {
 crday:display-overview($config-path, 'htmlpage')
};:)

declare function crday:display-overview($config) as item()* {
 crday:display-overview($config, '', 'htmlpage')
};


(:~ creates a html-overview of the datasets based on the defined mappings (as linked to from config)

@param config-path path to the confing-file
@param format [raw, htmlpage, html] - raw: return only the produced table, html* : serialize as html   
@returns a html-table with overview of the datasets
:)
declare function crday:display-overview($config, $x-context as xs:string, $format as xs:string ) as item()* {

(:       let $config := doc($config-path), 
         let $config := repo-utils:config($config-path),:)
(:         let $mappings := doc(repo-utils:config-value($config, 'mappings')),:)
          let $context-mapping := fcs:get-mapping('',$x-context, $config),
          (: if not specific mapping found for given context, use whole mappings-file :)
          $mappings := if ($context-mapping/xs:string(@key) = $x-context) then $context-mapping 
                    else doc(repo-utils:config-value($config, 'mappings')), 
           $baseadminurl := repo-utils:config-value($config, 'admin.url') 

        let $opt := util:declare-option("exist:serialize", "media-type=text/html method=xhtml")
        
let $overview :=  <div id="resources-overview">
                    <h2>Project overview - resources</h2>
                <table class="show"><tr><th>collection</th><th>path</th><th>file</th><th>resources</th><th>base-elem</th><th>indexes</th><th>tests</th><th>struct</th></tr>
           { for $map in $mappings/descendant-or-self::map[@key]
                    let $map-key := $map/xs:string(@key),
                        $map-dbcoll-path := $map/xs:string(@path),
(:                        $map-dbcoll:= if ($map-dbcoll-path ne '' and xmldb:collection-available (($map-dbcoll-path,"")[1])) then collection($map-dbcoll-path) else (),                      :)
                          $map-dbcoll:= repo-utils:context-to-collection($map-key, $config),
                          $resources:= fcs:apply-index($map-dbcoll,'fcs.resource',$x-context,$config),

                        $queries-doc-name := crday:check-queries-doc-name($config, $map-key),
                        $sturct-doc-name := repo-utils:gen-cache-id("structure", ($map-key,""), xs:string($crday:defaultMaxDepth)),
                        $invoke-href := concat($baseadminurl,'?x-context=', $map-key ,'&amp;action=' ),                        
                        $queries := if (repo-utils:is-in-cache($queries-doc-name, $config)) then 
                                                <a href="{concat($invoke-href,'xpath-queryset-view')}" >view</a>                                             
                                              else (),                       
                        $structure := if (repo-utils:is-in-cache($sturct-doc-name, $config)) then                                                
                                                <a href="{concat($invoke-href,'ay-xml-view')}" >view</a>                                             
                                              else ()
                    return <tr>
                        <td>{$map-key}</td>
                        <td>{$map-dbcoll-path}</td>
                        <td align="right">{count($map-dbcoll)}</td>
                        <td align="right">{count($resources)}</td>
                        <td>{$map/xs:string(@base_elem)}</td>
                        <td align="right"><a href="fcs?x-context={$map-key}&amp;operation=explain">{count($map/index)}</a></td>                        
                        <td>{$queries} [<a href="{concat($invoke-href,'xpath-queryset-run')}" >run</a>]</td>                        
                        <td>{$structure} [<a href="{concat($invoke-href,'ay-xml-run')}" >run</a>]</td>
                        </tr>
                        }
        </table></div>

            (: <th>ns</th><th>root-elem</th>
            $root-elems := for $elem in distinct-values($map-dbcoll/*/name()) return $elem,
            $ns-uris := for $ns in distinct-values($map-dbcoll/namespace-uri(*)) return $ns,
                        <td>{$ns-uris}</td>
                        <td>{$root-elems}</td>:)
 
 let $indexes := distinct-values($mappings//index/xs:string(@key))
 let $indexes-overview := <div><h2>Project overview - indexes</h2>
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
                                let $context-index := 'x' 
                                return <td>{if ($map/index[xs:string(@key)=$index]) then $context-index else '' }</td> }
                        </tr>
                        }</tbody>
                 </table>
               </div>

   return ($overview, $indexes-overview)
       (:return if ($format eq 'raw') then
                   $overview
                else            
                   repo-utils:serialise-as($overview, $format, 'html', $config, ()):)
};


declare function crday:get-fcs-resource-scan($config, $run-flag as xs:boolean, $format as xs:string ) as item()* {

(:$config := doc($config-path),:)
  let $name := repo-utils:gen-cache-id("index", ('', 'fcs.resource', 'text'), xs:string(1)),
    $result := 
    if (repo-utils:is-in-cache($name, $config) and not($run-flag)) then
        repo-utils:get-from-cache($name, $config)
    else
        let $data := crday:gen-fcs-resource-scan($config)
        return repo-utils:store-in-cache($name, $data,$config)
        
  return if ($format eq 'raw') then
            $result
         else            
          repo-utils:serialise-as($result, $format, 'scan', $config, ())    
};

(:~ gen fcs-resource scan out of mappings :)
declare function crday:gen-fcs-resource-scan($config as node()) as item()* {

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


(:~ run or view (if available) internal check queries 

@param format [raw, htmlpage, html] - raw: return only the produced table, html* : serialize as html
:)
declare function crday:get-query-internal($config, $x-context as xs:string, $run-flag as xs:boolean, $format as xs:string ) as item()* {

    let $testset := doc(repo-utils:config-value($config, 'tests.path')),
    
        $cache-path := repo-utils:config-value($config, 'cache.path'),             
        $queries-doc-name := crday:check-queries-doc-name($config, $x-context), 
  
  (: get the the results from cache, or create :)
  $result := if (exists($testset)) then 
                if (repo-utils:is-in-cache($queries-doc-name, $config) and not($run-flag)) then
                    repo-utils:get-from-cache($queries-doc-name, $config) 
                  else                    
                    let $context := repo-utils:context-to-collection($x-context, $config)
                    return if (exists($context)) then 
                            crday:gen-query-internal($testset, $context, $x-context, $cache-path, $queries-doc-name)
                            (: no need to store, because already continuously stored during querying  
                                 return repo-utils:store-in-cache($index-doc-name , $data, $config) :)
                           else 
                            diag:diagnostics("general-error", concat("run-check-queries: no context: ", $x-context))
               else
                diag:diagnostics("general-error", concat("run-check-queries: no testset available: ", repo-utils:config-value($config, 'tests.path')))
                
(:  return $result:)    
   return if ($format eq 'raw') then
            $result
         else            
            repo-utils:serialise-as($result, $format, 'table', $config, ())    
};

(:~ evaluates queries against given context and stores the result in aresult-file

@param $queries list of <xpath>-elements
@param $context nodeset to evaluate the queries against ($context shall be used in the queries)
@param $x-context string-key identifying the context 
:)
declare function crday:gen-query-internal($queries, $context as node()*, $x-context as xs:string+, $result-path as xs:string, $result-filename as xs:string ) as item()* {
       
    (: collect the xpaths from the queries-list before fiddling with the namespace :)
    let $xpaths := $queries//xpath
    (:    let $context := repo-utils:context-to-collection($x-context, $config)       
	   $context:= collection("/db/mdrepo-data/cmdi-providers"),	   :)

(:    let $result-store := xmldb:store($result-path ,  $result-filename, <result test="{$queries//test/xs:string(@id)}" context="{$x-context}" ></result>),:)
        let $result := <result test="{$queries//test/xs:string(@id)}" context="{$x-context}" ></result>    
        let $result-doc := repo-utils:store($result-path , $result-filename, $result, true())    
(:        $result-doc:= doc($result-store):)

    let $ns-uri := namespace-uri($context[1]/*)        	           
      (: dynamically declare a default namespace for the xpath-evaluation, if one is defined in current context 
      WATCHME: this is not very reliable, mainly meant to handle default-ns: cmd :)
(:      $dummy := if (exists($ns-uri)) then util:declare-namespace("",$ns-uri) else () :)
    let $dummy := util:declare-namespace("",xs:anyURI($ns-uri))    

    let $start-time := util:system-dateTime()	
    let $upd-dummy :=  
        for $xpath in $xpaths            
            let $start-time := util:system-dateTime()
            let $answer := util:eval($xpath/text())
            let $duration := util:system-dateTime() - $start-time
           return update insert <xpath key="{$xpath/@key}" label="{$xpath/@label}" dur="{$duration}">{$answer}</xpath> into $result-doc/result

    return $result-doc
};

(:~ wrapper for the ay-xml function cares for storing the result or fetching a stored one

@param format [raw, htmlpage, html] - raw: return only the produced table, html* : serialize as html
:)
declare function crday:get-ay-xml($config, $x-context as xs:string+, $init-xpath as xs:string, $max-depth as xs:integer, $run-flag as xs:boolean, $format as xs:string ) as item()? {
	
  let $name := repo-utils:gen-cache-id("structure", ($x-context, $init-xpath), xs:string($max-depth)),
    $result := 
    if (repo-utils:is-in-cache($name, $config) and not($run-flag)) then
        repo-utils:get-from-cache($name, $config)
    else
       
      let $context := repo-utils:context-to-collection($x-context, $config)
             (: prevent running on whole default collection - rather do it context by context :)
      return if (exists($context) and $x-context ne '') then
                    let $data := crday:gen-ay-xml($context, $init-xpath, $max-depth)
                    return repo-utils:store-in-cache($name, $data,$config)
                  else 
                    diag:diagnostics("general-error", concat("run-ay-xml: no context: ", $x-context))        

   return if ($format eq 'raw') then
            $result
         else            
          repo-utils:serialise-as($result, $format, 'terms', $config, ())    
};


(:~ analyzes the xml-structure - sub-elements and text-nodes
in the context of given collection, starting from given xpath

@param $context nodeset to analyze
@param $path if starts-with '/' or = '' start directly at the $context, else eval on f 'descendants-or-self'-axis
            if $path empty - diagnostics
calls elem-r for recursive processing

@returns xml-with paths and numbers 
:)
declare function crday:gen-ay-xml($context as item()*, $path as xs:string, $depth as xs:integer ) as element() {
  
  (:let $collection := collection($cr:dataPath),
  if ($collections[1] eq $cr:collectionRoot) then
  util:eval(fn:concat("$collection/descendant::IsPartOf[ft:query(., <query><term>", xdb:decode($coll), "</term></query>)]/ancestor-or-self::CMD/descendant-or-self::", $path))
  :)
  if (not(exists($path))) then
        diag:diagnostics("general-error", "ay-xml: no starting path provided") 
    else
        
        let $ns-uri := namespace-uri($context[1]/*),
            $local-name := $context[1]/*/local-name(),
(:            $prefix := if (exists(prefix-from-QName($qname))) then prefix-from-QName($qname) else "",:)
            $dummy := if (exists($ns-uri)) then util:declare-namespace("",$ns-uri) else ()
        
        let $full-path := if (starts-with($path,'/') or $path = '') then
                             fn:concat("$context", $path)
                            else     fn:concat("$context/descendant-or-self::", $path)

       let $path-nodes := if ($crday:restrictAyRecordsSize) then
                               subsequence(util:eval($full-path), 1, $crday:maxAyRecords)
                            else 
                               util:eval($full-path)
       
       let $entries := crday:elem-r($path-nodes, $path, $ns-uri, $depth, $depth),
     (:      $coll-names-value := if (fn:empty($collections)) then () else attribute colls {fn:string-join($collections, ",")},:)
             $dummy-undeclare-ns := util:declare-namespace("",xs:anyURI("")), 
     	  $result := element {$crday:docTypeTerms} {
     (:      		  $coll-names-value,:)
           		  attribute depth {$depth},
           		  attribute created {fn:current-dateTime()},
           		  $entries  
     		}
         return $result
    
};

(:~ goes down the xml-structure recursively and creates a summary about it along the way

namespace aware (handles namespace: none, default, explicit)
:)
declare function crday:elem-r($path-nodes as node()*, $path as xs:string, $ns as xs:anyURI?, $max-depth as xs:integer, $depth as xs:integer) as element() {
      let $path-count := count($path-nodes),
	$child-elements := $path-nodes/child::element(),
	$child-ns-qnames := if (exists($child-elements)) then distinct-values($child-elements/concat(namespace-uri(), '|', local-name())) else (),	
	$nodes-child-terminal := if (empty($child-elements)) then $path-nodes else () (: Maybe some selected elements $child-elements[not(element())] later on :),
	$text-nodes := $nodes-child-terminal/text(),
	$text-count := count($text-nodes),
	$text-count-distinct := count(distinct-values($text-nodes)),
	$dummy-undeclare-ns := util:declare-namespace("",xs:anyURI(""))
	return 
(:	<Term path="{fn:concat("//", $path)}" name="{text:groups($path, "/([^/]+)$")[last()]}" count="{$path-count}" count_text="{$text-count}"  count_distinct_text="{$text-count-distinct}">{ :)
	<Term path="{fn:concat("", translate($path,'/','.'))}" name="{(text:groups($path, "/([^/]+)$")[last()],$path)[1] }" count="{$path-count}" count_text="{$text-count}"  count_distinct_text="{$text-count-distinct}">{
	   (attribute ns {$ns},
	  if ($depth > 0) then
	    for $ns-qname in $child-ns-qnames[. != '']
	       let $ns-uri := substring-before($ns-qname, '|'),
	           $local-name := substring-after($ns-qname, '|'),
(:	           $prefix := if (exists(prefix-from-QName($qname))) then prefix-from-QName($qname) else "",:)
	           (: dynamically declare a namespace for the next step, if one is defined in current context :)
	           $dummy := if (exists($ns-uri)) then util:declare-namespace("",$ns-uri) else ()
	           return  
	           crday:elem-r(util:eval(concat("$path-nodes/", $local-name)), concat($path, '/', $local-name), $ns-uri, $max-depth, $depth - 1)			
	  (:
	    for $ns-qname in $child-ns-qnames[. != '']
	       let $ns-uri := substring-before($ns-qname, '|'),
	           $qname := substring-after($ns-qname, '|'),
	           $prefix := if (exists(prefix-from-QName($qname))) then prefix-from-QName($qname) else "",
	           (\: dynamically declare a namespace for the next step, if one is defined in current context :\)
	           $dummy := if (exists($ns-uri)) then util:declare-namespace($prefix,$ns-uri) else ()
	           return  
	           crday:elem-r(util:eval(concat("$path-nodes/", $qname)), concat($path, '/', $qname), $ns-uri, $max-depth, $depth - 1):)			
	  else 'maxdepth'
	)}</Term>
};


(:~ return doc-name out of context and testset (from config) or empty string if testset does not exist :)
declare function crday:check-queries-doc-name($config, $x-context as xs:string) as xs:string {
let $testset := doc(repo-utils:config-value($config, 'tests.path')),
    $testset-name := if (exists($testset)) then util:document-name($testset) else (),
    $sanitized-xcontext := repo-utils:sanitize-name($x-context)  
 return if (exists($testset)) then repo-utils:gen-cache-id("queries", ($sanitized-xcontext, $testset-name),"") else ""
 
};
