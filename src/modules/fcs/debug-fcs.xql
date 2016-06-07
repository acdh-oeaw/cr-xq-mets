xquery version "3.0";

(:
The MIT License (MIT)

Copyright (c) 2016 Austrian Centre for Digital Humanities at the Austrian Academy of Sciences

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE
:)

(:~ This is a simple XQuery script for debugging purposes which assembles the various steps of the fcs module to produce results to a query. ~:)

import module namespace fcs = "http://clarin.eu/fcs/1.0" at "fcs.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "../../core/config.xqm";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at  "../../core/repo-utils.xqm";
import module namespace cql = "http://exist-db.org/xquery/cql" at "../cqlparser/cqlparser.xqm";
import module namespace query  = "http://aac.ac.at/content_repository/query" at "../query/query.xqm";
import module namespace rf="http://aac.ac.at/content_repository/resourcefragment" at "../../core/resourcefragment.xqm";
import module namespace lt="http://aac.ac.at/content_repository/lookuptable" at "../../core/lookuptable.xqm";
import module namespace resource="http://aac.ac.at/content_repository/resource" at "../../core/resource.xqm";
import module namespace project="http://aac.ac.at/content_repository/project" at "../../core/project.xqm";
import module namespace index="http://aac.ac.at/content_repository/index" at "../../core/index.xqm";

declare namespace cr="http://aac.ac.at/content_repository";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace mets="http://www.loc.gov/METS/";
declare namespace sru = "http://www.loc.gov/zing/srw/";

(:~ These variables represent user parameters received by the fcs module. ~:)
let $query:="dar",
    $index:='',
    $x-context:="abacus",
    $startRecord:=1,
    $maximumRecords:=15,
    $x-dataview:="kwic",
    $config:=config:project-config($x-context)

let $project-config-map:=map{"config":=$config}
let $relPath := "modules/shared/scripts/js/query_input/CQLConfig.js"

let $data-collection := repo-utils:context-to-collection($x-context, $config)
    
let $xpath-query := query:query-to-xpath ($query, $x-context)
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
(: return util:expand($data-collection//tei:div[ft:query(.,'dar')])//exist:match:)

(:let $data := collection("/db/cr-data/abacus"):)
(:return $data//tei:w[starts-with(@lemma,"T")][@type="NN"]:)

(:#### testing Res/RF lookup :)
    let $element-id := 'mecmua.1.d1e13465'
    let $resource-pid := 'mecmua.1'
    let $project-pid := $x-context
(:    return lt:lookup('mecmua.1.d1e13465','mecmua.1', $x-context):)
  
(: return  repo-utils:context-to-type('abacus',$config):)
(: return resource:path($resource-pid, $project-pid, "lookuptable"  ):)


(: #####  SEARCH | SCAN  :)
(:return fcs:search-retrieve($query,$x-context, 1,10,'title,kwic',$config):)

(: test scan-all :)
(:return  fcs:scan('cql.serverChoice=ha*', 'abacus',1, 100, 1, 1, 'text', '', $config):)
 
  let $scan-clause := 'antiqua'
let $path := index:index-as-xpath($scan-clause,$x-context)
let $data := repo-utils:context-to-data($x-context,$config),
    (: this limit is introduced due to performance problem >50.000?  nodes (100.000 was definitely too much) :)
        $nodes := subsequence(util:eval("$data//"||$path),1,100)
(:return count($data//seg[@rend='antiqua']):)
 let $indexes := for $ix in index:map($x-context)//index[@scan='true']    
                              let $index-doc-name := repo-utils:gen-cache-id("index", ($x-context, $ix/xs:string(@key), 'text', 1))
                             return repo-utils:get-from-cache($index-doc-name, $config)
(:return $data//placeName[@subtype="allu"] :)
 
(:return  fcs:scan('antiqua', 'abacus',1, 100, 1, 1, 'text', '', $config):)
 
(: return doc-available("/db/cr-data/_indexes/abacus/index-abacus-cql.serverChoice-text-1.xml"):)
 (: ###  testing overall scan :)
(:let $indexed-data := collection("/db/cr-data/_indexes/abacus/"):)

(:return $indexed-data//sru:value[starts-with(., 'Ha')]:)
(: return $indexed-data//sru:value[ft:query(., 'ha*')]:)
(:return fcs:scan-all('abacus','ha*'):)
 
 return index:map($x-context), fcs:get-mapping('',$x-context,$config)