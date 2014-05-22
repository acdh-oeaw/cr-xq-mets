
xquery version "1.0";

import module namespace smc  = "http://clarin.eu/smc" at "smc.xqm";
import module namespace crday  = "http://aac.ac.at/content_repository/data-ay" at "../aqay/crday.xqm";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at  "../../core/repo-utils.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "/db/apps/cr-xq/core/config.xqm";
 (:  import module namespace cmdcheck  = "http://clarin.eu/cmd/check" at "/db/cr/modules/cmd/cmd-check.xqm"; :)

declare namespace cmd = "http://www.clarin.eu/cmd/";

let $dcr-cmd-map := doc("/db/apps/cr-xq/modules/smc/data/dcr-cmd-map.xml")
let $xsl-smc-op := doc("/db/apps/cr-xq/modules/smc/xsl/smc_op.xsl")
let $xsl-terms2graph := doc("/db/apps/cr-xq/modules/smc/xsl/terms2graph.xsl")
let $xsl-graph2json := doc("/db/apps/cr-xq/modules/smc/xsl/graph2json-d3.xsl")

let $config := config:config('mdrepo'),
    $x-context := "mdrepo", (: "http://clarin.eu/lrt-inventory", :)
    $model := map { "config" := $config}
(:    $context-collection := "/db/cr-data/barock",
    $data-collection := repo-utils:context-to-collection($x-context, $config)
    $context := collection($context-collection), :)

(: let $cmd-terms := doc("/db/cr/modules/smc/data/cmd-terms.xml") 
let $ay-data := doc("/db/mdrepo-data/_indexes/ay-teiHeader.xml") 
let $mapping := smc:create-mappings($ay-data)
return xmldb:store("/db/cr/etc", "mappings_mdrepo_auto.xml", $mapping)

let $ay-data := crday:ay-xml($data-collection, "Components", 4 ) 
return xmldb:store("/db/mdrepo-data/_indexes", "ay-olac-Components.xml", $ay-data)

    
 let $ay-xml :=  crday:get-ay-xml($config, $x-context, '', $crday:defaultMaxDepth, false(), 'raw') 
let $mapping := smc:get-mappings($config, $x-context, true(), 'raw')
:)
let $cache-path := config:param-value($model, 'cache.path')
(:  beware of mixing in the already result (doc()/Termsets/Termset vs. doc()/Termset  :)
let $termsets := <Termsets>{collection($cache-path)/Termset}</Termsets>
let $termsets-file := "_structures.xml"
let $graph-file := "_structure-graph"
let $termsets-doc := doc(concat($cache-path, $termsets-file))
   
(:  
let $graph := transform:transform($termsets-doc, $xsl-terms2graph,<parameters><param name="base-uri" value="/db/apps/cr-xq/modules/smc/data/" /></parameters> )
let $graph-store := xmldb:store($cache-path,concat($graph-file,".xml"), $graph) :)
let $graph-doc := doc(concat($cache-path, $graph-file, '.xml'))
  
(:  
let $graph-json := transform:transform($graph, $xsl-graph2json,<parameters><param name="base-uri" value="/db/apps/cr-xq/modules/smc/data/" /></parameters> )

 
return ($graph-store, xmldb:store("/db/mdrepo-data/_indexes","_structure-graph.json", $graph-json))
 :)
 let $graph-termsets := for $t in $graph-doc//Termset/Term
                            return <term>{$t/@*}</term>
 
    return ($cache-path, count($termsets//Termset),count($termsets-doc//Termset), count(distinct-values($termsets-doc//
    
    Termset/Term/@name)), count($graph-doc//node[@type='Profile']),
   <profiles>{distinct-values($termsets-doc//Termset/Term/@name)}</profiles>,
   <graph-termsets>{$graph-termsets}</graph-termsets>,   
   <nodes>{distinct-values($graph-doc//node[@type='Profile']/xs:string(@name))}</nodes>)

  
(:  

return  smc:gen-mappings($config, $x-context, true(), 'raw')

    smc:mappings-overview($config, 'htmlpagetable') :) 

  (:
let $mapping := smc:create-mappings($x-context, $config)


let $data-collection := repo-utils:context-to-collection($x-context, $config),
$ay-profiles := cmdcheck:stat-profiles($data-collection),
$child-elements := util:eval("$data-collection//collection")/child::element(),
$child-ns-qnames := if (exists($child-elements)) then distinct-values($child-elements/concat(namespace-uri(), '|', name())) else ()
:)
(:     $ns-uri := namespace-uri($data-collection[1]),    
    (namespace-uri($data-collection[1]/*), $data-collection[1]/*, $ay-profiles)  :)

(: crday:ay-xml($data-collection, "collection", 8)
let $path-nodes :=  $data-collection//cmd:Components,:)
(:    $child-elements := $path-nodes/child::element(),:)
(:    $ns := distinct-values($child-elements/namespace-uri()),:)
(:    (:  $subs := distinct-values($child-elements/concat(namespace-uri(), ":", name())),:):)
(:    $subs := distinct-values($child-elements/name()),    :)
(:    (: $dummy := util:declare-namespace ("", $ns), :):)
(:     $eval-subs := util:eval(concat("$path-nodes/", $subs)),:)



(:~ test shorten-uri
let $url := 'http://purl.org/dc/elements/1.1/title'
let $termset := $smc:termsets//Termset[url_prefix][starts-with($url, url_prefix)][$url ne '']
    let $url-suffix := substring-after ($url, $termset/url_prefix)    
return if (exists($termset)) then concat($termset/key, ':', $url-suffix) else $url
:)


(: let $list-cmd := transform:transform ($dcr-cmd-map, $xsl-smc-op,
<parameters><param name="operation" value="list"/>
    <param name="set" value="isocat-en"/>
    <param name="context" value="isocat-en"/>
</parameters>)

return (count($list-cmd//Term),$list-cmd)
:)
(:)
return transform:transform ($dcr-cmd-map, $xsl-smc-op, 
<parameters><param name="operation" value="map"/>    
    <param name="term" value="nome do projecto"/>        
</parameters>)
:)

