xquery version "1.0";
module namespace smc = "http://clarin.eu/smc";

import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at  "../../core/repo-utils.xqm";
import module namespace crday  = "http://aac.ac.at/content_repository/data-ay" at "../aqay/crday.xqm";
import module namespace fcs = "http://clarin.eu/fcs/1.0" at "../fcs/fcs.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "../../core/config.xqm";
declare namespace sru = "http://www.loc.gov/zing/srw/";

declare variable $smc:termsets := doc("data/termsets.xml");
declare variable $smc:dcr-terms := doc("data/dcr-terms.xml");
declare variable $smc:cmd-terms := doc("data/cmd-terms.xml");
declare variable $smc:xsl-terms2graph := doc("xsl/terms2graph.xsl");
declare variable $smc:xsl-graph2json := doc("xsl/graph2json-d3.xsl");
declare variable $smc:structure-file  := '_structure';




(:~ mappings overview
only process already created maps (i.e. (for now) don't run mappings on demand, 
because that would induce ay-xml - which takes very long time and is not safe 
:)
declare function smc:mappings-overview($config, $format as xs:string) as item()* {

let $cache_path := repo-utils:config-value($config, 'cache.path'),
    $mappings := collection($cache_path)/map[*]
    


let $overview := if (contains($format, "table")) then
                       <table class="show"><tr><th>index |{count(distinct-values($mappings//index/xs:string(@key)))}|</th>
                         {for $map in $mappings return <th>{concat($map/@profile-name, ' ', $map/@context, ' |', count($map/index), '/', count($map/index/path), '|')}</th> } 
                         </tr>                    
                        { for $ix in distinct-values($mappings//index/xs:string(@key))
                             let $datcat := $smc:dcr-terms//Concept[Term[@type='id']/concat(@set,':',text()) = $ix],
                                  $datcat-label := $datcat/Term[@type='mnemonic'],
                                 $datcat-type := $datcat/@datcat-type,
                                 $index-paths := $mappings//index[xs:string(@key)=$ix]/path
                             return <tr><td valign="top">{(<b>{$datcat-label}</b>, concat(' |', count($index-paths/ancestor::map), '/', count($index-paths), '|'), <br/>, concat($ix, ' ', $datcat-type))}</td>
                                        {for $map in $mappings
                                                 let $paths := $map/index[xs:string(@key)=$ix]/path
                                        return <td valign="top"><ul>{for $path in $paths
                                                            return <li title="{$path/text()}" >{tokenize($path/text(), '\.')[last()]}</li>
                                                         }</ul></td> 
                                         }
                                      </tr>
                           }
                        </table>
                    else 
                       <ul>                  
                        { for $ix in distinct-values($mappings//index/xs:string(@key))
                             let $datcat := $smc:dcr-terms//Concept[Term[@type='id']/concat(@set,':',text()) = $ix],
                                  $datcat-label := $datcat/Term[@type='mnemonic'],
                                 $datcat-type := $datcat/@datcat-type
                             return <li><span>{(<b>{$datcat-label}</b>, <br/>, concat($ix, ' ', $datcat-type))}</span>
                                        {for $map in $mappings
                                                 let $paths := $map/index[xs:string(@key)=$ix]/path
                                        return <td valign="top"><ul>{for $path in $paths
                                                            return <li>{$path/text()}</li>
                                                         }</ul></td> 
                                         }
                                      </li>
                           }
                        </ul> 
                    
       return if ($format eq 'raw') then
                   $overview
                else            
                   repo-utils:serialise-as($overview, $format, 'html', $config, ())                   
};


(:~
generates mappings for individual collections, 
by invoking get-mappings for each collection individually (as x-context)

@returns a summary of generated stuff
:)
declare function smc:gen-mappings($config, $x-context as xs:string+, $run-flag as xs:boolean, $format as xs:string) as item()* {

(:         let $mappings := doc(repo-utils:config-value($config, 'mappings')),:)
    let $context-mapping := fcs:get-mapping('',$x-context, $config),
          (: if not specific mapping found for given context, use whole mappings-file :)
          $mappings := if ($context-mapping/xs:string(@key) = $x-context) then $context-mapping 
                    else doc(repo-utils:config-value($config, 'mappings')) 
    
   
   let $mapsummaries := for $map in $mappings/descendant-or-self::map[@key]
                let $map := smc:get-mappings($config, $map/xs:string(@key), true(), 'raw')
                return <map count_profiles="{count($map/map)}" count_indexes="{count($map//index)}" >{($map/@*,
                            for $profile-map in $map/map 
                            return <map count_indexes="{count($profile-map/index)}" count_paths="{count($profile-map/index/path)}">{$profile-map/@*}</map>)}</map>
(:                return $map:)
   
   return <map empty_maps="{count($mapsummaries[xs:integer(@count_indexes)=0])}">{$mapsummaries}</map>

};

(:~ create and store mapping for every profile in given nodeset 
expects the CMD-format

calls crday:get-ay-xml which may be very time-consuming

@param $format [raw, htmlpage, html] - raw: return only the produced table, html* : serialize as html
@param $run-flag if true - re-run even if in cache
:)
declare function smc:get-mappings($config, $x-context as xs:string+, $run-flag as xs:boolean, $format as xs:string) as item()* {

let $scan-profiles :=  fcs:scan('cmd.profile', $x-context, 1, 50, 1, 1, "text", '', $config),
    $target_path := repo-utils:config-value($config, 'cache.path')

(: for every profile in the data-set :)
let $result := for $profile in $scan-profiles//sru:term
                    let $profile-name := xs:string($profile/sru:displayTerm)    
                    let $map-doc-name := repo-utils:gen-cache-id("map", ($x-context, $profile-name), '')
                    
                    return 
                        if (repo-utils:is-in-cache($map-doc-name, $config) and not($run-flag)) then 
                            repo-utils:get-from-cache($map-doc-name, $config)
                        else
                            let $ay-data := crday:get-ay-xml($config, $x-context, $profile-name, $crday:defaultMaxDepth, $run-flag, 'raw')    
                            let $mappings := <map profile-id="{$profile/sru:value}" profile-name="{$profile-name}" context="{$x-context}"> 
                                                {smc:match-paths($ay-data, $profile)}
                                               </map>
                            return repo-utils:store-in-cache($map-doc-name, $mappings, $config)
    
   return if ($format eq 'raw') then
                   <map context="{$x-context}" >{$result}</map>
                else            
                   repo-utils:serialise-as(<map context="{$x-context}" >{$result}</map>, $format, 'default', $config, ())  
};

(:~ expects a summary of data, matches the resulting paths with paths in cmd-terms
and returns dcr-indexes, that have a path in the input-data

be kind and try to map on profile-name if profile-id not available (or did not match) 
:)
declare function smc:match-paths($ay-data as item(), $profile as node()) as item()* {

let $data-paths := $ay-data//Term/replace(replace(xs:string(@path),'//',''),'/','.')

let $profile-id := xs:string($profile/sru:value)
let $profile-name := xs:string($profile/sru:displayTerm)    
  
let $match-by-id := if ($profile-id ne '') then $smc:cmd-terms//Termset[@id=$profile-id and @type="CMD_Profile"]/Term[xs:string(@path) = $data-paths ] else ()
let $match := if (exists($match-by-id)) then $match-by-id
                    else $smc:cmd-terms//Termset[xs:string(@name)=$profile-name and @type="CMD_Profile"]/Term[xs:string(@path) = $data-paths ] 

let $mapping := for $datcat in distinct-values($match//xs:string(@datcat))
                    let $key := smc:shorten-uri($datcat) 
                    return <index key="{$key}" >
                                { for $path in $match[xs:string(@datcat) = $datcat]/xs:string(@path)                                    
                                    return <path count="">{$path}</path>
                                }
                            </index>
return $mapping
};

(:~ replace url_prefix in the url by the short key
based on definitions in $smc:termsets
:)
declare function smc:shorten-uri($url as xs:string) as xs:string {    
    let $termset := $smc:termsets//Termset[url_prefix][starts-with($url, url_prefix)][$url ne '']
    let $url-suffix := substring-after ($url, $termset/url_prefix)    
    return if (exists($termset)) then concat($termset/key, ':', $url-suffix) else $url
};

(:~ 
:)
declare function smc:gen-graph($config, $x-context as xs:string+) as item()* {

    let $model := map { "config" := $config}
    let $cache-path := config:param-value($model, 'cache.path')
    let $smc-browser-path := config:param-value($model, 'smc-browser.path')
    (:  beware of mixing in the already result (doc()/Termsets/Termset vs. doc()/Termset  :)
    let $termsets := <Termsets>{collection($cache-path)/Termset}</Termsets>
    
    
    
(:    let $termsets-doc := doc(concat($cache-path, $termsets-file)):)
   let $termsets-doc := repo-utils:store-in-cache(concat($smc:structure-file,".xml"), $termsets, $config)
   
let $graph := transform:transform($termsets, $smc:xsl-terms2graph,<parameters><param name="base-uri" value="/db/apps/cr-xq/modules/smc/data/" /></parameters> ),
    $graph-file := concat($smc:structure-file, "-graph"),
    $graph-doc := repo-utils:store-in-cache (concat($graph-file,".xml"), $graph,$config),    
    $graph-json := transform:transform($graph, $smc:xsl-graph2json,<parameters><param name="base-uri" value="/db/apps/cr-xq/modules/smc/data/" /></parameters> ),
    $graph-json-doc := repo-utils:store-in-cache(concat($graph-file,".json"), $graph-json, $config)  
    let $graph-copy := if ($smc-browser-path ne '') then  repo-utils:store($smc-browser-path,concat($graph-file,".json"), $graph-json, true(),$config) else ()
return <gen-graph>{string-join((document-uri($termsets-doc), document-uri($graph-doc), concat($graph-file,".json"), $smc-browser-path),', ')}</gen-graph> 

(:
 let $graph-termsets := for $t in $graph-doc//Termset/Term
                            return <term>{$t/@*}</term>
    return ($cache-path, count($termsets//Termset),count($termsets-doc//Termset), count(distinct-values($termsets-doc//Termset/Term/@name)), count($graph-doc//node[@type='Profile']),
   <profiles>{distinct-values($termsets-doc//Termset/Term/@name)}</profiles>,
   <graph-termsets>{$graph-termsets}</graph-termsets>,   
   <nodes>{distinct-values($graph-doc//node[@type='Profile']/xs:string(@name))}</nodes>)
:)
  
};