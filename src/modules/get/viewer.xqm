xquery version "3.0";

module namespace viewer = "http://sade/viewer" ;
declare namespace templates="http://exist-db.org/xquery/templates";
import module namespace config="http://exist-db.org/xquery/apps/config" at "../../core/config.xqm";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at  "../../core/repo-utils.xqm";
import module namespace cr = "http://aac.ac.at/content_repository" at  "../../core/cr.xqm";
import module namespace resource = "http://aac.ac.at/content_repository/resource" at  "../resource/resource.xqm";
import module namespace project = "http://aac.ac.at/content_repository/project" at  "../resource/project.xqm";
(:declare namespace tei = "http://www.tei-c.org/ns/1.0" ;:)

(:~ default viewer, fetching data, transforming with xslt 
based on text-viewer 
relies to get the data-fragments on (the new) cr or resource modules
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
declare function viewer:display($config-map, $id as xs:string, $project as xs:string, $type as xs:string, $format as xs:string) as item()* {
    viewer:display($config-map,$id,$project,$type,(),$format)
};

declare function viewer:display($config-map, $id as xs:string, $project as xs:string, $type as xs:string, $subtype as xs:string?, $format as xs:string) as item()* {    
    
    let $data := 
                switch ($type)
                    case 'data' return 
                        if ($id = $project)
                            then () (: we don't want to return the whole data of a proejct ... :)
                            else cr:resolve-id-to-data($id,false())
                    case 'metadata' return
                        if ($id = $project)
                        then project:dmd($project) (: projects currently only have CMDI metadata :)
                        else 
                            if ($subtype!='')
                            then resource:dmd-from-id($subtype, $id, $project)
                            else resource:dmd-from-id($id, $project)
                    default return cr:resolve-id-to-entry($id)
    
(:    let $params := <parameters>
                        <param name="format" value="{$format}"/>
                  		<param name="base_url" value="{config:param-value($config-map,'base-url')}"/>

                  </parameters>
:)(:                  		modules/shared/scripts:)
(:<param name="base_url" value="{repo-utils:base-url($config)}"/>:)
                  
     return if ($format='xml') then
                $data
            else repo-utils:serialise-as($data, $format, $type, $config-map, ()) 
            (:<div class="templates:init">
               <div class="templates:surround?with=page.html&amp;at=content-container">
                { repo-utils:serialise-as($data, $format, 'cr-data', $config-map, ()) }
              </div>
             </div>:)
    
    
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

