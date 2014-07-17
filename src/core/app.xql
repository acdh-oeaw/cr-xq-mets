module namespace app="http://sade/app";

import module namespace templates="http://exist-db.org/xquery/templates" at "templates.xql";
import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace project = "http://aac.ac.at/content_repository/project" at "project.xqm";
import module namespace resource="http://aac.ac.at/content_repository/resource" at "resource.xqm";
import module namespace rf="http://aac.ac.at/content_repository/resourcefragment" at "resourcefragment.xqm";
import module namespace config-params="http://exist-db.org/xquery/apps/config-params" at "config.xql";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at  "repo-utils.xqm";

declare namespace xhtml= "http://www.w3.org/1999/xhtml";


(:~ 
OBSOLETED by app:info($key)
reads project title from project-dmd  :)
declare 
    %templates:wrap
function app:title($node as node(), $model as map(*)) {
    config:param-value($model, 'project-title')
 
};

(:~  generates an html-snippet for the templates (with current user and login/logout links)
:)
declare 
    %templates:wrap
function app:user ($node as node(), $model as map(*)) {

    let $back-url := replace(replace(request:get-url(),'http:','https:'),'exist2/apps/cr-xq-mets','lrp')

    let $shib-user := config:shib-user()
    let $user := if ($shib-user) then $shib-user else xmldb:get-current-user()                                     
    return <div id="user" >user: <span class="current-user">{$user}</span><br/> 
        <a href="https://clarin.oeaw.ac.at/Shibboleth.sso/Login?target={$back-url}">Log on</a>|
        <a href="https://clarin.oeaw.ac.at/Shibboleth.sso/Logout">Log off</a></div>
};

declare 
    %templates:wrap
function app:logo($node as node(), $model as map(*)) {
    let $logo-image := config:param-value($model, 'logo-image')
    let $logo-link := if (config:param-value($model, 'logo-link')='') then './' else config:param-value($model, 'logo-link')  
    return 
        <a xmlns="http://www.w3.org/1999/xhtml" href="{$logo-link}" >
            <img src="{$logo-image}" class="logo right"/>
        </a>
};

(:~ generic function to insert (by default html-formatted) application information into the templates
passes onto the config:param-value function to get the data 
:)
declare 
    %templates:wrap
    %templates:default("x-format", "html")
function app:info ($node as node(), $model as map(*), $key, $x-format) {

    let $val := config:param-value($model, $key)
    
    let $ret := 
        if (contains($x-format,'html')) then
            typeswitch ($val)            
                (:case xs:string      return <span class="{$key}">{$val}</span>
                case text()         return <span class="{$key}">{$val}</span>:)
                case element()      return repo-utils:serialise-as($val, $x-format, $key, $model("config"))
                default             return <span class="{$key}">{$val}</span>
        else $val 
 
    return $ret
};


declare 
    %templates:wrap    
    %templates:default("x-format", "html")
function app:list-resources($node as node(), $model as map(*), $x-format) {
   
   let $log := util:log-app("DEBUG",$config:app-name,"app:list-resources") 
(:    let $structMap := project:list-resources($model("config")):)
    (: project/resource:* couldn't correctly handle the config sequence chaos as is in $model("config") 
    so rather give them just the project-pid :) 
    let $project-pid := config:param-value($model("config"),$config:PROJECT_PID_NAME)    
    let $ress := project:list-resources-resolved($project-pid)
    let $log := util:log-app("DEBUG",$config:app-name,"app:list-resources-END")
    (:for $res in $ress
        let $dmd := resource:dmd($res, $model("config") ):)            
        return repo-utils:serialise-as($ress, $x-format, 'resource-list', $model("config"))
(:    return $dmd:)
    
};


declare 
    %templates:wrap    
    %templates:default("x-format", "html")
function app:toc($node as node(), $model as map(*), $x-format) {
    
    let $project-pid := $model('config')/xs:string(@OBJID)
    let $struct := project:get-toc-resolved($project-pid)
                
    return repo-utils:serialise-as($struct, $x-format, 'structMap', $model("config"))
   
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
                    return 
                        if ($visibility != 'private') 
                        then 
                            <div class="teaser" xmlns="http://www.w3.org/1999/xhtml">
                                <img class="teaser" src="{$teaser-image}" />
                                <h3><a href="{$link}">{$title}</a></h3>
                                {$teaser-text}
                            </div> 
                        else ()

(:    return $projects:)
};
