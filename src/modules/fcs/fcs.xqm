xquery version '3.0';

(:
: Module Name: FCS
: Date: 2012-03-01
: 
: XQuery 
: Specification : XQuery v1.0
: Module Overview: Federated Content Search
:)

(:~ This module provides methods to serve XML-data via the FCS/SRU-interface  
: @see http://clarin.eu/fcs 
: @author Matej Durco
: @since 2011-11-01 
: @version 1.1 
:)
module namespace fcs = "http://clarin.eu/fcs/1.0";
 
declare namespace err = "http://www.w3.org/2005/xqt-errors";
declare namespace sru = "http://www.loc.gov/zing/srw/";
declare namespace zr = "http://explain.z3950.org/dtd/2.0/";
declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace cmd = "http://www.clarin.eu/cmd/";
declare namespace xhtml= "http://www.w3.org/1999/xhtml";
declare namespace aac = "urn:general";
declare namespace mets="http://www.loc.gov/METS/";

declare namespace xlink="http://www.w3.org/1999/xlink";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace diag =  "http://www.loc.gov/zing/srw/diagnostic/" at  "../diagnostics/diagnostics.xqm";
import module namespace cr="http://aac.ac.at/content_repository" at "../../core/cr.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "../../core/config.xqm";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at  "../../core/repo-utils.xqm";
import module namespace kwic = "http://exist-db.org/xquery/kwic";
(:import module namespace cmdcoll = "http://clarin.eu/cmd/collections" at  "../cmd/cmd-collections.xqm"; :)
import module namespace cmdcheck = "http://clarin.eu/cmd/check" at  "../cmd/cmd-check.xqm";
import module namespace cql = "http://exist-db.org/xquery/cql" at "../query/cql.xqm";
import module namespace query  = "http://aac.ac.at/content_repository/query" at "../query/query.xqm";
(:import module namespace facs = "http://www.oeaw.ac.at/icltt/cr-xq/facsviewer" at "../facsviewer/facsviewer.xqm";:)
import module namespace facs = "http://aac.ac.at/content_repository/facs" at "../../core/facs.xqm";
import module namespace wc="http://aac.ac.at/content_repository/workingcopy" at "../../core/wc.xqm";
import module namespace project="http://aac.ac.at/content_repository/project" at "../../core/project.xqm";
import module namespace resource="http://aac.ac.at/content_repository/resource" at "../../core/resource.xqm";
import module namespace index="http://aac.ac.at/content_repository/index" at "../../core/index.xqm";
import module namespace rf="http://aac.ac.at/content_repository/resourcefragment" at "../../core/resourcefragment.xqm";

declare variable $fcs:explain as xs:string := "explain";
declare variable $fcs:scan  as xs:string := "scan";
declare variable $fcs:searchRetrieve as xs:string := "searchRetrieve";

declare variable $config:app-root external;

declare variable $fcs:scanSortText as xs:string := "text";
declare variable $fcs:scanSortSize as xs:string := "size";
declare variable $fcs:indexXsl := doc(concat(system:get-module-load-path(),'/index.xsl'));
declare variable $fcs:kwicWidth := 40;
(: this limit is introduced due to performance problem >50.000?  nodes (100.000 was definitely too much) :)  
declare variable $fcs:maxScanSize:= 100000;

declare variable $fcs:project-index-functions-ns-base-uri := "http://aac.ac.at/content-repository/projects-index-functions/";

(:~ The main entry-point. Processes request-parameters
regards config given as parameter + the predefined sys-config
@returns the result document (in xml, html or json)
:)
(: declare function fcs:repo($config-file as xs:string) as item()* { :)
declare function fcs:repo($config) as item()* {
  let    
    (: $config := repo-utils:config($config-file), :)   
     
    $key := request:get-parameter("key", "index"),        
        (: accept "q" as synonym to query-param; "query" overrides:)    
    $q := request:get-parameter("q", ""),
    $query := request:get-parameter("query", $q),    
        (: if query-parameter not present, 'explain' as DEFAULT operation, otherwise 'searchRetrieve' :)
(:    $operation :=  if ($query eq "") then request:get-parameter("operation", $fcs:explain):)
    $operation :=  if ($query eq "") then request:get-parameter("operation", "explain")
                    else request:get-parameter("operation", $fcs:searchRetrieve),
    $recordPacking:= request:get-parameter("recordPacking", 'xml'),
      
    (: take only first format-argument (otherwise gives problems down the line) 
        TODO: diagnostics :)
    $x-format := (request:get-parameter("x-format", $repo-utils:responseFormatXml))[1],
    $x-context_ := request:get-parameter("x-context", request:get-parameter("project", "")),
    $x-context := if ($x-context_ eq '') then request:get-parameter("project", "") else $x-context_,
    (:
    $query-collections := 
    if (matches($collection-params, "^root$") or $collection-params eq "") then 
      $cr:collectionRoot
    else
		tokenize($collection-params,','),
        :)
(:      $collection-params, :)
  $max-depth as xs:integer := xs:integer(request:get-parameter("maxdepth", 1))

  let $result :=
      (: if ($operation eq $cr:getCollections) then
		cr:get-collections($query-collections, $format, $max-depth)
      else :)
      if ($operation eq $fcs:explain) then
          fcs:explain($x-context, $config)		
      else if ($operation eq $fcs:scan) then
        (: allow optional $index-parameter to be prefixed to the scanClause 
            this is just to simplify input on the client-side :) 
        let $index := request:get-parameter("index", ""),
            $scanClause-param := request:get-parameter("scanClause", ""),
		    $scanClause :=    if ($index ne '' and  not(starts-with($scanClause-param, $index)) ) 
		                      then concat( $index, '=', $scanClause-param)
		                      else $scanClause-param,
		    $mode := request:get-parameter("x-mode", ""),
		    $start-term := request:get-parameter("startTerm", 1),
		    $response-position := request:get-parameter("responsePosition", 1),
		    $max-terms := request:get-parameter("maximumTerms", 50),
	        $max-depth := request:get-parameter("x-maximumDepth", 1),
		    $sort := request:get-parameter("sort", 'text')
		 return 
		  if ($scanClause='') 
		  then
		      <sru:scanResponse>
		          <sru:version>1.2</sru:version>
		          {diag:diagnostics('param-missing',"scanClause")}
		      </sru:scanResponse>
		  else 
		      if (not(number($max-terms)=number($max-terms)) or number($max-terms) < 0 ) 
		      then
		          <sru:scanResponse>
		              <sru:version>1.2</sru:version>
		              {diag:diagnostics('unsupported-param-value',"maximumTerms")}
		          </sru:scanResponse>
              else 
                    if (not(number($response-position)=number($response-position)) or number($response-position) < 0 ) 
                    then
                        <sru:scanResponse>
                        <sru:version>1.2</sru:version>
                        {diag:diagnostics('unsupported-param-value',"responsePosition")}
   		             </sru:scanResponse>
		             else 
		              fcs:scan($scanClause, $x-context, $start-term, $max-terms, $response-position, $max-depth, $sort, $mode, $config) 
      (: return fcs:scan($scanClause, $x-context) :)
	  else if ($operation eq $fcs:searchRetrieve) then
        if ($query eq "") then <sru:searchRetrieveResponse><sru:version>1.2</sru:version><sru:numberOfRecords>0</sru:numberOfRecords>
                                {diag:diagnostics("param-missing", "query")}</sru:searchRetrieveResponse>
        else 
      	 let $cql-query := $query,
			$start-item := request:get-parameter("startRecord", 1),
			$max-items := request:get-parameter("maximumRecords", 50),
			$x-dataview := request:get-parameter("x-dataview", repo-utils:config-value($config, 'default.dataview'))
            (: return cr:search-retrieve($cql-query, $query-collections, $format, xs:integer($start-item), xs:integer($max-items)) :)
            return 
            if (not($recordPacking = ('string','xml'))) then 
                        <sru:searchRetrieveResponse><sru:version>1.2</sru:version><sru:numberOfRecords>0</sru:numberOfRecords>
                                {diag:diagnostics("unsupported-record-packing", $recordPacking)}</sru:searchRetrieveResponse>
                else if (not(number($max-items)=number($max-items)) or number($max-items) < 0 ) then
                        <sru:searchRetrieveResponse><sru:version>1.2</sru:version><sru:numberOfRecords>0</sru:numberOfRecords>
                                {diag:diagnostics("unsupported-param-value", "maximumRecords")}</sru:searchRetrieveResponse>
                else if (not(number($start-item)=number($start-item)) or number($start-item) <= 0 ) then
                        <sru:searchRetrieveResponse><sru:version>1.2</sru:version><sru:numberOfRecords>0</sru:numberOfRecords>
                                {diag:diagnostics("unsupported-param-value", "startRecord")}</sru:searchRetrieveResponse>
                else
            fcs:search-retrieve($cql-query, $x-context, xs:integer($start-item), xs:integer($max-items), $x-dataview, $config)
    else 
      diag:diagnostics('unsupported-operation',$operation)
    
   return  repo-utils:serialise-as($result, $x-format, $operation, $config)
   
};

(:~ OBSOLETED ! 
Strictly speaking not part of the FCS-protocol, 
this function delivers static content, to be returned as HTML.
: @param $content-id required, identifies the content to be returned. The id is matched against id-attribute in the {config:static.path}-collection
: @param $x-context not used right now! probably not needed 
: @returns found static data or nothing 
:)
(:declare function fcs:static($content-id as xs:string+, $x-context as xs:string*, $config) as item()* {
    let $context := if ($x-context) then $x-context
                    else repo-utils:config-value($config, 'explain')
    let $static-dbcoll := collection(repo-utils:config-value($config,'static.path'))     
   let $data := $static-dbcoll//*[@id=$content-id]
    
    return $data
};
:)

(:~ handles the explain-operation requests.
: @param $x-context optional, identifies a resource to return the explain-record for. (Accepts both MD-PID or Res-PID (MdSelfLink or ResourceRef/text))
: @returns either the default root explain-record, or - when provided with the $x-context parameter - the explain-record of given resource
:)
declare function fcs:explain($x-context as xs:string*, $config) as item()* {
(: let $context := if ($x-context) then $x-context
                    else repo-utils:config-value($config, 'explain')
  let $explain := $md-dbcoll//CMD[Header/MdSelfLink/text() eq $context or .//ResourceRef/text() eq $context]//(explain|zr:explain) (\: //ResourceRef/text() :\):)

    let $md-dbcoll := collection(repo-utils:config-value($config,'metadata.path'))
    
    let $context-mapping := fcs:get-mapping('',$x-context, $config),
     (: if not specific mapping found for given context, use whole mappings-file
        this currently happens already in the get-mapping function 
          $mappings := if ($context-mapping/xs:string(@key) = $x-context) then $context-mapping 
                    else doc(repo-utils:config-value($config, 'mappings')):)
        $mappings := $context-mapping

(:    let $mappings := doc(repo-utils:config-value($config, 'mappings'))
(\:    let $context-mappings := if ($x-context='') then $mappings else $mappings//map[xs:string(@key)=$x-context]:\):\)
    let $context-map := fcs:get-mapping("",$x-context, $config)
:)
    let $server-host :=  'TODO: config:param-value($config, "base-url")', 
        $database := repo-utils:config-value($config, 'project-id'),
        $title := concat( repo-utils:config-value($config, 'project-title'), 
                    if ($x-context != '') then concat(' - ', $mappings/xs:string(@title)) else '') ,
        $descr := repo-utils:config-value($config, 'teaser-text'),
        $author := repo-utils:config-value($config, 'author'),
        $contact := repo-utils:config-value($config, 'contact'),
        $date-modified := 'TODO'
      
      
    let $explain:=
    <sru:explainResponse>
 <sru:version>1.1</sru:version>
 <sru:record>

   <sru:recordSchema>http://explain.z3950.org/dtd/2.1/</sru:recordSchema>
   <sru:recordPacking>xml</sru:recordPacking>
   <sru:recordData>
    <zr:explain xmlns:zr="http://explain.z3950.org/dtd/2.0/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://explain.z3950.org/dtd/2.0/ file:/C:/Users/m/3lingua/corpus_shell/_repo2/corpus_shell/fcs/schemas/zeerex-2.0.xsd"
    authoritative="false" id="id1">
    <zr:serverInfo protocol="SRU" version="1.2" transport="http">
        <zr:host>{$server-host}</zr:host>
        <zr:port>80</zr:port>
        <zr:database>{$database}</zr:database>
    </zr:serverInfo>
    <zr:databaseInfo>
        <zr:title lang="en" primary="true">{$title}</zr:title>
        <zr:description lang="en" primary="true">{$descr}</zr:description>
        <zr:author>{$author}</zr:author>
        <zr:contact>{$contact}</zr:contact>
    </zr:databaseInfo>
    <zr:metaInfo>
        <zr:dateModified>{$date-modified}</zr:dateModified>
    </zr:metaInfo>
    <zr:indexInfo>
        <zr:set identifier="isocat.org/datcat" name="isocat">
            <zr:title>ISOcat data categories</zr:title>
        </zr:set>
        <zr:set identifier="clarin.eu/fcs" name="fcs">
            <zr:title>CLARIN - Federated Content Search</zr:title>
        </zr:set>
        <!-- <index search="true" scan="true" sort="false">
            <title lang="en">Resource</title>
            <map>
                <name set="fcs">resource</name>
            </map>
        </index> -->
        { for $index in $mappings//index
            let $ix-key := $index/xs:string(@key)
            order by $ix-key
            return
                <zr:index search="true" scan="{($index/data(@scan), 'false')[1]}" sort="false">
                <zr:title lang="en">{$ix-key}</zr:title>
                <zr:map>
                    <zr:name set="fcs">{$ix-key}</zr:name>
                </zr:map>
        </zr:index>
        }
    </zr:indexInfo>
    <zr:schemaInfo>
    <!--    <schema identifier="clarin.eu/cmd" location="" name="cmd" retrieve="true">
            <title lang="en">Component Metadata</title>
        </schema> -->
    </zr:schemaInfo>
    <zr:configInfo>
        <!-- should translate to x-cmd-context extension-parameter if correctly interpreted: http://explain.z3950.org/dtd/commentary.html#8 
                    or shall we rather directly write: x-cmd-context or x-fcs-context -->
<!--        <supports type="extraSearchData">cmd context</supports> -->
    </zr:configInfo>
</zr:explain>
   </sru:recordData>
 </sru:record>
</sru:explainResponse>

    return $explain
};

(:
TODO?: only read explicit indexes + create index on demand.
:)
(:
declare function fcs:scan($scanClause as xs:string, $x-context as xs:string*) {
    
    let $clause-tokens := tokenize($scanClause,'='),
        $index := $clause-tokens[1],
        $term := $clause-tokens[2],
        (\:$map-index := $repo-utils:mappings/map/index[@key=$index], :\)
        $index-file := concat(repo-utils:config-value('index.prefix'),$index,'.xml'),
        h$result := doc($index-file)
    
    return $result     
};
:)


(:~ This function handles the scan-operation requests
:  (derived from cmd:scanIndex function)
: two phases: 
:   1. one create full index for given path/element within given collection (for now the collection is stored in the name - not perfect) (and cache)
:	2. select wished subsequence (on second call, only the second step is performed)
	
: actually wrapping function handling caching of the actual scan result (coming from do-scan-default())
: or fetching the cached result (if available)
: also dispatching to cmd-collections for the scan-clause=cmd.collections
:   there either scanClause-filter or x-context is used as constraint (scanClause-filter is prefered))

:)
declare function fcs:scan($scan-clause  as xs:string, $x-context as xs:string+, $start-item as xs:integer, $max-items as xs:integer, $response-position as xs:integer, $max-depth as xs:integer, $p-sort as xs:string?, $mode as xs:string?, $config) as item()? {

  let $scx := tokenize($scan-clause,'='),
	 $index-name := $scx[1],  
	 (:$index := fcs:get-mapping($index-name, $x-context, $config ), :)
	 (: if no index-mapping found, dare to use the index-name as xpath :) 
     (:$index-xpath := index:index-as-xpath($index-name,$x-context),:)
 	 $filter := ($scx[2],'')[1],	 
	 $sort := if ($p-sort eq $fcs:scanSortText or $p-sort eq $fcs:scanSortSize) then $p-sort else $fcs:scanSortText	
	 
	 let $sanitized-xcontext := repo-utils:sanitize-name($x-context) 
	 let $project-id := if (config:project-exists($x-context)) then $x-context else cr:resolve-id-to-project-pid($x-context)
    let $index-doc-name := repo-utils:gen-cache-id("index", ($sanitized-xcontext, $index-name, $sort, $max-depth)),
        $dummy := util:log-app("DEBUG", $config:app-name, "cache-mode: "||$mode),
        $dummy2 := util:log-app("DEBUG", $config:app-name, "is in cache: "||repo-utils:is-in-cache($index-doc-name, $config) ),
  (: get the base-index from cache, or create and cache :)
  $index-scan := 
  if (repo-utils:is-in-cache($index-doc-name, $config) and not($mode='refresh')) then
          let $dummy := util:log-app("DEBUG", $config:app-name, "reading index "||$index-doc-name||" from cache")
          return repo-utils:get-from-cache($index-doc-name, $config)           
        else
        (: TODO: cmd-specific stuff has to be integrated in a more dynamic way! :) 
            let $data :=
                (:
                if ($index-name eq $cmdcoll:scan-collection) then
                    let $starting-handle := if ($filter ne '') then $filter else $x-context
                    return cmdcoll:colls($starting-handle, $max-depth, cmdcoll:base-dbcoll($config))
                  (\: just a hack for now, handling of special indexes should be put solved in some more easily extensible way :\)  
                else :) 
                if ($index-name eq 'cmd.profile') then
(:(\:                    let $context := repo-utils:context-to-collection($x-context, $config):\):)
                    cmdcheck:scan-profiles($x-context, $config)
                    
                else 
                if (starts-with($index-name, 'fcs.')) then
                    let $metsdivs := 
                           switch ($index-name)
                                (: resources only :)
                                case 'fcs.resource' return let $resources := project:list-resources($x-context)
                                                           return $resources!<mets:div>{./@*}</mets:div>
                                case 'fcs.rf' return if ($project-id eq $x-context) then project:list-resources($x-context)
                                                        else resource:get($x-context,$project-id)
                                case 'fcs.toc' return if ($project-id eq $x-context) then
                                    (: this delivers the whole structure of all resources - it may be too much in one shot 
                                        resource:get-toc($project-id) would deliver only up until chapter level 
                                        alternatively just take fcs.resource to get only resource-listing :)
                                            project:get-toc-resolved($project-id)
                                            else resource:get-toc($x-context,$project-id)                                                        
                            default return ()
                    (:let $map := 
(\:                        if ($x-context= ('', 'default')) then 
                             doc(repo-utils:config-value($config, 'mappings')):\)
                          if (not($context-map/xs:string(@key) = $x-context) ) then 
                                $context-map
                        else
                            (\: generate a map based on the indexes defined for given context :\) 
                            let $data-collection := repo-utils:context-to-collection($x-context, $config)
(\:                            let $context-map := fcs:get-mapping('', $x-context,$config):\)
                            let $fcs-resource-index := fcs:get-mapping('fcs.resource', $x-context,$config)
                            let $index-key-xpath := $fcs-resource-index/(path[xs:string(@type)='key'], path)[1]
                            let $index-label-xpath := $fcs-resource-index/(path[xs:string(@type)='label'], path)[1]
                            let $base-elem := $fcs-resource-index/xs:string(@base_elem)
                            return <map >{
                                ($context-map/@key, $context-map/@title, 
                                for $item in util:eval(concat("$data-collection/descendant-or-self::", $base-elem))
                                    let $key := util:eval(concat("$item/", $index-key-xpath ))
                                    let $label := util:eval(concat("$item/", $index-label-xpath ))
                                    return <map key="{$key}" title="{$label}" />
                                )}</map>
:)
(:                    let $mappings := doc(repo-utils:config-value($config, 'mappings')):)
                    (: use only module-config here - otherwise scripts.path override causes problems :) 
                    let $xsl := repo-utils:xsl-doc('metsdiv-scan', "xml", $config)
                    
                    return transform:transform($metsdivs,$xsl,())
(:                    return $context-map:)
                        
                                
                else
                    fcs:do-scan-default($scan-clause, $x-context, $sort, $config)         

          (: if empty result, return the empty result, but don't store
            to not fill cache with garbage:)
(:            return $data:)
        let $dummy := util:log-app("DEBUG", $config:app-name, "generating index "||$index-doc-name)
        return  repo-utils:store-in-cache($index-doc-name , $data, $config,'indexes')

        (:if (number($data//sru:scanResponse/sru:extraResponseData/fcs:countTerms) > 0) then
        
                else $data:)

    (: extra handling if fcs.resource=root :)
    let $filterx := if ($index-name= 'fcs.resource' and $filter='root') then '' else $filter
    
	(: extract the required subsequence (according to given sort) :)
	let $res-nodeset := transform:transform($index-scan,$fcs:indexXsl, 
			<parameters><param name="scan-clause" value="{$scan-clause}"/>
			            <param name="mode" value="subsequence"/>
			            <param name="x-context" value="{$x-context}"/>
						<param name="sort" value="{$sort}"/>
						<param name="filter" value="{$filterx}"/>
						<param name="start-item" value="{$start-item}"/>
					    <param name="response-position" value="{$response-position}"/>
						<param name="max-items" value="{$max-items}"/>
			</parameters>),
		$count-items := count($res-nodeset/sru:term),
		(: $colls := if (fn:empty($collection)) then '' else fn:string-join($collection, ","), :)
        $colls := string-join( $x-context, ', ') ,
		$created := fn:current-dateTime()
		(: $scan-clause := concat($xpath, '=', $filter) :)
		(: $res := <Terms colls="{$colls}" created="{$created}" count_items="{$count-items}" 
					start-item="{$start-item}" max-items="{$max-items}" sort="{$sort}" scanClause="{$scan-clause}"  >{$res-term}</Terms> 
					  count_text="{$count-text}" count_distinct_text="{$distinct-text-count}" :)
        (: $res := <sru:scanResponse>
                    <sru:version>1.2</sru:version>
                    {$res-nodeset}        			    
                    <sru:echoedScanRequest>                        
                        <sru:scanClause>{$scan-clause}</sru:scanClause>
                        <sru:maximumTerms>{ $count-items }</sru:maximumTerms>    

                    </sru:echoedScanRequest>
    			</sru:scanResponse>
           :)         
(:	let	$result-count := $doc/Term/@count,
    $result-seq := fn:subsequence($doc/Term/v, $start-item, $end-item),
	$result-frag := ($doc/Term, $result-seq),
    $seq-count := fn:count($result-seq) :)

  return $res-nodeset   
(:return $index-scan  DEBUG:)
};


(:OBSOLETED ! 
    aggregation, sorting and serializing is handled by fcs:term-from-nodes() and fcs:group-by-facet()

declare function fcs:do-scan-default($scan-clause as xs:string, $x-context as xs:string, $sort as xs:string, $config) as item()* {
    let $path := index:index-as-xpath($scan-clause,$x-context)
    let $data-collection := repo-utils:context-to-collection($x-context, $config)
    let $getnodes := util:eval(fn:concat("$data-collection//", $path)),
        $match-path := index:index-as-xpath($scan-clause,$x-context,'match-only'),
        $label-path := index:index-as-xpath($scan-clause,$x-context,'label-only'),
        $log := util:log-app("INFO",$config:app-name,$match-path||" "||$label-path),
        (\: if we collected strings, we have to wrap them in elements 
           to be able to work with them in xsl :\)
        $prenodes :=    if ($label-path!='') then 
                             for $t in $getnodes 
                             return 
                                <v displayTerm="{string-join(util:eval("$t/"||$label-path),'')}">{string-join(util:eval("$t/"||$match-path),'')}</v>
                        else if ($getnodes[1] instance of xs:string or $getnodes[1] instance of text()) then
                                for $t in $getnodes return <v>{$t}</v>
                        else if ($getnodes[1] instance of attribute()) then
                                for $t in $getnodes return <v>{xs:string($t)}</v>
                        else for $t in $getnodes return <v>{string-join($t//text()," ")}</v>
    let $nodes := <nodes path="{fn:concat('//', $match-path)}"  >{$prenodes}</nodes>,
        	(\: use XSLT-2.0 for-each-group functionality to aggregate the values of a node - much, much faster, than XQuery :\)
   	    $data := transform:transform($nodes,$fcs:indexXsl, 
   	                <parameters>
   	                    <param name="scan-clause" value="{$scan-clause}"/>
   	                    <param name="sort" value="{$sort}"/>
   	                </parameters>)
   	    
    return $data
};:)

declare function fcs:do-scan-default($scan-clause as xs:string, $x-context as xs:string, $sort as xs:string, $config) as item()* {
    let $project-pid := repo-utils:context-to-project-pid($x-context,$config)
    let $facets := index:facets($scan-clause,$project-pid)
    let $path := index:index-as-xpath($scan-clause,$project-pid)
    (:let $data-collection := repo-utils:context-to-collection($x-context, $config),
        $nodes := util:eval("$data-collection//"||$path):)
    let $context-parsed := repo-utils:parse-x-context($x-context,$config)
    let $data := repo-utils:context-to-data($context-parsed,$config),
    (: this limit is introduced due to performance problem >50.000?  nodes (100.000 was definitely too much) :)
        $nodes := subsequence(util:eval("$data//"||$path),1,$fcs:maxScanSize)
    
    let $terms := 
        if ($facets/index)
        then fcs:group-by-facet($nodes, $sort, $facets/index, $project-pid)
        else fcs:term-from-nodes($nodes, $sort, $scan-clause, $project-pid)
        
    return 
        <sru:scanResponse xmlns:fcs="http://clarin.eu/fcs/1.0">
            <sru:version>1.2</sru:version>
            {$terms}
            <sru:extraResponseData>
                <fcs:countTerms level="top">{count($terms)}</fcs:countTerms>
                <fcs:countTerms level="total">{count($terms//sru:term)}</fcs:countTerms>
             </sru:extraResponseData>
            <sru:echoedScanRequest>
                <sru:scanClause>{$scan-clause}</sru:scanClause>
                <sru:maximumTerms/>
            </sru:echoedScanRequest>
        </sru:scanResponse>
};

(:%private :)
declare function fcs:term-from-nodes($node as item()+, $order-param as xs:string, $index-key as xs:string, $project-pid as xs:string) {
    let $match-path := index:index-as-xpath($index-key,$project-pid,'match-only'),
        $label-path := index:index-as-xpath($index-key,$project-pid,'label-only')
    let $data :=  for $n in $node
                    let $value:= map:entry("value",string-join(util:eval("$n/"||$match-path),'')),
                        $label := map:entry("label",
                            if ($label-path!='') 
                            then util:eval("$n/"||$label-path)/data(.)
                            else $value)
                    return map:new(($value,$label))
    
    let $order-expr :=
        switch ($order-param)
            case 'text' return "$value"
            case 'size' return "count($g)"
            default     return "$value"
            
   let $order-modifier :=
        switch ($order-param)
            case 'size' return "descending"
            default     return "ascending"
    
    let $terms :=           
        for $g at $pos in $data
        group by $value := map:get($g,'value')
        order by 
            if ($order-modifier='ascending') then true() else util:eval($order-expr) descending,
            if ($order-modifier='descending') then true() else util:eval($order-expr) ascending
        return
            let $m-label := map:entry("label",map:get($g[1],'label')),
                $m-value := map:entry("value",$value),
                $m-count := map:entry("numberOfRecords",count($g))
            return map:new(($m-label,$m-value,$m-count))
    return <sru:terms> 
        {
        for $term at $pos in $terms
        return <sru:term>
                    <sru:value>{$term("value")}</sru:value>
                    <sru:displayTerm>{$term("label")}</sru:displayTerm>
                    <sru:numberOfRecords>{$term("numberOfRecords")}</sru:numberOfRecords>
                    <sru:extraTermData>
                        <fcs:position>{$pos}</fcs:position>
                    </sru:extraTermData>
                </sru:term>
                }
                </sru:terms>
};


declare %private function fcs:group-by-facet($data as node()*,$sort as xs:string, $index as element(index), $project-pid) as item()* {
    let $key := $index/xs:string(@key),
        $match:= index:index-as-xpath($key,$project-pid,'match-only')
     
     let $order-expression :=
        switch ($sort)
            case 'text' return "$group-key"
            case 'size' return "count($entries)"
            default     return "$group-key"
            
   let $order-modifier :=
        switch ($sort)
            case 'size' return "descending"
            default     return "ascending"
    
    let $groups := 
        let $maps := 
            for $x in $data 
            group by $g := util:eval("$x/"||$match)
            return map:entry($g,$x)
        let $map := map:new($maps)
        return $map
    
    return
     <sru:terms> {
        for $group-key in map:keys($groups)
        let $entries := map:get($groups, $group-key)
        order by 
                if ($order-modifier='ascending') then true() else util:eval($order-expression) descending,
                if ($order-modifier='descending') then true() else util:eval($order-expression) ascending
        return
            <sru:term>
                <sru:displayTerm>{fcs:term-to-label($group-key, $key,$project-pid)}</sru:displayTerm>
                <sru:value>{$group-key}</sru:value>
                <sru:numberOfRecords>{count($entries)}</sru:numberOfRecords>
                <sru:extraTermData>
                    <cr:type>{$key}</cr:type>
                    {if ($index/index)
                    then fcs:group-by-facet($entries, $sort, $index/index, $project-pid)
                    else fcs:term-from-nodes($entries, $sort, root($index)/index/@key, $project-pid)}
                </sru:extraTermData>
            </sru:term>
            } </sru:terms>
};

declare %private function fcs:term-to-label($term as xs:string, $index as xs:string, $project-pid as xs:string) as xs:string{
    let $labels := doc(project:path($project-pid,"home")||"/termlabels.xml")
    return ($labels//term[@key=$term][ancestor::*/@key=$index],$term)[1]
};


(:declare function fcs:exec-query($data as map(*)*, $xpath-query as xs:string?) as map()+ {:)
declare function fcs:exec-query($data, $xpath-query){
    fcs:exec-query($data,$xpath-query,())
};

(:declare function fcs:exec-query($data as map(*)*, $xpath-query as xs:string?, $flags as map()?) as map()* {:)
declare function fcs:exec-query($data, $xpath-query, $flags as map()?) {
    if ($xpath-query!='')
    then 
   
       (: if there was a problem with the parsing the query  don't evaluate :)
        if ($xpath-query instance of text() or $xpath-query instance of xs:string) then
                util:eval(concat("$data",translate($xpath-query,'&amp;','?')))
                        else ()
        
        (:for $d in $data("data") 
        return
            let $matches:= util:eval("$d"||$xpath-query)
            return
                map {
                    "resource-id":=$d,
                    "matches" := $matches,
                    "count" := count($matches)
                }:)
    else ()
};

(:~ 
 : Main search function that handles the searchRetrieve-operation request)
 :
 : @param $query: The FCS Query as input by the user
 : @param $x-context: The CR-Context of the query
 : @param $startRecord: The nth of all results to display
 : @param $maxmimumRecords: The maximum of records to display
 : @param $x-dataview: A comma-separated list of keywords for the output viwe on the results. This depends on <code>fcs:format-record-data()</code>.
 : @param $config: The project's config 
 : @see fcs:format-record-data()
~:)
declare function fcs:search-retrieve($query as xs:string, $x-context as xs:string*, $startRecord as xs:integer, $maximumRecords as xs:integer, $x-dataview as xs:string*, $config) as item()* {
        
        let $start-time := util:system-dateTime()                        
        let $project-id := cr:resolve-id-to-project-pid($x-context)
        let $context-parsed:=repo-utils:parse-x-context($x-context,$config)
                        
        (: basically search on workingcopy, just in case of resourcefragment lookup, we have to go to resourcefragments :)        
        (:let $data := if (contains($query,$config:INDEX_INTERNAL_RESOURCEFRAGMENT)) 
                        then collection(project:path($project-id, 'resourcefragments'))  
                        else repo-utils:context-to-collection($x-context, $config):)
        
        (: basically we search on working copies and filter out fragments and resoruces  
           (prefixed with a minus sign, e.g. &x-context=abacus2,-abacus2.1) below :)
        (: FIXME add support for index 'fcs.resource' :)
        let $data := if (contains($query,$config:INDEX_INTERNAL_RESOURCEFRAGMENT)) 
                     then collection(project:path($project-id, 'resourcefragments'))  
                     else repo-utils:context-to-data($context-parsed,$config)
        
        let $xpath-query := cql:cql-to-xpath($query,$project-id)
        
         (: ! results are only actual matching elements (no wrapping base_elem, i.e. resourcefragments ! :)
        let $result-unfiltered:= query:execute-query ($query,$data,$project-id)                         
        (: filter excluded resources or fragments unless this is a direct fragment request :)
        let $result := 
                if (contains($query,$config:INDEX_INTERNAL_RESOURCEFRAGMENT))
                then $result-unfiltered
                else repo-utils:filter-by-context($result-unfiltered,$context-parsed,$config)
        let	$result-count := fn:count($result),
            $facets := if (contains($x-dataview,'facets') and $result-count > 1) then fcs:generateFacets($result, $query) else (),
            $ordered-result := fcs:sort-result($result, $query, $x-context, $config),                              
            $result-seq := fn:subsequence($ordered-result, $startRecord, $maximumRecords),
            $seq-count := fn:count($result-seq),        
            $end-time := util:system-dateTime()
        let $config-param :=    if (contains($query,'fcs.toc')) 
                                then 
                                    map{
                                        "config" := $config,
                                        "x-highlight" := "off"
                                    }
                                else 
                                    $config
       
             let $result-seq-expanded := util:expand($result-seq)
             
             let $records :=
               <sru:records>{
                for $rec at $pos in $result-seq-expanded
         	        let $rec-data := fcs:format-record-data( $rec, $x-dataview, $x-context, $config-param)
                    return 
         	          <sru:record>
         	              <sru:recordSchema>http://clarin.eu/fcs/1.0/Resource.xsd</sru:recordSchema>
         	              <sru:recordPacking>xml</sru:recordPacking>         	              
         	              <sru:recordData>{$rec-data}</sru:recordData>         	              
         	              <sru:recordPosition>{$pos}</sru:recordPosition>
         	              <sru:recordIdentifier>{($rec-data/fcs:ResourceFragment[1]/data(@ref),$rec-data/data(@ref))[1]}</sru:recordIdentifier>
         	          </sru:record>
         	   }</sru:records>,
             $end-time2 := util:system-dateTime()
             
             return
                switch (true())
                    case ($xpath-query instance of element(sru:diagnostics)) return  
                        <sru:searchRetrieveResponse>
                            <sru:version>1.2</sru:version>
                            <sru:numberOfRecords>{$result-count}</sru:numberOfRecords>
                            {$xpath-query}
                        </sru:searchRetrieveResponse>
                
                    case ($startRecord > $result-count + 1 ) return
                        <sru:searchRetrieveResponse>
                            <sru:version>1.2</sru:version>
                            <sru:numberOfRecords>{$result-count}</sru:numberOfRecords>
                            {diag:diagnostics('start-out-of-range',concat( $startRecord , ' > ', $result-count))}
                        </sru:searchRetrieveResponse>
                        
                    default return
                        <sru:searchRetrieveResponse>
                            <sru:version>1.2</sru:version>
                            <sru:numberOfRecords>{$result-count}</sru:numberOfRecords>
                            <sru:echoedSearchRetrieveRequest>
                                <sru:version>1.2</sru:version>
                                <sru:query>{$query}</sru:query>
                                <fcs:x-context>{$x-context}</fcs:x-context>
                                <fcs:x-dataview>{$x-dataview}</fcs:x-dataview>
                                <sru:startRecord>{$startRecord}</sru:startRecord>
                                <sru:maximumRecords>{$maximumRecords}</sru:maximumRecords>
                                <sru:query>{$query}</sru:query>
                                <sru:baseUrl>{repo-utils:config-value($config, "base.url")}</sru:baseUrl>
                            </sru:echoedSearchRetrieveRequest>
                            <sru:extraResponseData>
                              	<fcs:returnedRecords>{$seq-count}</fcs:returnedRecords>
                                <fcs:numberOfMatches>{ () (: count($match) :)}</fcs:numberOfMatches>
                                <fcs:duration>{($end-time - $start-time, $end-time2 - $end-time) }</fcs:duration>
                                <fcs:transformedQuery>{ $xpath-query }</fcs:transformedQuery>
                            </sru:extraResponseData>
                            {$records}
                            {   if ($xpath-query instance of element(diagnostics)) 
                                then  <sru:diagnostics>{$xpath-query/*}</sru:diagnostics> 
                                else ()
                            }
                            {$facets}                     
                        </sru:searchRetrieveResponse>
};


(:~ facets are only available in SRU 2.0, but we need them now.

For now only for faceting over resources

xsi:schemaLocation="http://docs.oasis-open.org/ns/search-ws/facetedResults http://docs.oasis-open.org/search-ws/searchRetrieve/v1.0/os/schemas/facetedResults.xsd"
:)
declare function fcs:generateFacets($result, $orig-query) {
 let $project-id := ($result/data(@cr:project-id))[1]
return <sru:facetedResults>
    <sru:facet>
        <sru:facetDisplayLabel>Resource</sru:facetDisplayLabel>
        <sru:index>fcs.resource</sru:index>
        <sru:relation>=</sru:relation>        
        <sru:terms>{
                for $hit in $result
                let $id := $hit/data(@cr:resource-pid)
                 
                group by $id
                return <sru:term>
                <sru:actualTerm>{resource:label($id,$project-id)}</sru:actualTerm>
                <sru:query>{$id}</sru:query>
                <sru:requestUrl>?operation=searchRetrieve&amp;query={$orig-query}&amp;x-context={$id}</sru:requestUrl>
                <sru:count>{count($hit)}</sru:count>
            </sru:term>
        }</sru:terms>
    </sru:facet>
</sru:facetedResults>

};

(:declare function fcs:format-record-data($record-data as node(), $data-view as xs:string*, $x-context as xs:string*, $config as item()*, $resource-data as map(*)?) as item()*  {:)
declare function fcs:format-record-data($record-data as node(), $data-view as xs:string*, $x-context as xs:string*, $config as item()*) as item()*  {
    fcs:format-record-data($record-data, $record-data, $data-view, $x-context, $config)
};

(:~ generates the inside of one record according to fcs/Resource.xsd 
fcs:Resource, fcs:ResourceFragment, fcs:DataView 
all based on mappings and parameters (data-view)

@param $orig-sequence-record-data - the node from the original not expanded search result, so that we can optionally navigate outside the base_elem (for resource_fragment or so)
                    if not providable, setting the same data as in $record-data-input works mostly (expect, when you want to move out of the base_elem)
@param $record-data-input the base-element with the match hits inside (marked with exist:match) 
:)
declare function fcs:format-record-data($orig-sequence-record-data as node(), $record-data-input as node(), $data-view as xs:string*, $x-context as xs:string*, $config as item()*) as item()*  {
    
    let $title := index:apply-index($orig-sequence-record-data, "title", $config)
    (: this is (hopefully) temporary FIX: the resource-pid attribute is in fcs-namespace (or no namespace?) on resourceFragment element!  	:)
	let $resource-pid:= ($record-data-input/ancestor-or-self::*[1]/data(@*[local-name()=$config:RESOURCE_PID_NAME]),
	                      index:apply-index($orig-sequence-record-data, "fcs.resource",$config,'match-only'))[1]
	
	let $resource-ref :=   if (exists($resource-pid)) 
	                               then 
	                                   concat('?operation=searchRetrieve&amp;query=fcs.resource="',
	                                           replace(xmldb:encode-uri(replace($resource-pid[1],'//','__')),'__','//'),
	                                           '"&amp;x-context=', $x-context,
	                                           '&amp;x-dataview=title,full',
	                                           '&amp;version=1.2'
	                                           (: rather nohighlight for full resource now
	                                           if (exists(util:expand($record-data)//exist:match/ancestor-or-self::*[@cr:id][1]))
	                                           then '&amp;x-highlight='||string-join(distinct-values(util:expand($record-data)//exist:match/ancestor-or-self::*[@cr:id][1]/@cr:id),',')
	                                           else ():)
	                                         )
	                               else ""
	
(:	let $resource-pid:= util:eval("$record-data-input/ancestor-or-self::*[1]/data(@cr:"||$config:RESOURCE_PID_NAME||")"):)
	let $project-id := cr:resolve-id-to-project-pid($x-context)
    
    (: if no exist:match, take the root of the matching snippet :)
    let $match-ids := if (exists($record-data-input//exist:match/parent::*/data(@cr:id)))
                      then $record-data-input//exist:match/parent::*/data(@cr:id)
                      else $record-data-input/data(@cr:id)
    
    (: if the match is a whole resourcefragment we dont need a lookup, its ID is in the attribute :)   
    let $resourcefragment-pid :=    if ($record-data-input/ancestor-or-self::*[1]/@*[local-name() = $config:RESOURCEFRAGMENT_PID_NAME]) 
                                    then $record-data-input/ancestor-or-self::*[1]/data(@*[local-name() = $config:RESOURCEFRAGMENT_PID_NAME])
                                    else if (exists($match-ids)) then rf:lookup-id($match-ids[1],$resource-pid, $project-id)[1]
                                          else ()
    let $rf :=      if ($record-data-input/@*[local-name()=$config:RESOURCEFRAGMENT_PID_NAME] or empty($match-ids)) 
                    then $record-data-input
                    else rf:lookup($match-ids[1],$resource-pid, $project-id)
                    
    let $rf-entry :=  if (exists($resourcefragment-pid)) then rf:record($resourcefragment-pid,$resource-pid, $project-id) else ()
    let $res-entry := $rf-entry/parent::mets:div[@TYPE=$config:PROJECT_RESOURCE_DIV_TYPE]
	
    let $matches-to-highlight:= (tokenize(request:get-parameter("x-highlight",""),","),$match-ids)
    let $record-data :=  if (exists($matches-to-highlight) and request:get-parameter("x-highlight","") != 'off')
                                then 
(:                                if ($config("x-highlight")="off"):)
                                if ($config instance of map()) 
                                then 
                                    if ($config("x-highlight") = "off") 
                                    then $rf
                                    else fcs:highlight-matches-in-copy($rf, $matches-to-highlight)
                                else fcs:highlight-matches-in-copy($rf, $matches-to-highlight)
                             else $rf
                          
	(: to repeat current $x-format param-value in the constructed requested :)
	let $x-format := request:get-parameter("x-format", $repo-utils:responseFormatXml)
	let $resourcefragment-ref :=   if (exists($resourcefragment-pid)) 
	                               then 
	                                   concat('?operation=searchRetrieve&amp;query=fcs.rf="',
	                                           replace(xmldb:encode-uri(replace($resourcefragment-pid[1],'//','__')),'__','//'),
	                                           '"&amp;x-context=', $x-context,
	                                           '&amp;x-dataview=title,full',
	                                           '&amp;version=1.2',
	                                           if (exists(util:expand($record-data)//exist:match/ancestor-or-self::*[@cr:id][1]))
	                                           then '&amp;x-highlight='||string-join(distinct-values(util:expand($record-data)//exist:match/ancestor-or-self::*[@cr:id][1]/@cr:id),',')
	                                           else ()
	                                         )
	                               else ""
	
    let $kwic := if (contains($data-view,'kwic')) then
                   let $kwic-config := <config width="{$fcs:kwicWidth}"/>
                   let $kwic-html := kwic:summarize($record-data[1], $kwic-config)
                       
                    return 
                        if (exists($kwic-html)) 
                        then  
                            for $match in $kwic-html
                            return (<fcs:c type="left">{$match/span[1]/text()}</fcs:c>, 
                                       (: <c type="left">{kwic:truncate-previous($exp-rec, $matches[1], (), 10, (), ())}</c> :)
                                                      <fcs:kw>{$match/span[2]/text()}</fcs:kw>,
                                                      <fcs:c type="right">{$match/span[3]/text()}</fcs:c>)            	                       
                                       (: let $summary  := kwic:get-summary($exp-rec, $matches[1], $config) :)
                        (:	                               <fcs:DataView type="kwic-html">{$kwic-html}</fcs:DataView>:)
                        
(: DEBUG:                                            <fcs:DataView>{$kwic-html}</fcs:DataView>) :)
                        else (: if no kwic-match let's take first 100 characters 
                                        There c/should be some more sophisticated way to extract most significant info 
                                        e.g. match on the query-field :)
                        substring($record-data[1],1,(2 * $fcs:kwicWidth))                                         
                     else ()
    (: prev-next :)                     
    let $dv-navigation:= if (contains($data-view,'navigation')) then
                            (:let $context-map := fcs:get-mapping("",$x-context, $config)
                          let $sort-index := if (exists($context-map/@sort)) then $context-map/@sort
                                                 else "title":)
                           (: WATCHME: this only works if default-sort and title index are the same :)
                           (:important is the $responsePosition=2 :)
(:                          let $prev-next-scan := fcs:scan(concat($sort-index, '=', $title),$x-context, 1,3,2,1,'text','',$config):)
                                    (: handle also edge situations  
                                        expect maximum 3 terms, on the edges only 2 terms:)
                          (:let $rf-prev := if (count($prev-next-scan//sru:terms/sru:term) = 3
                                            or not($prev-next-scan//sru:terms/sru:term[1]/sru:value = $title)) then
                                                 $prev-next-scan//sru:terms/sru:term[1]/sru:value
                                            else ""
                                                 
                          let $rf-next := if (count($prev-next-scan//sru:terms/sru:term) = 3) then
                                                $prev-next-scan//sru:terms/sru:term[3]/sru:value
                                             else if (not($prev-next-scan//sru:terms/sru:term[2]/sru:value = $title)) then
                                                 $prev-next-scan//sru:terms/sru:term[2]/sru:value
                                            else "" 
                          :)
                          let $rf-prev := $rf-entry/preceding-sibling::mets:div[@TYPE = $config:PROJECT_RESOURCEFRAGMENT_DIV_TYPE][1]
                          let $rf-next := $rf-entry/following-sibling::mets:div[@TYPE = $config:PROJECT_RESOURCEFRAGMENT_DIV_TYPE][1]
                          let $log:= util:log-app("INFO",$config:app-name,("$rf-entry",$rf-entry))
                          let $log:= util:log-app("INFO",$config:app-name,("$rf-prev",$rf-prev))
                          let $log:= util:log-app("INFO",$config:app-name,("$rf-next",$rf-next))
    
                          
                          let $rf-prev-ref := if (exists($rf-prev)) then concat('?operation=searchRetrieve&amp;query=', $config:INDEX_INTERNAL_RESOURCEFRAGMENT, '="', xmldb:encode-uri($rf-prev/data(@ID)), '"&amp;x-dataview=full&amp;x-dataview=navigation&amp;x-context=', $x-context) else ""                                                 
                          let $rf-next-ref:= if (exists($rf-next)) then concat('?operation=searchRetrieve&amp;query=', $config:INDEX_INTERNAL_RESOURCEFRAGMENT, '="', xmldb:encode-uri($rf-next/data(@ID)), '"&amp;x-dataview=full&amp;x-dataview=navigation&amp;x-context=', $x-context) else ""
                           return
                             (<fcs:ResourceFragment type="prev" pid="{$rf-prev/data(@ID)}" ref="{$rf-prev-ref}" label="{$rf-prev/data(@LABEL)}"  />,
                             <fcs:ResourceFragment type="next" pid="{$rf-next/data(@ID)}" ref="{$rf-next-ref}" label="{$rf-next/data(@LABEL)}"  />)
                        else ()
                        
    let $dv-facs :=     if (contains($data-view,'facs')) 
                        then 
(:                            let $facs-uri:=fcs:apply-index ($record-data-input, "facs-uri",$x-context, $config):)
                            let $facs-uri := facs:get-url($resourcefragment-pid, $resource-pid, $project-id)
    				        return <fcs:DataView type="facs" ref="{$facs-uri[1]}"/>
    				    else ()
                     
    let $dv-title := let $title_ := if (exists($title) and not($title='')) then $title else $res-entry/data(@LABEL)||", "||$rf-entry/data(@LABEL) 
    
                    return <fcs:DataView type="title">{$title_[1]}</fcs:DataView>
    
    let $dv-xmlescaped :=   if (contains($data-view,'xmlescaped')) 
                            then <fcs:DataView type="xmlescaped">{util:serialize($record-data,'method=xml, indent=yes')}</fcs:DataView>
                            else ()
    
    (:return if ($data-view = 'raw') then $record-data 
            else <fcs:Resource pid="{$resource-pid}">
                       <fcs:ResourceFragment pid="{$resourcefragment-pid}" ref="{$resourcefragment-ref}">{
                    ($dv-title, $kwic,
                         if ('full' = $data-view or not(exists($kwic))) then <fcs:DataView type="full">{$record-data}</fcs:DataView>
                             else () 
                           )}</fcs:ResourceFragment>
                           {$dv-navigation}
                       </fcs:Resource>:)
                       (:                                        case "full"         return util:expand($record-data):)
    return
        if ($data-view = "raw") 
        then $record-data
        else <fcs:Resource pid="{$resource-pid}" ref="{$resource-ref}">                
                { (: if not resource-fragment couldn't be identified, don't put it in the result, just DataViews directly into Resource :)
                if ($rf-entry) then         
                    <fcs:ResourceFragment pid="{$resourcefragment-pid}" ref="{$resourcefragment-ref}">{
                        for $d in tokenize($data-view,',\s*') 
                        return 
                            let $data:= switch ($d)
    (:                                        case "full"         return $rf[1]/*:)
                                            case "full"         return $record-data[1]/*
                                            case "facs"         return $dv-facs
                                            case "title"        return $dv-title
                                            case "kwic"         return $kwic
                                            case "navigation"   return $dv-navigation
                                            case "xmlescaped"   return $dv-xmlescaped
                                            default             return ()
                             return if ($data instance of element(fcs:DataView)) then $data else <fcs:DataView type="{$d}">{$data}</fcs:DataView>
                    }</fcs:ResourceFragment>
                 else 
                     for $d in tokenize($data-view,',\s*') 
                        return 
                            let $data:= switch ($d)
    (:                                        case "full"         return $rf[1]/*:)
                                            case "full"         return $record-data[1]/*
                                            case "facs"         return $dv-facs
                                            case "title"        return $dv-title
                                            case "kwic"         return $kwic
                                            case "navigation"   return $dv-navigation
                                            case "xmlescaped"   return $dv-xmlescaped
                                            default             return ()
                             return if ($data instance of element(fcs:DataView)) then $data else <fcs:DataView type="{$d}">{$data}</fcs:DataView>
                 }
            </fcs:Resource>

};


declare function fcs:get-pid($mdRecord as element()) {
    let $log := util:log("INFO",name($mdRecord))
    return
    switch (name($mdRecord))
        case "teiHeader" return $mdRecord//(idno|tei:idno)[@type='cr-xq']/xs:string(.)
        case "cmdi" return ()
        default return ()
}; 

(: daniel 2013-06-19 added ignore-base-elem processing :)
(:~ This expects a CQL-query that it translates to XPath

It relies on the external cqlparser-module, that delivers the query in XCQL-format (parse-tree of the query as XML)
and then applies a stylesheet

@params $x-context identifier of a resource/collection
@returns XPath version of the CQL-query, or diagnostics bubbling up the call-chain if parse-error! 
:)
declare function fcs:transform-query($cql-query as xs:string, $x-context as xs:string, $config, $ignore-base-element as xs:boolean) as item() {
    let $mappings := config:mappings($x-context),
        $log := util:log("INFO",$mappings),    
        $xpath-query := cql:cql2xpath($cql-query, $x-context, $mappings),
        $return_match := 
                        let $indexes:=  
                            for $key in cql:cql-to-xcql($cql-query)//searchClause/index
                            return 
                                if (exists($mappings))
                                then $mappings//index[@key eq $key]/@return_match='true'
                                else false()
                        let $some_index_requires_existMatch:=some $x in $indexes satisfies $x=true()
                        return $some_index_requires_existMatch 
    
        (: ignore base_elem if any of the indexes we search in requires this by having @ignore_base_elem='true' on its definition :)
    let $ignore_base_elem := 
                        let $indexes:=  for $key in cql:cql-to-xcql($cql-query)//searchClause/index
                                        return 
                                            if (exists($mappings))
                                            then $mappings//index[@key eq $key]/(@ignore_base_elem='true' or @return_match='true')
                                            else false()
                        let $some_index_requires_ignore:=some $x in $indexes satisfies $x=true()
                        return $some_index_requires_ignore 
    (: if there was a problem with the parsing the query  don't evaluate :)
    let $final-xpath := switch(true())
                            case $return_match
                                return "util:expand("||$xpath-query||")//exist:match"
                                
                            case ($ignore-base-element and ($xpath-query instance of text() or $xpath-query instance of xs:string) and not($ignore_base_elem)) return
                                let $context-map        := fcs:get-mapping("",$x-context, $config),
                                    $default-mappings   := fcs:get-mapping("", 'default', $config )
        (:                    $index-map := $context-map/index[xs:string(@key) eq $index],
                        (\: get either a) the specific base-element for the index, 
                              b) the default for given map,
                              c) the index itself :\)
                            $base-elem := if (exists($index-map/@base_elem)) then xs:string($index-map/@base_elem) 
                                else if (exists($context-map/@base_elem)) then xs:string($context-map/@base_elem)
                                else $index:)                        
                            (:$base-elem := if (exists($context-map[@base_elem])) then
                                                if (not($context-map/@base_elem='')) then
                                                    concat('ancestor-or-self::', $context-map/@base_elem)
                                                 else '.'
                                            else if (exists($default-mappings[@base_elem])) then
                                                concat('ancestor-or-self::', $default-mappings/@base_elem)
                                            else '.'
                                            
                        return concat($xpath-query,'/', $base-elem):)
                        
                                let $base-elem-xpath:=fcs:base-element-to-xpath($cql-query,$x-context,$config,$ignore-base-element)
                                return $xpath-query||'/'||$base-elem-xpath
                            default 
                                return $xpath-query
      return $final-xpath
 };
 
(: daniel 2013-06-19: moved base-element-generation out into its own function :)
declare function fcs:base-element-to-xpath($cql-query as xs:string, $x-context as xs:string, $config, $ignore-base-element as xs:boolean) as xs:string? {
    let $context-map        := fcs:get-mapping("",$x-context, $config),
        $default-mappings   := fcs:get-mapping("", 'default', $config )
    (: daniel 2013-06-12 added parse functionality for map/@base_elem so that we can have
                    - @base_elem='p'
                    - @base_elem='(p|l)'
                    - @base_elem='fn:function(.)'
    :)
    let $base-elem :=   if (exists($context-map[@base_elem])) 
                        then 
                            if (not($context-map/@base_elem='')) 
                            then $context-map/@base_elem
                            else '.'
                        else
                            if (exists($default-mappings[@base_elem])) 
                            then $default-mappings/@base_elem
                            else '.'
    
    let $relativeStep :=            'ancestor-or-self::'
    let $base-elem-isUnion :=       matches($base-elem,'^\(.+\|.+\)$')
    let $base-elem-isFunction :=    matches(replace($base-elem,'\[.*\]',''),'^(\D[\p{L}\p{P}]*:)?(\D[\p{L}\p{P}]+)\(.*\)') 
    let $return:=   
            switch(true())
                case $base-elem-isFunction  return $base-elem
                case $base-elem-isUnion     return "("||string-join(tokenize(replace($base-elem,'[\(\)]',''),'\|')!concat($relativeStep,.),'|')||")"
                default                     return 
                                                if ($base-elem = '.') 
                                                then $base-elem 
                                                else $relativeStep||$base-elem
    return $return
};

(: old version, "manually" parsing the cql-string
it accepted/understood: 
term
index=term
index relation term
:)
declare function fcs:transform-query-old($cql-query as xs:string, $x-context as xs:string, $type as xs:string, $config ) as xs:string {

    let $query-constituents := if (contains($cql-query,'=')) then 
                                        tokenize($cql-query, "=") 
                                   else tokenize($cql-query, " ")    
	let $index := if ($type eq 'scan' or count($query-constituents)>1 )  then $query-constituents[1]
	                else "cql.serverChoice"				 				
	let $searchTerm := if (count($query-constituents)=1) then
							$cql-query
						else if (count($query-constituents)=2) then (: tokenized with '=' :)
						    normalize-space($query-constituents[2])
						else
							$query-constituents[3]

(: try to get a mapping specific to given context, else take the default :)
    let $context-map := fcs:get-mapping("",$x-context, $config),

(: TODO: for every index in $xcql :)
            (: try  to get a) a mapping for given index within the context-map,
                    b) in any of the mapping (if not found in the context-map) , - potentially dangerous!!
                    c) or else take the index itself :)
        $mappings := doc(repo-utils:config-value($config, 'mappings')),   
        $index-map := $context-map/index[xs:string(@key) eq $index],
        $resolved-index := if (exists($index-map)) then $index-map/text()
                           else if (exists($mappings//index[xs:string(@key) eq $index])) then
                                $mappings//index[xs:string(@key) eq $index]
                            else $index       
            ,    
            (: get either a) the specific base-element for the index, 
                  b) the default for given map,
                  c) the index itself :)
        $base-elem := if (exists($index-map/@base_elem)) then xs:string($index-map/@base_elem) 
                        else if (exists($context-map/@base_elem)) then xs:string($context-map/@base_elem)
                        else $index,
            (: <index status="indexed"> - flag to know if ft-indexes can be used.
            TODO?: should be checked against the actual index-configuration :)
        $indexed := (xs:string($index-map/@status) eq 'indexed'),
        $match-on := if (exists($index-map/@use) ) then xs:string($index-map/@use) else '.'  
        
	let $res := if ($type eq 'scan') then
	                   concat("//", $resolved-index, if ($match-on ne '.') then concat("/", $match-on) else '') 
	               else
	                   concat("//", $resolved-index, "[", 
	                                       if ($indexed) then 
	                                               concat("ft:query(", $match-on, ",<term>",translate($searchTerm,'"',''), "</term>)")
	                                           else 
	                                               concat("contains(", $match-on, ",'", translate($searchTerm,'"',''), "')")
	                                        , "]",
								"/ancestor-or-self::", $base-elem)		
				    

	return $res

};

(:~ gets the mapping-entry for the index

first tries a mapping within given context, then tries defaults.

if $index-param = "" return the map-element, 
    else - if found - return the index-element 
:)
declare function fcs:get-mapping($index as xs:string, $x-context as xs:string+, $config)  {
    let $mappings :=    typeswitch($config)
                            case element()  return config:param-value(map{"config":=$config}, 'mappings')
                            case map()      return config:param-value($config, 'mappings')
                            default         return $config[descendant-or-self::map],
        $context-map := if (exists($mappings//map[@key = $x-context])) 
                        then $mappings//map[@key = $x-context]
(:                            else $mappings//map[xs:string(@key) = 'default'],:)
     (: if not specific mapping found for given context, use whole mappings-file :)
                        else $mappings,
    $context-index := $context-map/index[@key eq $index],
    $default-index := $mappings//map[@key = 'default']/index[@key eq $index]
    
    
    return  if ($index eq '') 
            then $context-map
            else 
                if (exists($context-index)) 
                then $context-index
                else 
                    if (exists($default-index)) 
                    then $default-index
                    else (: if no contextual index, dare to take any index - may be dangerous!  :)
                        let $any-index := $mappings//index[xs:string(@key) eq $index]
                        return $any-index
};


declare function fcs:indexes-in-query($cql as xs:string, $x-context as xs:string+, $config) as node()* {
    
    let $xcql := cql:cql-to-xcql($cql)
    let $indexes := for $ix in $xcql//index[not(ancestor::sortKeys)]
                        return fcs:get-mapping($ix, $x-context, $config)
                        
    return $indexes                       
    

};

declare function fcs:declare-index-function($x-context, $index-name, $config) as xs:string?{
    let $index-as-xpath:=fcs:index-as-xpath($index-name,$x-context, $config)
    return 
        "declare function "||$x-context||":"||$index-name||"($data) as item()* {&#10;"||
            "&#09;$data//"||$index-as-xpath||"&#10;"||
        "};&#10;&#10;"
};

declare function fcs:store-project-index-functions($x-context) {
    let $preamble:="xquery version '3.0';",
        $namespace:="module namespace "||$x-context||"="||$fcs:project-index-functions-ns-base-uri||$x-context||"';"
    let $config:=   map{"config":=config:project-config($x-context)},
        $mappings:= config:param-value($config,'mappings')
    let $defs:=     for $index in $mappings//index return fcs:declare-index-function($x-context,$index/@key,$config)
    let $path:=     $config:modules-dir||"index-functions/",
        $resource:= $x-context||".xqm",
        $store:=    xmldb:store($path, $resource, string-join(($preamble,$namespace,$defs),'&#10;&#10;'), 'application/xquery'),
        $chmod:=    if ($store!='') then xmldb:set-resource-permissions($path,$resource,$x-context,$x-context,util:base-to-integer(0755, 8)) else () 
    return exists($chmod)
};


declare function fcs:import-project-index-functions($x-context) { util:import-module(xs:anyURI($fcs:project-index-functions-ns-base-uri||$x-context),$x-context,xs:anyURI($config:modules-dir||"index-functions/"||$x-context||".xqm"))
};

(:~ 
TO BE DEPRECATED BY index:apply-index()
evaluate given index on given piece of data
used when formatting record-data, to put selected pieces of data (indexes) into the results record 

@returns result of evaluating given index's path on given data. or empty node if no mapping index was found
:)
declare function fcs:apply-index($data, $index as xs:string, $x-context as xs:string+, $config) as item()* {
    let $index-map := fcs:get-mapping($index,$x-context, $config),
        $index-xpath := fcs:index-as-xpath($index,$x-context, $config)
    
(:    $match-on := if (exists($index-map/@use) ) then concat('/', xs:string($index-map[1]/@use)) else ''
, $match-on:)   
    return
        if (exists($index-map/path/text())) 
        then 
            let $plain-eval:=util:eval("$data//"||$index-xpath)
            return 
                if (exists($plain-eval))
                then $plain-eval
                else util:eval("util:expand($data)//"||$index-xpath)
        else () 
};

declare function fcs:apply-index($data, $index as xs:string, $x-context as xs:string+) as item()* {
    let $project-config:= project:get($x-context)
    return fcs:apply-index($data,$index,$x-context,$project-config)
};

(:~ 
TO BE DEPRECATED BY index:index-as-xpath()

gets the mapping for the index and creates an xpath (UNION)

FIXME: takes just first @use-param - this prevents from creating invalid xpath, but is very unreliable wrt to the returned data
       also tried to make a union but problems with values like: 'xs:string(@value)' (union operand is not a node sequence [source: String])

@param $index index-key as known to mappings 

@returns xpath-equivalent of given index as defined in mappings; multiple xpaths are translated to a UNION, 
           value of @use-attribute is also attached;  
         if no mapping found, returns the input-index unchanged 
:)
declare function fcs:index-as-xpath($index as xs:string, $x-context as xs:string+, $config) as xs:string {    
    let $index-map := fcs:get-mapping($index, $x-context, $config)        
    return if (exists($index-map)) then
       (:                 let $match-on := if (exists($index-map/@use) ) then 
                                            if (count($index-map/@use) > 1) then  
                                               concat('/(', string-join($index-map/@use,'|'),')')
                                            else concat('/', xs:string($index-map/@use)) 
                                         else '' :)
                                  let $match-on := if (exists($index-map/@use) ) then concat('/', xs:string($index-map[1]/@use)) else ''
                        let $paths := $index-map/path[not(@type) or xs:string(@type)='key']
(:                        let $paths := $index-map/path:)
                        let $indexes := if (count($paths) > 1) 
                                        then translate(concat('(', string-join($paths ,'|'),')', $match-on),'.','/')
                                        else translate(concat($paths, $match-on),'.','/')
                           return $indexes
                  else $index
    
};

(:~ this is to mark matched-element, even if usual index-matching-mechanism fails (which is when matching on attributes) 
:)

declare function fcs:highlight-result($result as node()*, $match as node()*, $x-context as xs:string+, $config) as item()* {
    
    let $default-expand := util:expand($result)
    
(:    let $indexes := fcs:indexes-in-query($query, $x-context, $config):)
    
    (: if the kwic-module already did its work, just give that back, 
            else use the custom highlighting:) 
     
    (:problematic performance:)
    let $processed-result := if (exists($default-expand//exist:match)) then $default-expand
                               else fcs:process-result($result, $match)
(:  do-nothing pass-through variant :)
(:      let $processed-result := $default-expand                               :)
(:                    else  :)
                     (: "highlight-matches=elements"):)
    
    return $processed-result                               
};

(:~ this is to mark matched element, even if usual index-matching-mechanism fails (which is when matching on attributes)
it recursively processes the result 
and sets a <exist:match> element (-a-r-o-u-n-d) INSIDE the matching elements
(because it is important for the further processing to keep the matching element)
it still strips the inner elements (descendants) and only leaves the .//text() . 

@param $result the result containing the matched elements, but somewhere inside the ancestors (base-elem)
@param $matching the list of directly matched elements, that are contained in the $result somewhere

:)
declare function fcs:process-result($result as node()*, $matching as node()*) as item()* {
  for $node in $result
    return  typeswitch ($node)
        case text() return $node
        case comment() return $node
        (:case element() return  if ($node = $matching) then <exist:match>{fcs:process-result-default($node, $matching )}</exist:match>:)
                            
        case element() return  if ($node = $matching) then 
                                element {node-name($node)} {$node/@*, 
                                            <exist:match>{string-join($node//text(), ' ')}</exist:match>}
                    else  fcs:process-result-default($node, $matching )
        default return fcs:process-result-default($node, $matching )
(:namespace prefix-from-QName($node/name()) {$node/namespace-uri()} ,:)
    };

declare function fcs:process-result-default($node as node(), $matching as node()*) as item()* {
  element {node-name($node)} {($node/@*, fcs:process-result($node/node(), $matching))}
(:  namespace {$node/namespace-uri()}, :)
  (: <div class="default">{$node/name()} </div> :)  
 };

(:~ dynamically sort result based on query (CQL: sortBy clause) or default sorting defined in mappings
if unable to find any sorting index, return the result as is.
<sortKeys>
<key>
<index>dc.date</index>
<modifiers>
<modifier>
<type>sort.descending</type>
</modifier>
</modifiers>
</key>
<key>
<index>dc.title</index>
<modifiers>
<modifier>
<type>sort.ascending</type>
</modifier>
</modifiers>
</key>
</sortKeys>
:)
declare function fcs:sort-result($result as node()*, $cql as xs:string, $x-context as xs:string+, $config) as item()* {

  let $xcql := cql:cql-to-xcql($cql)
  let $indexes := if (exists($xcql//sortKeys/key/index)) then
                        $xcql//sortKeys/key/index
                      else 
                          let $context-map := fcs:get-mapping("",$x-context, $config)
                          return if (exists($context-map/@sort)) then $context-map/@sort
                                    else ()
                        
    let $xpaths := for $ix in $indexes                         
                        return fcs:index-as-xpath($ix,$x-context, $config )
                                 
   let $sorting-expression := string-join(("for $rec in $result order by ",
                                    for $index at $pos in $xpaths
                                        let $modifier := substring-after ($indexes[position()=$pos]/following-sibling::modifiers/modifier/type, 'sort.')
                                    return 
                                        ("$rec//", $index, " ", $modifier, if ($pos = count($xpaths)) then '' else ', '),
                                    " return $rec"                                      
                                    ), '')                                   
   return if (count($indexes) = 0) then $result
                else util:eval($sorting-expression)
(:                else $sorting-expression:)

};

declare function fcs:highlight-matches-in-copy($copy as element()+, $ids as xs:string*) as element()+ {
    let $stylesheet-file := "highlight-matches.xsl",
        $stylesheet:=   doc($stylesheet-file),
        $params := <parameters><param name="cr-ids" value="{string-join($ids,',')}"></param></parameters>
   return 
            if (exists($stylesheet)) 
            then 
                for $c in $copy
                return transform:transform($copy,$stylesheet,$params) 
            else util:log("ERROR","stylesheet "||$stylesheet-file||" not available.")
}; 
