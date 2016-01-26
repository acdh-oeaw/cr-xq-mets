xquery version "3.0";

module namespace viewer = "http://sade/viewer" ;
declare namespace templates="http://exist-db.org/xquery/templates";
import module namespace config="http://exist-db.org/xquery/apps/config" at "../../core/config.xqm";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at  "../../core/repo-utils.xqm";
import module namespace cr = "http://aac.ac.at/content_repository" at  "../../core/cr.xqm";
import module namespace resource = "http://aac.ac.at/content_repository/resource" at  "../../core/resource.xqm";
import module namespace project = "http://aac.ac.at/content_repository/project" at  "../../core/project.xqm";
import module namespace index = "http://aac.ac.at/content_repository/index" at  "../../core/index.xqm";
import module namespace f = "http://aac.ac.at/content_repository/file" at "../../core/file.xqm";
import module namespace diag  = "http://www.loc.gov/zing/srw/diagnostic/" at "../diagnostics/diagnostics.xqm";

declare namespace mets = "http://www.loc.gov/METS/";
declare namespace xlink="http://www.w3.org/1999/xlink";

(:declare namespace tei = "http://www.tei-c.org/ns/1.0" ;:)

(:~ default viewer, fetching data, transforming with xslt 
based on text-viewer 
relies to get the data-fragments on (the new) cr or resource modules
:)



(:~
 : Path to the stylesheet which removes any internal attributes (i.e. those in the cr:namespace) from the working copy.
~:)
declare variable $viewer:path-to-export-xsl:=      $config:app-root||"/core/remove-cr-ids.xsl";

(:~
 : The index of name $viewer.md-is-restriced-indexname is applied to the standard metadata record 
 : for a resource and must return a value that can be cast to xs:boolean. 
 : If applying the index returns an empty sequence or a value that cannot be cast to xs:boolean, 
 : the data will not be available in any format (xml, html etc.), 
 :)
declare variable $viewer:md-is-restriced-indexname := 'md.get-data-is-restricted';



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
    (:let $debug := 
        let $d := <debug><id>{$id}</id><project>{$project}</project><type>{$type}</type><subtype>{$subtype}</subtype><format>{$format}</format></debug>
        return util:log-app("INFO",$config:app-name,$d):)
    let $log := util:log-app("DEBUG", $config:app-name, "viewer:display($config-map,"||$id||","||$project||","||$type||","||$subtype||","||$format||")")
    let $data := 
                switch ($type)
                    case 'data' return 
                        if ($id = $project)
                        then () (: we don't want to return the whole data of a proejct ... :)
                        else 
                            let $id-parsed := repo-utils:parse-x-context($id,()),
                                $resource-pid := $id-parsed("resource-pid")
                            let $is-restricted := 
                                if ($resource-pid!='') 
                                then index:apply-index(resource:dmd($resource-pid,$project),$viewer:md-is-restriced-indexname,$project,'match')
                                else  diag:diagnostics('record-does-not-exist','Could determine project-id from supplied id '||$id)
                            return 
                                switch (true())
                                    case ($resource-pid='') return diag:diagnostics('record-does-not-exist','Could determine project-id from supplied id '||$id) 
                                    case ($is-restricted) return diag:diagnostics('record-not-authorised-to-send',('access to the data of this resource is restriced. Please refer to its metadata for further information.'))
                                    case (not($is-restricted instance of xs:boolean)) return diag:diagnostics('general-error','value "'||$is-restricted||'" is unsuitable to determine whether data access is restriced or not')
                                    default return cr:resolve-id-to-data($id,false())
                    
                    case 'metadata' return
                        if ($id = $project)
                        then project:dmd($project) (: projects currently only have CMDI metadata :)
                        else
                            let $resource-pid := repo-utils:context-to-resource-pid($id)("resource-pid")
                            let $data := 
                                if ($subtype!='')
                                then resource:dmd-from-id($subtype, $resource-pid, $project)
                                else resource:dmd-from-id($resource-pid, $project)
                            return $data
                    
                   (: case 'show' return 
                        switch (true())
                            case ($id = $project) return viewer:display($config-map,$id,$project,'redirect',$subtype,$format)
                            case ()
                            default return ():)
                    
                    case 'redirect' return
                        let $corpusPage := f:get-file-entry('projectCorpusAccessPage', $project)/mets:FLocat/replace(@xlink:href,'^.+/',''),
                            $corpusURI := project:base-url($project)||"/"||$corpusPage    
                        let $id-parsed := repo-utils:parse-x-context($id,())
                        let $resource-pid := $id-parsed("resource-pid"),
                            $rf-pid := $id-parsed("resourcefragment-pid")
                        let $q_param :=
                            switch (true())
                                case ($rf-pid!='') return "?detail.query=fcs.rf="||$rf-pid
                                case ($resource-pid!='') return "?detail.query=fcs.r=*&amp;x-highlight=off&amp;x-context="||$resource-pid
                                default return ()
                        return response:redirect-to(xs:anyURI($corpusURI||$q_param))
                    default return cr:resolve-id-to-entry($id)
    
(:    let $params := <parameters>
                        <param name="format" value="{$format}"/>
                  		<param name="base_url" value="{config:param-value($config-map,'base-url')}"/>

                  </parameters>
:)(:                  		modules/shared/scripts:)

     return if ($format='xml') then
                let $xsl := doc($viewer:path-to-export-xsl)
                return 
                    if ($xsl)
                    then transform:transform($data,$xsl,())
                    else ($data,util:log-app($config:app-name,"ERROR","$viewer:path-to-export-xsl was not found at "||$viewer:path-to-export-xsl))
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

