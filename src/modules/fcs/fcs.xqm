xquery version "3.0";
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
import module namespace functx="http://www.functx.com";

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
declare variable $fcs:defaultMaxTerms := 50;
declare variable $fcs:defaultMaxRecords := 10;


(:~ The main entry-point. Processes request-parameters
regards config given as parameter + the predefined sys-config
@returns the result document (in xml, html or json)
:)
(: declare function fcs:repo($config-file as xs:string) as item()* { :)
declare function fcs:main($config) as item()* {
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
      if ($operation[1] eq $fcs:explain) then
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
(:		    protocol defines startTerm as the term in the scanClause
            $start-term := request:get-parameter("startTerm", 1),  :)
		    $response-position := request:get-parameter("responsePosition", 1),
		    $max-terms := request:get-parameter("maximumTerms", $fcs:defaultMaxTerms),
	        $x-filter := request:get-parameter("x-filter", ''),
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
		              fcs:scan($scanClause, $x-context, $max-terms, $response-position, $max-depth, $x-filter, $sort, $mode, $config) 
      (: return fcs:scan($scanClause, $x-context) :)
	  else if ($operation eq $fcs:searchRetrieve) then
        if ($query eq "") then <sru:searchRetrieveResponse><sru:version>1.2</sru:version><sru:numberOfRecords>0</sru:numberOfRecords>
                                {diag:diagnostics("param-missing", "query")}</sru:searchRetrieveResponse>
        else 
      	 let 
(:      	 $cql-query := $query,:)
			$start-record:= request:get-parameter("startRecord", 1),
			$maximum-records  := request:get-parameter("maximumRecords", $fcs:defaultMaxRecords),
			$x-dataview := request:get-parameter("x-dataview", repo-utils:config-value($config, 'default.dataview'))
            
            return 
            if (not($recordPacking = ('string','xml'))) then 
                        <sru:searchRetrieveResponse><sru:version>1.2</sru:version><sru:numberOfRecords>0</sru:numberOfRecords>
                                {diag:diagnostics("unsupported-record-packing", $recordPacking)}</sru:searchRetrieveResponse>
                else if (not(number($maximum-records)=number($maximum-records)) or number($maximum-records) < 0 ) then
                        <sru:searchRetrieveResponse><sru:version>1.2</sru:version><sru:numberOfRecords>0</sru:numberOfRecords>
                                {diag:diagnostics("unsupported-param-value", "maximumRecords")}</sru:searchRetrieveResponse>
                else if (not(number($start-record)=number($start-record)) or number($start-record) <= 0 ) then
                        <sru:searchRetrieveResponse><sru:version>1.2</sru:version><sru:numberOfRecords>0</sru:numberOfRecords>
                                {diag:diagnostics("unsupported-param-value", "startRecord")}</sru:searchRetrieveResponse>
                else
            fcs:search-retrieve($query, $x-context, xs:integer($start-record), xs:integer($maximum-records), $x-dataview, $config)
    else 
      diag:diagnostics('unsupported-operation',$operation)
    
   return  repo-utils:serialise-as($result, $x-format, $operation, $config, $x-context, ())
   
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
declare function fcs:scan($scan-clause  as xs:string, $x-context as xs:string+, $max-terms as xs:integer, $response-position as xs:integer, $max-depth as xs:integer, $x-filter as xs:string?, $p-sort as xs:string?, $mode as xs:string?, $config) as item()? {

  let $scx := tokenize($scan-clause,'='),
	 $index-name := $scx[1],  
	 (:$index := fcs:get-mapping($index-name, $x-context, $config ), :)
	 (: if no index-mapping found, dare to use the index-name as xpath :) 
     (:$index-xpath := index:index-as-xpath($index-name,$x-context),:)
     (: 
      from the protocol spec:
      The term [from the scan clause] is the position within the ordered list of terms at which to start, and is referred to as the start term.       :)
 	 $start-term:= ($scx[2],'')[1],	 
	 $sort := if ($p-sort eq $fcs:scanSortText or $p-sort eq $fcs:scanSortSize) then $p-sort else $fcs:scanSortText	
	 
	 let $sanitized-xcontext := repo-utils:sanitize-name($x-context) 
	 let $project-id := if (config:project-exists($x-context)) then $x-context else cr:resolve-id-to-project-pid($x-context)
    let $index-doc-name := repo-utils:gen-cache-id("index", ($sanitized-xcontext, $index-name, $sort, $max-depth)),
        $dummy2 := util:log-app("DEBUG", $config:app-name, "is in cache: "||repo-utils:is-in-cache($index-doc-name, $config) ),
        $log := (util:log-app("DEBUG", $config:app-name, "cache-mode: "||$mode),
                util:log-app("DEBUG", $config:app-name, "scan-clause="||$scan-clause),
                util:log-app("DEBUG", $config:app-name, "x-context="||$x-context),
                util:log-app("DEBUG", $config:app-name, "x-filter="||$x-filter),
                util:log-app("DEBUG", $config:app-name, "max-terms="||$max-terms),
                util:log-app("DEBUG", $config:app-name, "max-depth="||$max-depth),
                util:log-app("DEBUG", $config:app-name, "p-sort="||$p-sort)
        ),
  (: get the base-index from cache, or create and cache :)
  $index-scan :=
        (: scan overall existing indices, do NOT store the result! :)        
        if ($index-name= 'cql.serverChoice') then
        (: FIXME: the start-term/x-filter is temporary hack until the client-side adapts the new param-semantics :) 
                    fcs:scan-all($x-context, ($start-term, $x-filter)[1], $config)
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
                    
                    (: if no data was retrieved ($metsdivs empty) pass at least an empty element, so that the basic envelope gets rendered 
                    FIXME: actually this should return an empty envelope without any sru:term if there is no data (now it is one) :)
                    return transform:transform(($metsdivs,<mets:div/>)[1],$xsl,())
(:                    return $context-map:)
                else
                    fcs:do-scan-default($scan-clause, $x-context, $sort, $config)         

          (: if empty result, return the empty result, but don't store
            to not fill cache with garbage:)
(:            return $data:)
        
        return  if (exists($data)) then 
                        let $dummy := util:log-app("DEBUG", $config:app-name, "generating index "||$index-doc-name)
                        return repo-utils:store-in-cache($index-doc-name , $data, $config,'indexes') 
                    else 
                        let $dummy := util:log-app("DEBUG", $config:app-name, "no data for index "||$index-doc-name)
                        return ()

        (:if (number($data//sru:scanResponse/sru:extraResponseData/fcs:countTerms) > 0) then
        
                else $data:)

    (: extra handling if fcs.resource=root :)
    let $start-term := if ($index-name= 'fcs.resource' and $start-term='root') then '' else $start-term
    
	(: extract the required subsequence (according to given sort) :)
	(:let $res-nodeset :=  if ($index-name= 'cql.serverChoice') then
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
		(\: $colls := if (fn:empty($collection)) then '' else fn:string-join($collection, ","), :\)
        $colls := string-join( $x-context, ', ') ,
		$created := fn:current-dateTime():)
	let $terms-subsequence := fcs:scan-subsequence($index-scan/descendant-or-self::sru:scanResponse/sru:terms/sru:term, $start-term , $max-terms, $response-position, $x-filter)
    (:  return $res-nodeset   :)
(:    return $index-scan  :)
    (:DEBUG
    
    :)
    
    return <sru:scanResponse xmlns:fcs="http://clarin.eu/fcs/1.0">
            <sru:version>1.2</sru:version>
            <sru:terms>
    {$terms-subsequence}        
            </sru:terms>            
            {$index-scan/sru:scanResponse/sru:extraResponseData}            
            <sru:echoedScanRequest>
                <sru:scanClause>{$scan-clause}</sru:scanClause>
                <sru:maximumTerms>{$max-terms}</sru:maximumTerms>
                <fcs:x-context>{$x-context}</fcs:x-context>
                <fcs:x-filter>{$x-filter}</fcs:x-filter>
            </sru:echoedScanRequest>
        </sru:scanResponse>
};

(:~ returns appropriate subsequence of the index based on filter, startTerm and maximumTerms as defined in
@seeAlso http://docs.oasis-open.org/search-ws/searchRetrieve/v1.0/cs01/part6-scan/searchRetrieve-v1.0-cs01-part6-scan.html#responsePosition

:)
declare function fcs:scan-subsequence($terms as element(sru:term)*, $start-term as xs:string?, $maximum-terms as xs:integer, $response-position as xs:integer, $x-filter as xs:string?) as item()* {
(:$max-depth as xs:integer, $p-sort as xs:string?, $mode as xs:string?, $config) as item()? {:)

let $recurse-subsequence := if ($terms/sru:extraTermData/sru:terms/sru:term) then (: if there are more levels of terms :) 
                        for $term in $terms
                                let $children-subsequence := if ($term/sru:extraTermData/sru:terms/sru:term) then (: go deeper if children terms :) 
                                            fcs:scan-subsequence($term/sru:extraTermData/sru:terms/sru:term, $start-term,$maximum-terms, $response-position, $x-filter)
                                            else ()
                                            (: only return term if it has any child terms (after filtering) :)
                                return if (exists($children-subsequence)) then 
                                          <sru:term>{($term/*[not(local-name()='extraTermData')],
                                         if ($term/sru:extraTermData) then (: if given term has extraTermData :)
                                                <sru:extraTermData>
                                                { if ($term/sru:extraTermData/sru:terms) then (: term could have extraTermData but no children terms :) 
                                                        ($term/sru:extraTermData/*[not(local-name()='terms')],
                                                        <sru:terms>{$children-subsequence}</sru:terms>)
                                                   else $term/sru:extraTermData/*                                                  
                                                } </sru:extraTermData>
                                              else ()
                                          )} </sru:term>
                                       else ()
                    else (: do filtering on flat terms-sequence or only on the leaf-nodes in case of nested terms-sequences (trees) :)                    
                        if ($x-filter='' or not(exists($x-filter))) then
                            if ($start-term='' or not(exists($start-term))) then 
                            (: no start-term and no x-filter, just return first $maximum-terms from the terms-sequence :)
                                subsequence($terms,1,$maximum-terms)
                              else
                              (: start-term and no x-filter, return the following siblings of the startTerm; regard response-position :)
                                let $start-search-term-position := count($terms[starts-with(sru:value,$start-term)][1]/preceding-sibling::*) + 1
                                let $start-list-term-position := $start-search-term-position - $response-position + 1
                                let $dummy := util:log-app("DEBUG", $config:app-name, "start-search/list-term position: "||$start-search-term-position||'/'||$start-list-term-position)
(:                                $terms[$start-search-term-node/position() - $response-position]:)
                                return subsequence($terms,$start-list-term-position,$maximum-terms)
                          else       
                            if ($start-term='' or not(exists($start-term))) then
                            (: no start-term and x-filter, return the first $maximum-terms terms from the filtered! terms-sequence  :)
(:  TODO: regard other types of matches :)
                                subsequence($terms[starts-with(sru:displayTerm,$x-filter)],1,$maximum-terms)
                              else 
                              (: start-term and x-filter, return $maximum-terms terms from the filtered! terms-sequence starting from the $start-term :)
                                let $filtered-terms := $terms[starts-with(sru:displayTerm,$x-filter)]
                                (: need to reapply the filter :)
                                let $start-search-term-position := count($terms[starts-with(sru:value,$start-term)][1]/preceding-sibling::*[starts-with(sru:displayTerm,$x-filter)]) + 1
                                let $start-list-term-position := $start-search-term-position - $response-position + 1
                                let $dummy := util:log-app("DEBUG", $config:app-name, "start-search/list-term position: "||$start-search-term-position||'/'||count($filtered-terms))
                                return subsequence($filtered-terms,$start-list-term-position,$maximum-terms)
(:                                $terms[starts-with(sru:displayTerm,$start-term)]/following-sibling::sru:term[starts-with(sru:displayTerm,$x-filter)][position()<=$maximum-terms]:)

return  $recurse-subsequence
(:return subsequence($filteredData,  , $maximumTerms):)

};

(:~ delivers matching(!) terms from all indexes marked as scan=true(!) 
    to prevent too many records results are only returned, when the filter is at least $fcs:filterScanMinLength (current default=2)  
:)
declare function fcs:scan-all($project as xs:string, $filter as xs:string, $config ) as item()* {
(:  let $indexes :=  collection(project:path("abacus","indexes")):)
  let $index-definitions := index:map($project)//index[@scan='true']
  let $indexes := for $ix in $index-definitions    
                              let $index-doc-name := repo-utils:gen-cache-id("index", ($project, $ix/xs:string(@key), 'text', 1))
                             return repo-utils:get-from-cache($index-doc-name, $config)
  
  let $terms := if (string-length($filter) >= $fcs:filterScanMinLength) then
                    $indexes//sru:value[ft:query(., $filter)]/parent::sru:term union $indexes//sru:displayTerm[ft:query(., $filter)]/parent::sru:term
                  else ()
            (: get rid of nested terms  and adding cr:type :)
   let $terms-pruned := for $t in $terms
                                let $type := if (exists($t/sru:extraTermData/cr:type)) then () (: it will be copied anyhow :)
                                                else let $ix-key := root($t)//sru:scanClause/text()
                                                       let $ix-label := ($index-definitions[@key=$ix-key]/xs:string(@label),$ix-key)[1] 
                                                    return <cr:type l="{$ix-label}">{$ix-key}</cr:type> (: add if not provided :)
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
    let $termlabels := project:get-termlabels($project-pid,$index-key)     
    let $groups := 
        let $maps := 
            for $x in $data 
              let $g := index:apply-index ($x, $index-key, $project-pid,'match-only')              
            group by $g 
                return if (exists($g)) then                    
                        map:entry(($g)[1],$x)
                    else ()
        let $map := map:new($maps)
        return $map
    
    return
     <sru:terms> {
        for $group-key in map:keys($groups)
        let $entries := map:get($groups, $group-key)        
         let $term-label := fcs:term-to-label($group-key,$index-key,$project-pid,$termlabels)
         let $label := if ($term-label) then $term-label
                                        else index:apply-index($entries[1],$index-key,$project-pid,'label-only')
        let $count := count($entries)        
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
        (: when displaying certain indexes (e.g. toc) we only want to show the first resource fragment :) 
        let $config-param :=    if (contains($query,'fcs.toc')) 
                                then 
                                    map{
                                        "config" := $config,
                                        "x-highlight" := "off",
                                        "no-of-rf" := 1 
                                    }
                                else 
                                    $config
       
             let $result-seq-expanded := util:expand($result-seq)
             
             let $records :=
               <sru:records>{
                for $rec at $pos in $result-seq-expanded
         	    let $rec-data := fcs:format-record-data($result-seq[$pos], $rec, $x-dataview, $x-context, $config-param)
                return 
                for $rec-data-part in $rec-data return 
         	          <sru:record>
         	              <sru:recordSchema>http://clarin.eu/fcs/1.0/Resource.xsd</sru:recordSchema>
         	              <sru:recordPacking>xml</sru:recordPacking>         	              
         	              <sru:recordData>{$rec-data-part}</sru:recordData>         	              
         	              <sru:recordPosition>{$pos}</sru:recordPosition>
         	              <sru:recordIdentifier>{($rec-data-part/fcs:ResourceFragment[1]/data(@ref),$rec-data-part/data(@ref))[1]}</sru:recordIdentifier>
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
 let $project-id := ($result/xs:string(@cr:project-id))[1]
 let $resources-in-result := distinct-values ( $result/data(@cr:resource-pid)) 
 (:for $hit in $result
                let $id := $hit/data(@cr:resource-pid)                 
                group by $id
                return 
 :)
 (: using this to get a consistent / the correct order :)  
 let $resource-list := project:list-resources($project-id)[xs:string(@ID) = $resources-in-result]
 
return <sru:facetedResults>
    <sru:facet>
<sru:terms>{
                for $res in $resource-list
                let $res-id := $res/data(@ID)
                let $count := count($result[data(@cr:resource-pid) = $res-id ])
                let $label := $res/data(@LABEL)
(:                resource:label($res-id,$project-id):)
                return <sru:term>
                <sru:actualTerm>{$label}</sru:actualTerm>
                <sru:query>{$res-id}</sru:query>
                <sru:requestUrl>?operation=searchRetrieve&amp;query={$orig-query}&amp;x-context={$res-id}</sru:requestUrl>
                <sru:count>{$count}</sru:count>
            </sru:term>
            }
      <sru:facetDisplayLabel>Resource</sru:facetDisplayLabel>
        <sru:index>fcs.resource</sru:index>
        <sru:relation>=</sru:relation>        
        </sru:terms>
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
    let $match-elem := 'w'
    let $parent-elem := 'p' (: TODO: read from configuration cql.serverChoice  :) 
    let $match-ids := if (exists(util:expand($record-data-input)//exist:match/parent::*/data(@cr:id)))
                      then
                          let $exist-matches := util:expand($record-data-input)//exist:match
                          let $log := util:log-app("DEBUG", $config:app-name, "match parents: "||string-join($exist-matches/ancestor::*[local-name()=$match-elem][@cr:id]/xs:string(@cr:id),'; '))
                          return (:$exist-matches/parent::*/data(@cr:id):)
                                for $exist-match in $exist-matches
                                return
                                    if ($exist-match/ancestor::* = $exist-match) 
                                    then $exist-match/ancestor::*[local-name()=$match-elem]/data(@cr:id)
                                    else $exist-match/ancestor::*[local-name()=$match-elem]/data(@cr:id)
                                        (:for $substrPos in functx:index-of-string(xs:string($exist-match/parent::*),$exist-match)
                                        return $exist-match/parent::*/data(@cr:id)||":"||$substrPos||":"||string-length($exist-match):)
                      else 
                        (: if no exist:match, take the root of the matching snippet,:)   
                        let $log := util:log-app("DEBUG", $config:app-name, "$record-data-input contains no exist:match, falling back to its own @cr:id")
                        return $record-data-input/data(@cr:id)
    (: if the match is a whole resourcefragment we dont need a lookup, its ID is in the attribute :)   
    let $resourcefragment-pids :=    if ($record-data-input/ancestor-or-self::*[1]/@*[local-name() = $config:RESOURCEFRAGMENT_PID_NAME]) 
                                    then $record-data-input/ancestor-or-self::*[1]/data(@*[local-name() = $config:RESOURCEFRAGMENT_PID_NAME])
                                    else 
                                        if (exists($match-ids)) 
                                        then
                                            (:   21.1.2015 2 Zeilen :)
                                            (:let $cr-id-to-lookup := (\:if(matches($match-ids[1],':\d+:\d+$')) then replace($match-ids[1],':\d+:\d+$','') else:\) $match-ids[1]
                                            return rf:lookup-id($cr-id-to-lookup,$resource-pid, $project-id)[1]:)
                                            distinct-values((for $m in $match-ids return rf:lookup-id($m,$resource-pid,$project-id)))
                                        else util:log-app("ERROR", $config:app-name, "$match-ids is empty")
    let $rfs :=      if ($record-data-input/@*[local-name()=$config:RESOURCEFRAGMENT_PID_NAME] or empty($match-ids)) 
                    then $record-data-input 
                    else
                        (: for some indexes we might only want to return a certain number of 
                           resource fragments, e.g. fcs.toc only the first one - this is defined in the
                           config map by fcs:search-retrieve() :)
                        if ($config instance of map()) 
                        then
                            if ($config("no-of-rf") castable as xs:integer)
                            then
                                for $rpid in $resourcefragment-pids[position() le xs:integer($config("no-of-rf"))] 
                                return rf:get($rpid,$resource-pid, $project-id)
                            else 
                                for $rpid in $resourcefragment-pids 
                                return rf:get($rpid,$resource-pid, $project-id)
                        else 
                            for $rpid in $resourcefragment-pids 
                            return rf:get($rpid,$resource-pid, $project-id)
                    
    (: iterate over all resourcefragments:)
    return
    
    for $rf in $rfs
    return 
        let $resourcefragment-pid := $rf/@resourcefragment-pid
        let $dumy := util:log-app("INFO",$config:app-name,"$match-ids: "||string-join($match-ids,' '))                    
        let $dumy3 := util:log-app("INFO",$config:app-name,"$resourcefragment-pid: '"||$resourcefragment-pid||"'")
    (:   21.1.2015 1 Zeile :)
        (:let $rf-entry :=  if (exists($resourcefragment-pid)) then rf:record($resourcefragment-pid,$resource-pid, $project-id):)
        let $rf-entry :=  if (exists($resourcefragment-pid)) then rf:record($resourcefragment-pid,$resource-pid, $project-id)
        else ()
    (:    let $res-entry := $rf-entry/parent::mets:div[@TYPE=$config:PROJECT_RESOURCE_DIV_TYPE]:)
        let $res-entry := $rf-entry/parent::mets:div[@TYPE=$config:PROJECT_RESOURCE_DIV_TYPE]
    	
        (: $match-ids are always cr:ids of whole elements - it may be :)
        
        let $matches-to-highlight:= (tokenize(request:get-parameter("x-highlight",""),","),$match-ids)[rf:lookup-id(.,$resource-pid, $project-id) = $resourcefragment-pid]
    (:    let $record-data-toprocess := if (string-length(string-join($rf,'')) > string-length(string-join($record-data-input,''))) then $rf else $record-data-input:)
            let $record-data-toprocess := <rec> { if (not($record-data-input/local-name() = $parent-elem)) then $rf else $record-data-input } </rec>
            
         let $log := util:log-app("DEBUG", $config:app-name, "record-data-topprocess: "||name($record-data-toprocess/*))
         let $log := util:log-app("DEBUG", $config:app-name, "$matches-to-highlight: "||string-join($matches-to-highlight,';'))
         
                                                
        let $record-data-highlighted := 
        (: not sure if to work with $record-data-input or $rf :)
        if (exists($matches-to-highlight) and request:get-parameter("x-highlight","") != 'off')
                                then 
    (:                                if ($config("x-highlight")="off"):)
                                    if ($config instance of map()) 
                                    then 
                                        if ($config("x-highlight") = "off") 
                                        then $record-data-toprocess
                                        else fcs:highlight-matches-in-copy($record-data-toprocess, $matches-to-highlight)
    (:    DEBUG:                             else fcs:highlight-matches-in-copy(($rf,<missing-rf match-ids="{$match-ids[1]}" >{$record-data-input}</missing-rf>)[1], $matches-to-highlight):)
                                     else fcs:highlight-matches-in-copy($record-data-toprocess, $matches-to-highlight)
                                else $record-data-toprocess
    (: to repeat current $x-format param-value in the constructed requested :)
    	let $x-format := request:get-parameter("x-format", $repo-utils:responseFormatXml)
    	let $resourcefragment-ref :=   if (exists($resourcefragment-pid)) 
    	                               then 
    	                                   concat('?operation=searchRetrieve&amp;query=fcs.rf="',
    	                                           replace(xmldb:encode-uri(replace($resourcefragment-pid[1],'//','__')),'__','//'),
    	                                           '"&amp;x-context=', $x-context,
    	                                           '&amp;x-dataview=title,full',
    	                                           '&amp;version=1.2',
    	                                           if (exists(util:expand($record-data-highlighted)//exist:match/ancestor-or-self::*[@cr:id][1]))
    	                                           (:then '&amp;x-highlight='||string-join(distinct-values(util:expand($record-data-highlighted)//exist:match/ancestor-or-self::*[@cr:id][1]/@cr:id),','):)
    	                                           then '&amp;x-highlight='||string-join($matches-to-highlight,',')
    	                                           else ()
    	                                         )
    	                               else ""
    	
        
        let $rf-window := if (config:param-value($config,"rf.window") != '' and config:param-value($config,"rf.window") castable as xs:integer) 
                          then xs:integer(config:param-value($config,"rf.window")) 
                          else 1
        
        let $rf-window-prev := for $rfp in reverse(subsequence(reverse($rf-entry/preceding-sibling::mets:div[@TYPE = $config:PROJECT_RESOURCEFRAGMENT_DIV_TYPE]),1,$rf-window)) 
                               return rf:get($rfp/@ID,$resource-pid,$project-id)/*
                                
        let $rf-window-next := for $rfp in subsequence($rf-entry/following-sibling::mets:div[@TYPE = $config:PROJECT_RESOURCEFRAGMENT_DIV_TYPE],1,$rf-window) 
                                return rf:get($rfp/@ID,$resource-pid,$project-id)/*
        
    (:    let $rf2 := <ref>{($record-data-highlighted)}</ref>:)
    let $rf2 := fcs:highlight-matches-in-copy($record-data-input, $matches-to-highlight)
    (:    ,$rf-window-next:)
    (:   let $debug :=   <fcs:DataView type="debug" count="{count($record-data-highlighted)}">{transform:transform($record-data-highlighted, $fcs:flattenKwicXsl,())}</fcs:DataView>:)
         let $debug :=   <fcs:DataView type="debug" count="{count($rf)}" matchids="{$match-ids}">{$record-data-highlighted}</fcs:DataView>
        
        let $kwic := if (contains($data-view,'kwic')) then
                       let $kwic-config := <config width="{$fcs:kwicWidth}"/>
                       (: tentatively kwic-ing from original input - to get the closest match
                        however this fails when matching on attributes, where the exist:match is only added in the highlighting function,
                        thus we need the processed record-data :)
    (:                   let $kwic-html := kwic:summarize($record-data-input, $kwic-config):)
                    (: we create the kwic from the working copy, thus we look up the resourcefragment :)
                     (:let $wc-fragment :=  (for $m in $matches-to-highlight return wc:lookup($m,$resource-pid,$project-id))/ancestor-or-self::*[string-length(.) > $fcs:kwicWidth][1]
                     let $wc-fragment-highlighted := fcs:highlight-matches-in-copy($wc-fragment,$matches-to-highlight) 
                     let $flattened-record := transform:transform($wc-fragment-highlighted, $fcs:flattenKwicXsl,()):)
    (:                  let $kwicInput := $record-data[1]:)
     (:(\:DEBUG             :\)  let $kwicInput := ($record-data[1],$orig-sequence-record-data/ancestor-or-self::*[string-length(.) ge $fcs:kwicWidth][1])[1]
                     let $kwicInput-highlighted := $kwicInput
    (\:                 let $kwicInput-highlighted := fcs:highlight-matches-in-copy($kwicInput,$matches-to-highlight):\):)
                     (:let $log := util:log-app("DEBUG", $config:app-name, $orig-sequence-record-data/ancestor::*[string-length(.) gt $fcs:kwicWidth][1]):)
                      let $flattened-record := transform:transform($record-data-highlighted, $fcs:flattenKwicXsl,())
    (:                 let $flattened-record := repo-utils:serialise-as($record-data[1], 'html', $fcs:searchRetrieve, $config):)
                     
                     let $kwic-html := kwic:summarize($flattened-record, $kwic-config,util:function(xs:QName("fcs:filter-kwic"),2))
    (:                       DEBUG:)
    (:                    let $kwic-html := $record-data[1]:)
                           
                        return 
                           ( if (exists($kwic-html)) 
                            then  
                                for $match at $pos in $kwic-html
                                (: when the exist:match is complex element kwic:summarize leaves the keyword (= span[2]) empty, 
                                so we try to fall back to the exist:match :)
                                let $kw := if (exists($match/span[2][text()])) then $match/span[2]/text() else $record-data-highlighted[1]//exist:match[$pos]//text() 
                                return (<fcs:c type="left">{$match/span[1]/text()}</fcs:c>, 
                                           (: <c type="left">{kwic:truncate-previous($exp-rec, $matches[1], (), 10, (), ())}</c> :)
                                                          <fcs:kw>{$kw}</fcs:kw>,
                                                          <fcs:c type="right">{$match/span[3]/text()}</fcs:c>)            	                       
                                           (: let $summary  := kwic:get-summary($exp-rec, $matches[1], $config) :)
                            (:	                               <fcs:DataView type="kwic-html">{$kwic-html}</fcs:DataView>:)
                            
     (:DEBUG :)                                            
                            else (: if no kwic-match let's take first 100 characters 
                                            There c/should be some more sophisticated way to extract most significant info 
                                            e.g. match on the query-field :)
                            substring($record-data-highlighted[1],1,(2 * $fcs:kwicWidth)) ,
                            () )
                        (:<fcs:DataView>{$flattened-record}</fcs:DataView>, 
                           <fcs:DataView>{kwic:summarize($flattened-record, $kwic-config)}</fcs:DataView> ):)
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
                                then <fcs:DataView type="xmlescaped">{util:serialize($record-data-highlighted,'method=xml, indent=yes')}</fcs:DataView>
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
            then $record-data-highlighted
            else <fcs:Resource pid="{$resource-pid}" ref="{$resource-ref}">                
                    { (: if not resource-fragment couldn't be identified, don't put it in the result, just DataViews directly into Resource :)
                    if ($rf-entry) then 
                        <fcs:ResourceFragment pid="{$resourcefragment-pid}" ref="{$resourcefragment-ref}">{
                        for $d in tokenize($data-view,',\s*') 
                        return 
                            let $data:= switch ($d)
    (:                                        case "full"         return $rf[1]/*:)
                                            case "debug"         return $debug 
                                            case "full"         return (if ($rf-window gt 1) then $rf-window-prev else (),
                                                                       $record-data-highlighted[1]/*/*,
                                                                       if ($rf-window gt 1) then $rf-window-next else ())
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
                                                case "full"         return $record-data-highlighted[1]/*/*
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
    let $log := util:log-app("INFO",$config:app-name,name($mdRecord))
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
            else util:log-app("ERROR",$config:app-name,"stylesheet "||$stylesheet-file||" not available.")
}; 




declare function fcs:filter-kwic($node as node(), $mode as xs:string) as xs:string? {
    if ($mode eq 'before')
    then concat($node,' ')
    else concat(' ',$node)
};