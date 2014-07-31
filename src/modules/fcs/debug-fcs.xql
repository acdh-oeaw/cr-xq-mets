xquery version "3.0";

(:~ This is a simple XQuery script for debugging purposes which assembles the various steps of the fcs module to produce results to a query. ~:)

import module namespace fcs = "http://clarin.eu/fcs/1.0" at "fcs.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "../../core/config.xqm";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at  "../../core/repo-utils.xqm";
import module namespace cql = "http://exist-db.org/xquery/cql" at "../cqlparser/cqlparser.xqm";
import module namespace rf="http://aac.ac.at/content_repository/resourcefragment" at "../../core/resourcefragment.xqm";
import module namespace lt="http://aac.ac.at/content_repository/lookuptable" at "../../core/lookuptable.xqm";
import module namespace resource="http://aac.ac.at/content_repository/resource" at "../../core/resource.xqm";

declare namespace cr="http://aac.ac.at/content_repository";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace mets="http://www.loc.gov/METS/";

(:~ These variables represent user parameters received by the fcs module. ~:)
let $query:="dar",
    $index:='',
    $x-context:="mecmua",
    $startRecord:=1,
    $maximumRecords:=15,
    $x-dataview:="kwic",
    $config:=config:project-config($x-context)

let $project-config-map:=map{"config":=$config}
let $relPath := "modules/shared/scripts/js/query_input/CQLConfig.js"

let $data-collection := repo-utils:context-to-collection($x-context, $config)
let $xpath-query := fcs:transform-query ($query, $x-context, $config, true())
(:let $results := if ($xpath-query instance of text() or $xpath-query instance of xs:string) then:)
(:                    util:eval(concat("$data-collection",translate($xpath-query,'&amp;','?'))):)
(:                else ():)
(:                        :)
(:let $index:="resource-pid":)
(:return    for $data in $results return:)
(:        let $index-map := fcs:get-mapping($index,$x-context, $config),:)
(:            $index-xpath := fcs:index-as-xpath($index,$x-context, $config):)
(:        return fcs:apply-index($data,$index,$x-context,$config):)
 
(:return fcs:get-mapping('resourcefragment-pid',$x-context,config:config($x-context)):)
(:return fcs:index-as-xpath('resourcefragment-pid',$x-context,config:config($x-context)):)
(:return $config//mets:techMD[@ID='crProjectMappings']/mets:mdWrap/mets:xmlData/map:)
(:let $dataset:=repo-utils:resources-by-project($x-context):)

(:let $import:=fcs:import-project-index-functions($x-context):)
(:let $data:=for $d in $dataset return doc($d):)
(:return :)
(:    for $d in $data return:)
(:        fcs:apply-index($d, 'title', $x-context, $config):)

(:return cql:cql2xpath($query, $x-context, config:mappings($x-context)):)
    let $element-id := 'mecmua.1.d1e13465'
    let $resource-pid := 'mecmua.1'
    let $project-pid := $x-context
(:    return lt:lookup('mecmua.1.d1e13465','mecmua.1', $x-context):)
 return util:expand($data-collection//tei:div[ft:query(.,'dar')])//exist:match
(: return resource:path($resource-pid, $project-pid, "lookuptable"  ):)
(:return fcs:search-retrieve($query,$x-context, 1,10,'title,kwic',$config):)
(:return  fcs:scan('fcs.toc', 'abacus.3',1, 100, 1, 1, 'text', '', $config):)
(: return  repo-utils:context-to-type('abacus',$config):)
 
(:let $mappings := config:param-value(map{"config":=$config},"mappings"):)
(:return:)
(:    for $index in $mappings//index :)
(:    return fcs:index-as-xpath($index/@key,$x-context,$config):)
(:(:return config:project-config($x-context):):)