xquery version "1.0";

import module namespace smc  = "http://clarin.eu/smc" at "smc.xqm";
import module namespace crday  = "http://aac.ac.at/content_repository/data-ay" at "/db/cr/crday.xqm";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at  "xmldb:exist:///db/cr/repo-utils.xqm";
import module namespace cmdcheck  = "http://clarin.eu/cmd/check" at "/db/cr/modules/cmd/cmd-check.xqm";

declare namespace cmd = "http://www.clarin.eu/cmd/";

let $dcr-cmd-map := doc("/db/cr/modules/smc/data/dcr-cmd-map.xml")
let $cmd-terms := doc("/db/cr/modules/smc/data/cmd-terms.xml")
let $xsl-smc-op := doc("/db/cr/modules/smc/xsl/smc_op.xsl")

let $config := doc("/db/cr/etc/config_mdrepo.xml"), 
    $x-context := "olac-root" (: "http://clarin.eu/lrt-inventory", :)
(:    $context-collection := "/db/cr-data/barock",
    $data-collection := repo-utils:context-to-collection($x-context, $config)
    $context := collection($context-collection), :)

(: let $cmd-terms := doc("/db/cr/modules/smc/data/cmd-terms.xml") 
let $ay-data := doc("/db/mdrepo-data/_indexes/ay-teiHeader.xml") 
let $mapping := smc:create-mappings($ay-data)
return xmldb:store("/db/cr/etc", "mappings_mdrepo_auto.xml", $mapping)

let $ay-data := crday:ay-xml($data-collection, "Components", 4 ) 
return xmldb:store("/db/mdrepo-data/_indexes", "ay-olac-Components.xml", $ay-data)
:)

let $cache_path := repo-utils:config-value($config, 'cache.path')
(:let $mapping := smc:get-mappings($x-context, $config, true(),'raw'):)
(:let $mappings := collection($cache_path)/map[*]:)

let $profile_comps := distinct-values($cmd-terms//Term[@type='CMD_Component'][@parent='']/xs:string(@id)),
    $components := distinct-values($cmd-terms//Term[@type='CMD_Component'][not(@parent='')]/xs:string(@id)),
    
 $comps := <comps>{for $comp in $components 
                    order by $comp
                    return <comp>{$comp}</comp> }</comps>,
                    
    $elem_paths := distinct-values($cmd-terms//Term[@type='CMD_Element']/@path)    ,
    $comp_paths := distinct-values($cmd-terms//Term/@path)    
    
return count($comp_paths)
