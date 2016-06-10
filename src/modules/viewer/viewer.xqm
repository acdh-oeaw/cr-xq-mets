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

module namespace viewer = "http://sade/viewer" ;
declare namespace templates="http://exist-db.org/xquery/templates";
import module namespace config="http://exist-db.org/xquery/apps/config" at "../../core/config.xqm";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at  "../../core/repo-utils.xqm";
import module namespace resource = "http://cr-xq/resource" at  "../resource/resource.xqm";
(:declare namespace tei = "http://www.tei-c.org/ns/1.0" ;:)

(:~ default viewer, fetching data, transforming with xslt 
based on text-viewer 
tries to get the resources matching the @xml:id, then the filename (in the data- and metadata-path)
:)

(: moved to resource-module 
declare function viewer:get ($config-map, $id as xs:string) {

    let $data-dir := config:param-value($config-map, 'data-dir'),
    $metadata-dir := config:param-value($config-map, 'metadata-path'),
    $resource-id := collection($data-dir)//*[@xml:id eq $id],
    $resource := if (exists($resource-id)) then $resource-id
                 else if (doc-available(concat($data-dir, '/', $id))) then
                            doc(concat($data-dir, '/', $id))
                 else if (doc-available(concat($metadata-dir, '/', $id))) then
                            doc(concat($metadata-dir, '/', $id))
                 else ()
    
    
    return if (exists($resource)) then $resource 
                else <diagnostics><message>Resource unavailable, id: { ($data-dir, $id) } </message></diagnostics> 

};
:)

declare function viewer:display($config-map, $id as xs:string, $format as xs:string) as item()* {    
    
    let $data := resource:get($config-map, $id)
    
    let $params := <parameters>
                        <param name="format" value="{$format}"/>
                  		<param name="base_url" value="{config:param-value($config-map,'base-url')}"/>

                  </parameters>
(:                  		modules/shared/scripts:)
                  
     return if ($format='xml') then
                $data
            else 
            <div class="templates:init">
               <div class="templates:surround?with=page.html&amp;at=content-container">
                { repo-utils:serialise-as($data, $format, 'xml', $config-map("config"), $params) }
              </div>
             </div>
    
    
 (:   let $divID := $node/xs:string(@id)
    let $config := local:readConfig()("config")//*[@name="text-viewer"][@container=$divID]
    
    (\: Projektkonfiguration auslesen :\)
    let $collection_path := $config/param[@name="collection_path"]/xs:string(@value)
    let $xpath := $config/param[@name="xpath"]/xs:string(@value)
    let $xslt_path := $config/param[@name="xslt_path"]/xs:string(@value)
    
    (\: Geamtanzahl der referenzierten Elemente feststellen :\)
    let $totalNr := util:eval(concat("count(collection('",$collection_path,"')",$xpath,")"))
    
    (\: XML-Fragment aus DB holen und transformieren :\)
    let $xsl := if ($xslt_path = () or $xslt_path = "" or $xslt_path = "tei") then doc("resources/tei/stylesheet/xhtml2/tei.xsl")
                else doc($xslt_path)
    let $fragment := util:eval(concat("collection('",$collection_path,"')",$xpath,"[",$position,"]"))    
    let $html := transform:transform($fragment, $xsl, ())    
    
    (\: Navigation bauen :\)
    let $navbar := text-viewer:getNavBar($position, "", $totalNr)
    
    return <div>Brieftext: {$navbar, $html}</div>
    :)
    
};

