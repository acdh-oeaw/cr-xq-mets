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
(:import module namespace cql = "http://exist-db.org/xquery/cql" at "../query/cql.xqm";:)
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
declare variable $fcs:flattenKwicXsl := doc(concat(system:get-module-load-path(),'/flatten-kwic.xsl'));
declare variable $fcs:kwicWidth := 40;
declare variable $fcs:filterScanMinLength := 2;
(: this limit is introduced due to performance problem >50.000?  nodes (100.000 was definitely too much) :)  
declare variable $fcs:maxScanSize:= 100000;


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
      	 let 
(:      	 $cql-query := $query,:)
			$start-item := request:get-parameter("startRecord", 1),
			$max-items := request:get-parameter("maximumRecords", 50),
			$x-dataview := request:get-parameter("x-dataview", repo-utils:config-value($config, 'default.dataview'))
            
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
            fcs:search-retrieve($query, $x-context, xs:integer($start-item), xs:integer($max-items), $x-dataview, $config)
    else 
      diag:diagnostics('unsupported-operation',$operation)
    
   return  repo-utils:serialise-as($result, $x-format, $operation, $config)
   
};

(:~ handles the explain-operation requests.
: @param $x-context optional, identifies a resource to return the explain-record for. (Accepts both MD-PID or Res-PID (MdSelfLink or ResourceRef/text))
: @returns either the default root explain-record, or - when provided with the $x-context parameter - the explain-record of given resource
:)
declare function fcs:explain($x-context as xs:string*, $config) as item()* {

    let $md-dbcoll := collection(repo-utils:config-value($config,'metadata.path'))
    
    let $context-mapping := index:map($x-context),
     (: if not specific mapping found for given context, use whole mappings-file
        this currently happens already in the get-mapping function 
          $mappings := if ($context-mapping/xs:string(@key) = $x-context) then $context-mapping 
                    else doc(repo-utils:config-value($config, 'mappings')):)
        $mappings := $context-mapping

    let $server-host :=  config:param-value($config, "base-url"), 
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
            let $ix-label := ($index/xs:string(@label),$ix-key)[1]
(: rather retain explicit order           order by $ix-key:)
            return
                <zr:index search="true" scan="{($index/data(@scan), 'false')[1]}" sort="false">
                <zr:title lang="en">{$ix-label}</zr:title>
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
        $dummy2 := util:log-app("DEBUG", $config:app-name, "is in cache: "||repo-utils:is-in-cache($index-doc-name, $config) ),
        $log := (util:log-app("DEBUG", $config:app-name, "cache-mode: "||$mode),
                util:log-app("DEBUG", $config:app-name, "scan-clause="||$scan-clause),
                util:log-app("DEBUG", $config:app-name, "x-context="||$x-context),
                util:log-app("DEBUG", $config:app-name, "start-item="||$start-item),
                util:log-app("DEBUG", $config:app-name, "max-items="||$max-items),
                util:log-app("DEBUG", $config:app-name, "max-depth="||$max-depth),
                util:log-app("DEBUG", $config:app-name, "p-sort="||$p-sort)
        ),
  (: get the base-index from cache, or create and cache :)
  $index-scan :=
        (: scan overall existing indices, do NOT store the result! :)        
        if ($index-name= 'cql.serverChoice') then 
                    fcs:scan-all($x-context, $filter, $config)
        else
        if (repo-utils:is-in-cache($index-doc-name, $config) and not($mode='refresh')) then
          let $dummy := util:log-app("DEBUG", $config:app-name, "reading index "||$index-doc-name||" from cache")
          return repo-utils:get-from-cache($index-doc-name, $config)            
        else
        (: TODO: cmd-specific stuff has to be integrated in a more dynamic way! :)
            let $dummy := util:log-app("DEBUG", $config:app-name, "generating index "||$index-doc-name)
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
	let $res-nodeset :=  if ($index-name= 'cql.serverChoice') then
	                           $index-scan
	                    else transform:transform($index-scan,$fcs:indexXsl, 
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

(:~ delivers matching(!) terms from all indexes marked as scan=true(!) 
    to prevent too many records results are only returned, when the filter is at least $fcs:filterScanMinLength (current default=2)  
:)
declare function fcs:scan-all($project as xs:string, $filter as xs:string, $config ) as item()* {
(:  let $indexes :=  collection(project:path("abacus","indexes")):)
        
  let $indexes := for $ix in index:map($project)//index[@scan='true']    
                              let $index-doc-name := repo-utils:gen-cache-id("index", ($project, $ix/xs:string(@key), 'text', 1))
                             return repo-utils:get-from-cache($index-doc-name, $config)
  
  let $terms := if (string-length($filter) >= $fcs:filterScanMinLength) then
                    $indexes//sru:value[ft:query(., $filter)]/parent::sru:term union $indexes//sru:displayTerm[ft:query(., $filter)]/parent::sru:term
                  else ()
            (: get rid of nested terms  and adding cr:type :)
   let $terms-pruned := for $t in $terms
                                let $type := if (exists($t/sru:extraTermData/cr:type)) then () (: it will be copied anyhow :)
                                                else <cr:type>{root($t)//sru:scanClause/text()}</cr:type> (: add if not provided :)
                                let $extraTermData := 
                                       <sru:extraTermData>{($t/sru:extraTermData/*[not(local-name()='terms')], $type)}</sru:extraTermData>                                 
                               return
                                <sru:term>{($t/@*, $t/*[not(local-name()='extraTermData')], $extraTermData) }</sru:term>
    let $dummy-log := util:log-app("DEBUG", $config:app-name, "terms/pruned:"||count($terms)||"/"||count($terms-pruned))
    
  return 
        <sru:scanResponse xmlns:fcs="http://clarin.eu/fcs/1.0">
            <sru:version>1.2</sru:version>
            <sru:terms>
            {$terms-pruned}
            </sru:terms>
            <sru:extraResponseData>
                
             </sru:extraResponseData>
            <sru:echoedScanRequest>
                <sru:scanClause>cql.serverChoice={$filter}</sru:scanClause>
                <sru:maximumTerms/>
            </sru:echoedScanRequest>
        </sru:scanResponse>
(:        <fcs:countTerms level="top">{count($terms)}</fcs:countTerms>
                <fcs:countTerms level="total">{count($terms//sru:term)}</fcs:countTerms>:)
};

declare function fcs:do-scan-default($index as xs:string, $x-context as xs:string, $sort as xs:string, $config) as item()* {
    let $ts0 := util:system-dateTime()
    let $project-pid := repo-utils:context-to-project-pid($x-context,$config)
    let $facets := index:facets($index,$project-pid)
(:    let $path := index:index-as-xpath($scan-clause,$project-pid):)
    (:let $data-collection := repo-utils:context-to-collection($x-context, $config),
        $nodes := util:eval("$data-collection//"||$path):)
(:    let $context-parsed := repo-utils:parse-x-context($x-context,$config):)
    let $data := repo-utils:context-to-data($x-context,$config),
    (: this limit is introduced due to performance problem >50.000?  nodes (100.000 was definitely too much) :)
(:        $nodes := subsequence(util:eval("$data//"||$path),1,$fcs:maxScanSize):)
        $nodes := index:apply-index($data, $index,$project-pid,())
        
    let $terms :=
        if ($nodes) then 
            if ($facets/index)
                then fcs:group-by-facet($nodes, $sort, $facets/index, $project-pid)
                else fcs:term-from-nodes($nodes, $sort, $index, $project-pid)
           else ()
    let $ts1 := util:system-dateTime()
    let $dummy2 := util:log-app("DEBUG", $config:app-name, "fcs:do-scan-default: index: "||$index||", duration:"||($ts1 - $ts0))        
    return 
        <sru:scanResponse xmlns:fcs="http://clarin.eu/fcs/1.0">
            <sru:version>1.2</sru:version>
            {$terms}
            <sru:extraResponseData>
                <fcs:countTerms level="top">{count($terms)}</fcs:countTerms>
                <fcs:countTerms level="total">{count($terms//sru:term)}</fcs:countTerms>
             </sru:extraResponseData>
            <sru:echoedScanRequest>
                <sru:scanClause>{$index}</sru:scanClause>
                <sru:maximumTerms/>
            </sru:echoedScanRequest>
        </sru:scanResponse>
};

(:%private :)
declare function fcs:term-from-nodes($nodes as item()+, $order-param as xs:string, $index-key as xs:string, $project-pid as xs:string) {
    let $ts0 := util:system-dateTime()
    let $dummy := util:log-app("DEBUG", $config:app-name, "fcs:term-from-nodes: "||$index-key)
    let $termlabels := project:get-termlabels($project-pid,$index-key)
    (:let $data :=  for $n in $node
                    let $term-value := index:apply-index($n,$index-key,$project-pid,'match-only')                                                    
                    return $term-value
    :)                
    (:let $data :=  for $n in $node
                    let $term-value := index:apply-index($n,$index-key,$project-pid,'match-only'),
                        $value-map := map:entry("value",$term-value)
                    let $term-label := fcs:term-to-label($term-value,$index-key,$project-pid,$termlabels)
                    let $label-value := if ($term-label) then $term-label
                                        else string-join(index:apply-index($n,$index-key,$project-pid,'label-only'),'')                                    
                            (\:switch(true())
                                case ($term-label!='') return $term-label
                                case ($label-path!='') return string-join(util:eval("$n/"||$label-path),'')
                                default return $term-value:\)                            
                    let $label-map := map:entry("label",$label-value)                            
                    return map:new(($value-map,$label-map)):)
    let $ts1 := util:system-dateTime()     
    (: since an expression like  
        group by $x 
        let $y 
        order by $y 
     is not possible in eXist (although a xquery 3.0 use case cf. http://www.w3.org/TR/xquery-30-use-cases/#groupby_q6) we have to separated 
     the group operation from the sort operation here     
    :)
    let $terms-unordered :=           
        for $g at $pos in $nodes
        let $term-value-g := string-join(index:apply-index($g,$index-key,$project-pid,'match-only'),' ')
        group by $term-value-g 
        return
            let $m-value := map:entry("value",$term-value-g),
                $m-count := map:entry("count",count($g)),
                $firstOccurence := map:entry("firstOccurence",$g[1])
            return map:new(($m-value,$m-count,$firstOccurence))
    let $terms := 
            for $t in $terms-unordered
            let $t-value := $t("value"),
                $t-count := $t("count"),
                $firstOccurence := $t("firstOccurence"),
                $label := 
                    let $term-label := string-join(fcs:term-to-label($t-value,$index-key,$project-pid,$termlabels),'')
                    return
                        if ($term-label) 
                        then $term-label[1]
                        else string-join(index:apply-index($firstOccurence,$index-key,$project-pid,'label-only'),'')
            order by 
                if ($order-param='size') then $t-count else true() descending,
                if ($order-param='text') then $label else true() ascending
                 collation "?lang=de-DE"
            return map:new((map:entry("value",$t-value),map:entry("count",$t-count),map:entry("label",$label)))
            
   let $ts2 := util:system-dateTime()
   let $dummy2 := util:log-app("DEBUG", $config:app-name, "fcs:term-from-nodes: after ordering; index: "||$index-key||", duration:"||($ts2 - $ts1))
    return <sru:terms> 
        {
        for $term at $pos in $terms
        return <sru:term>
                    <sru:value>{$term("value")}</sru:value>
                    <sru:displayTerm>{$term("label")}</sru:displayTerm>
                    <sru:numberOfRecords>{$term("count")}</sru:numberOfRecords>
                    <sru:extraTermData>
                        <fcs:position>{$pos}</fcs:position>
                    </sru:extraTermData>
                </sru:term>
                }
                </sru:terms>
};



declare %private function fcs:group-by-facet($data as node()*,$sort as xs:string, $index as element(index), $project-pid) as item()* {
    let $index-key := $index/xs:string(@key)
        (:$match:= index:index-as-xpath($key,$project-pid,'match-only'),
        $label-path := index:index-as-xpath($key,$project-pid,'label-only'):)
    let $termlabels := project:get-termlabels($project-pid,$index-key)     
    let $groups := 
        let $maps := 
            for $x in $data 
(:            let $g := util:eval("$x/"||$match)[1]:)
              let $g := index:apply-index ($x, $index-key, $project-pid,'match-only')
            group by $g 
            return if (exists($g)) then map:entry(($g)[1],$x)
        else ()
        let $map := map:new($maps)
        return $map
    
    return
     <sru:terms> {
        for $group-key in map:keys($groups)
        let $entries := map:get($groups, $group-key)
        (:let $label :=  if ($label-path='') 
                            then fcs:term-to-label($group-key, $key,$project-pid)
                            else data(util:eval("$entries[1]/"||$label-path)):)
(:         let $label := (fcs:term-to-label($group-key,$key,$project-pid), data(util:eval("$entries[1]/"||$label-path)))[1]:)
         let $term-label := fcs:term-to-label($group-key,$index-key,$project-pid,$termlabels)
         let $label := if ($term-label) then $term-label
                                        else index:apply-index($entries[1],$index-key,$project-pid,'label-only')
        let $count := count($entries)
        let $dummy := util:log-app("DEBUG", $config:app-name, "fcs:group by facet: "||$group-key||"##"||$index-key||"##"||$label||" count-group: "||$count)
        order by
            if ($sort='size') then $count else true() descending,
            if ($sort='text') then $label else true() ascending            
        return
            <sru:term>
                <sru:displayTerm>{$label}</sru:displayTerm>
                <sru:value>{$group-key}</sru:value>
                <sru:numberOfRecords>{$count}</sru:numberOfRecords>
                <sru:extraTermData>
                    <cr:type>{$index-key}</cr:type>
                    {if ($index/index)
                    then fcs:group-by-facet($entries, $sort, $index/index, $project-pid)
                    else fcs:term-from-nodes($entries, $sort, root($index)/index/@key, $project-pid)}
                </sru:extraTermData>
            </sru:term>
            } </sru:terms>
};

(:~ lookup a label to a term using a freshly loaded the projects termlabel map 
you really should try to use the second method with termlabels already resolved
it spears you a lot of time  
:)
(:%private :)
declare function fcs:term-to-label($term as xs:string?, $index as xs:string, $project-pid as xs:string) as xs:string?{
    
(:    return ($labels//term[@key=$term][ancestor::*/@key=$index],$term)[1]:)
    if ($term) then 
            let $termlabels := project:get-termlabels($project-pid)
            return fcs:term-to-label($term,$index,$project-pid, $termlabels)
         else  ()
};

(:~ lookup a label to a term using the termlabel map passed as argument
this is the preferred method, the resolution of the projects termlabels map should happen before the scan loop, 
to prevent repeated lookup of this map, which has serious performance impact
:)
(:%private :)
declare function fcs:term-to-label($term as xs:string?, $index as xs:string, $project-pid as xs:string, $termlabels) as xs:string?{
    
(:    return ($labels//term[@key=$term][ancestor::*/@key=$index],$term)[1]:)
    if ($term and $termlabels) then 
            $termlabels//term[@key=$term][ancestor::*/@key=$index]
         else  ()
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
                     else repo-utils:context-map-to-data($context-parsed,$config)
        
        let $xpath-query := query:query-to-xpath($query,$project-id)
        
         (: ! results are only actual matching elements (no wrapping base_elem, i.e. resourcefragments ! :)
        let $result-unfiltered:= query:execute-query ($query,$data,$project-id)                         
        (: filter excluded resources or fragments unless this is a direct fragment request :)
        let $result := 
                if (contains($query,$config:INDEX_INTERNAL_RESOURCEFRAGMENT))
                then $result-unfiltered
                else repo-utils:filter-by-context($result-unfiltered,$context-parsed,$config)
        let	$result-count := fn:count($result),
            $facets := if (contains($x-dataview,'facets') and $result-count > 1) then fcs:generateFacets($result, $query) else (),
(:  temporarily deactivated during the cleanup of fcs 2014-08-22
$ordered-result := fcs:sort-result($result, $query, $x-context, $config),                              
            $result-seq := fn:subsequence($ordered-result, $startRecord, $maximumRecords),:)
            $result-seq := fn:subsequence($result, $startRecord, $maximumRecords),
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
    
    let $title := index:apply-index($orig-sequence-record-data, "title", $x-context)
    (: this is (hopefully) temporary FIX: the resource-pid attribute is in fcs-namespace (or no namespace?) on resourceFragment element!  	:)
	let $resource-pid:= ($record-data-input/ancestor-or-self::*[1]/data(@*[local-name()=$config:RESOURCE_PID_NAME]),
(:	                      index:apply-index($orig-sequence-record-data, "fcs.resource",$config,'match-only'))[1]:)
	                      index:apply-index($orig-sequence-record-data, "fcs.resource",$x-context,'match-only'))[1]
	
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
    (: HERE we are losing  the exist:match, when looking up the resource fragment :)
    let $rf :=      if ($record-data-input/@*[local-name()=$config:RESOURCEFRAGMENT_PID_NAME] or empty($match-ids)) 
                    then $record-data-input
                    else rf:lookup($match-ids[1],$resource-pid, $project-id)
                    
(:    let $dumy := util:log-app("INFO",$config:app-name,("$record-data-input:",$record-data-input))                    :)
(:    let $dumy2 := util:log-app("INFO",$config:app-name,("$match-ids:",$match-ids)):)
    let $rf-entry :=  if (exists($resourcefragment-pid)) then rf:record($resourcefragment-pid,$resource-pid, $project-id)
    else ()
    let $res-entry := $rf-entry/parent::mets:div[@TYPE=$config:PROJECT_RESOURCE_DIV_TYPE]
	
    let $matches-to-highlight:= (tokenize(request:get-parameter("x-highlight",""),","),$match-ids)
    let $record-data := 
    (: not sure if to work with $record-data-input or $rf :)
    if (exists($matches-to-highlight) and request:get-parameter("x-highlight","") != 'off')
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
                   
                   (: tentatively kwic-ing from original input - to get the closest match
                    however this fails when matching on attributes, where the exist:match is only added in the highlighting function,
                    thus we need the processed record-data :)
(:                   let $kwic-html := kwic:summarize($record-data-input, $kwic-config):)
                 let $flattened-record := transform:transform($record-data[1], $fcs:flattenKwicXsl,())
(:                 let $flattened-record := repo-utils:serialise-as($record-data[1], 'html', $fcs:searchRetrieve, $config):)
                 let $kwic-html := kwic:summarize($flattened-record, $kwic-config)
                       
                    return 
                        if (exists($kwic-html)) 
                        then  
                            for $match at $pos in $kwic-html
                            (: when the exist:match is complex element kwic:summarize leaves the keyword (= span[2]) empty, 
                            so we try to fall back to the exist:match :)
                            let $kw := if (exists($match/span[2][text()])) then $match/span[2]/text() else $record-data[1]//exist:match[$pos]//text() 
                            return (<fcs:c type="left">{$match/span[1]/text()}</fcs:c>, 
                                       (: <c type="left">{kwic:truncate-previous($exp-rec, $matches[1], (), 10, (), ())}</c> :)
                                                      <fcs:kw>{$kw}</fcs:kw>,
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

    let $dv-cite := if (contains($data-view,'cite')) then
                        if ($rf-entry) then rf:cite($resourcefragment-pid, $resource-pid, $project-id, $config)
                            else resource:cite($resource-pid, $project-id, $config)
                       else ()
    
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
                                        case "cite"        return $dv-cite
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
                                            case "cite"        return $dv-cite
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


declare function fcs:highlight-matches-in-copy($copy as element()+, $ids as xs:string*) as element()+ {
    let $stylesheet-file := "highlight-matches.xsl",
        $stylesheet:=   doc($stylesheet-file),
        $params := <parameters><param name="cr-ids" value="{string-join($ids,',')}"></param></parameters>
   return 
(:   $copy:)
            if (exists($stylesheet)) 
            then 
                for $c in $copy
                return transform:transform($copy,$stylesheet,$params) 
            else util:log("ERROR","stylesheet "||$stylesheet-file||" not available.")
}; 

