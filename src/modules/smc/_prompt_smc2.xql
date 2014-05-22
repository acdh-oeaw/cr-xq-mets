xquery version "1.0";

import module namespace resource = "http://cr-xq/resource" at "../resource/resource.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "../../core/config.xqm";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at  "../../core/repo-utils.xqm";
import module namespace httpclient="http://exist-db.org/xquery/httpclient";
import module namespace util="http://exist-db.org/xquery/util";
import module namespace fcs = "http://clarin.eu/fcs/1.0" at "../fcs/fcs.xqm";
import module namespace crday = "http://aac.ac.at/content_repository/data-ay" at "../aqay/crday.xqm";


(:declare namespace tei = "http://www.tei-c.org/ns/1.0" ;:)
declare namespace templates="http://exist-db.org/xquery/templates";
declare namespace cmd= "http://www.clarin.eu/cmd/"; 
declare namespace cr = "http://aac.ac.at/content-repository";
declare namespace xhtml = "http://www.w3.org/1999/xhtml";




let $config := config:config('mdrepo'),
    $x-context := "mdrepo", (: "http://clarin.eu/lrt-inventory", :)
    $format := "raw",
    $model := map { "config" := $config}


(:       let $config := doc($config-path), 
         let $config := repo-utils:config($config-path),:)
(:         let $mappings := doc(repo-utils:config-value($config, 'mappings')),:)
          let $context-mapping := fcs:get-mapping('',$x-context, $config),
          (: if not specific mapping found for given context, use whole mappings-file :)
          $mappings := if ($context-mapping/xs:string(@key) = $x-context) then $context-mapping 
                    else doc(repo-utils:config-value($config, 'mappings')), 
           $baseadminurl := repo-utils:config-value($config, 'admin.url') 

        let $opt := util:declare-option("exist:serialize", "media-type=text/html method=xhtml")
        
let $coll-overview :=  <div id="collections-overview">
                    <h2>Collections overview</h2>
                <table class="show"><tr><th>collection</th><th>path</th><th>file</th><th>resources</th><th colspan="2">base-elem</th>
                            <th>indexes</th><th>struct</th><th>md</th></tr>
           { for $map in $mappings/descendant-or-self::map[@key]
                    let $map-key := $map/xs:string(@key),
                        $map-dbcoll-path := $map/xs:string(@path),
(:                        $map-dbcoll:= if ($map-dbcoll-path ne '' and xmldb:collection-available (($map-dbcoll-path,"")[1])) then collection($map-dbcoll-path) else (),                      :)
                          $map-dbcoll:= repo-utils:context-to-collection($map-key, $config),
(:                          $resources:= fcs:apply-index($map-dbcoll,'fcs.resource',$map-key,$config),
                          $base-elems:= fcs:apply-index($map-dbcoll,'cql.serverChoice',$map-key,$config),
:)
                          $resources:= (),
                          $base-elems:= (),


(:                        $queries-doc-name := crday:check-queries-doc-name($config, $map-key),:)
                        $sturct-doc-name := repo-utils:gen-cache-id("structure", ($map-key,""), xs:string($crday:defaultMaxDepth)),
                        $invoke-href := concat($baseadminurl,'?x-context=', $map-key ,'&amp;action=' ),                        
                        (:$queries := if (repo-utils:is-in-cache($queries-doc-name, $config)) then 
                                                <a href="{concat($invoke-href,'xpath-queryset-view')}" >view</a>                                             
                                              else (),:)                       
                        $structure := if (repo-utils:is-in-cache($sturct-doc-name, $config)) then                                                
                                                <a href="{concat($invoke-href,'ay-xml-view')}" >view</a>                                             
                                              else (),
                        $md := resource:getMD(map { "config" := $config}, $map-key)//cmd:MdSelfLink/text()
                    return <tr>
                        <td>{$map-key}</td>
                        <td>{$map-dbcoll-path}</td>
                        <td align="right">{count($map-dbcoll)}</td>
                        <td align="right"><a href="fcs?x-context={$map-key}&amp;operation=scan&amp;scanClause=fcs.resource&amp;x-format={$format}">{count($resources)}</a></td>
                        <td>{$map/xs:string(@base_elem)}</td>
                        <td>{count($base-elems)}</td>
                        <td align="right"><a href="fcs?x-context={$map-key}&amp;operation=explain&amp;x-format={$format}">{count($map/index)}</a></td>
                        <td>{$structure} [<a href="{concat($invoke-href,'ay-xml-run')}" >run</a>]</td>
                        <td><a href="{$md}">{$md}</a></td>
                        </tr>
                        }
        </table></div>

return $coll-overview