module namespace app="http://sade/app";

import module namespace templates="http://exist-db.org/xquery/templates" at "templates.xql";
import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace config-params="http://exist-db.org/xquery/apps/config-params" at "config.xql";
(:
import module namespace templates="http://exist-db.org/xquery/templates" at "templates.xql";

import module namespace kwic="http://exist-db.org/xquery/kwic"
    at "resource:org/exist/xquery/lib/kwic.xql";
import module namespace fcs = "http://clarin.eu/fcs/1.0" at "/db/cr/fcs.xqm";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at  "/db/cr/repo-utils.xqm";
:)

 (:
declare 
    %templates:wrap
function app:init($node as node(), $model as map(*), $project as xs:string?) {
        let $project-config-path := concat($config:projects-dir, $project, "/config.xml")
        let $project-resolved := if (doc-available($project-config-path)) then $project else "no such project"
        let $project-config := if (doc-available($project-config-path)) then doc($project-config-path) else ()
        return map { "config" := $project-config 
        }
:)
 (:   <p>{$project}</p>:)
 
        (:    <p>exist:root {request:get-attribute("$exist:root")}<br/>
        exist:resource {request:get-attribute("$exist:resource")}<br/>
        exist:path {request:get-attribute("$exist:path")}<br/>
        exist:controller {request:get-attribute("$exist:controller")}<br/>
        exist:prefix {request:get-attribute("$exist:prefix")}<br/>
        get-uri {request:get-uri()}<br/>
        config:app-root {$config:app-root}<br/>
        
</p>
};:)

declare 
    %templates:wrap
function app:title($node as node(), $model as map(*)) {
(:    $model("config")//param[xs:string(@key)='project-title']:)
config:param-value($model, 'project-title')
(:    <p>exist:root {request:get-attribute("$exist:root")}<br/>
        exist:resource {request:get-attribute("$exist:resource")}<br/>
        exist:path {request:get-attribute("$exist:path")}<br/>
        exist:controller {request:get-attribute("$exist:controller")}<br/>
        exist:prefix {request:get-attribute("$exist:prefix")}<br/>
        get-uri {request:get-uri()}<br/>
        config:app-root {$config:app-root}<br/>
        
</p>:)
};

declare 
    %templates:wrap
function app:logo($node as node(), $model as map(*)) {

    let $logo-image := config:param-value($model, 'logo-image')
    let $logo-link := config:param-value($model, 'logo-link')
    
    return <a href="{$logo-link}" target="_blank">
                    <img src="{$logo-image}" class="logo right"/>
                </a>
           
};



declare 
    %templates:wrap
    %templates:default("filter", "")
function app:list-projects($node as node(), $model as map(*), $filter as xs:string) {

    let $filter-seq:= tokenize($filter,',')
    let  $projects := if ($filter='') then config:list-projects()
                        else $filter-seq
    
    (: get the absolute path to controller, for the image-urls :)
    let $exist-controller := config:param-value($model, 'exist-controller')
    let $request-uri:= config:param-value($model, 'request-uri')
    let $base-uri:= if (contains($request-uri,$exist-controller)) then 
                        concat(substring-before($request-uri,$exist-controller),$exist-controller)
                      else $request-uri
    
    for $pid in $projects
    
                    let $config-map := map { "config" := config:project-config($pid)}
                    (: try to get the base-project (could be different then the current $project-id for the only-config-projects :) 
                    let $config-dir := substring-after(config:param-value($config-map, 'project-dir'),$config-params:projects-dir)
                    let $visibility := config:param-value($config-map, 'visibility')                 
                    let $title := config:param-value($config-map, 'project-title')
                    let $link := if (config:param-value($config-map, 'project-url')!='') then
                                        config:param-value($config-map, 'project-url')
                                        else  concat($base-uri, '/', $pid, '/index.html')
                    let $teaser-image :=  concat($base-uri, '/', $config-dir, config:param-value($config-map, 'teaser-image'))
                    let $teaser-text:= if (config:param-value($config-map, 'teaser-text')!='') then
                                            config:param-value($config-map, 'teaser-text')
                                        else
(:                                        welcome message as fallback for teaser:)
                                            let $teaser := collection(config:param-value($config-map, 'project-static-dir'))//*[xs:string(@id)= 'teaser'][1]/p
                                            let $welcome := collection(config:param-value($config-map, 'project-static-dir'))//*[xs:string(@id)='welcome'][1]/p
                                            return if ($teaser) then $teaser else $welcome
                                                                                    
                                          
                    
(:                                let $teaser := config:param-value($config-map, 'teaser'):)
                    return if ($visibility != 'private') then <div class="teaser" xmlns="http://www.w3.org/1999/xhtml"><img class="teaser" src="{$teaser-image}" /> <h3><a href="{$link}" >{$title}</a></h3>
                                     {$teaser-text}
                            </div> else ()

(:    return $projects:)
};