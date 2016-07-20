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

module namespace app="http://sade/app";

import module namespace templates="http://exist-db.org/xquery/templates" at "templates.xql";
import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace project = "http://aac.ac.at/content_repository/project" at "project.xqm";
import module namespace resource="http://aac.ac.at/content_repository/resource" at "resource.xqm";
import module namespace rf="http://aac.ac.at/content_repository/resourcefragment" at "resourcefragment.xqm";
import module namespace config-params="http://exist-db.org/xquery/apps/config-params" at "config.xql";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at  "repo-utils.xqm";
import module namespace f="http://aac.ac.at/content_repository/file" at "file.xqm";
import module namespace functx = "http://www.functx.com";

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
           { if ($shib-user) then <a href="https://clarin.oeaw.ac.at/Shibboleth.sso/Logout">Log off</a>
                else if (not($user = 'guest')) then  <a href=".?logout=true">Log out</a>
                else <a href="https://clarin.oeaw.ac.at/Shibboleth.sso/Login?target={$back-url}">Log on</a>
             }
           </div>
        
};

declare 
    %templates:wrap
function app:logo($node as node(), $model as map(*)) {
    let $logo-image := config:param-value($model, 'logo-image')
    let $logo-link := if (config:param-value($model, 'logo-link')='') then './' else config:param-value($model, 'logo-link')  
    return
        if ($logo-image != '' and $logo-link != '') then
        <a xmlns="http://www.w3.org/1999/xhtml" href="{$logo-link}" >
            <img src="{$logo-image}" class="logo right"/>
        </a>
        else        
        <a xmlns="http://www.w3.org/1999/xhtml" href="./index.html" >
            <img src="modules/shared/default_logo.png" class="logo right"/>
        </a>
};

(:~ generic function to insert (by default html-formatted) application information into the templates
passes onto the config:param-value function to get the data 
:)
declare 
    %templates:wrap
    %templates:default("x-format", "html")
function app:info ($node as node(), $model as map(*), $key, $x-format) {

    let $val := config:param-value($model, $key),
        $log := (util:log-app("DEBUG",$config:app-name,"app:info $key = "||$key),
                 util:log-app("TRACE",$config:app-name,"app:info $val = "||substring(serialize($val),1,240)))
    
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
    %templates:default("maximumTerms", "800")
function app:list-resources($node as node(), $model as map(*), $x-format as xs:string, $maximumTerms as xs:integer) {
   
   let $log := util:log-app("DEBUG",$config:app-name,"app:list-resources") 
(:    let $structMap := project:list-resources($model("config")):)
    (: project/resource:* couldn't correctly handle the config sequence chaos as is in $model("config") 
    so rather give them just the project-pid :) 
    let $project-pid := config:param-value($model("config"),$config:PROJECT_PID_NAME),    
        $ress := project:list-resources-resolved($project-pid)
(:        , $log := util:log-app("DEBUG",$config:app-name,"app:list-resources: $project-pid = "||$project-pid||" $ress = "||$ress):)
    (:for $res in $ress
        let $dmd := resource:dmd($res, $model("config") ):)            
        return repo-utils:serialise-as($ress, $x-format, 'resource-list', $model("config"), <parameters><param name="maximumTerms" value="{$maximumTerms}"/></parameters>)
(:    return $dmd:)
    
};


declare 
    %templates:wrap    
    %templates:default("x-format", "html")
function app:list-files($node as node(), $model as map(*), $fg-key, $x-format) {
   
(:   let $log := util:log-app("DEBUG",$config:app-name,"app:list-files") :)

    let $project-pid := config:param-value($model("config"),$config:PROJECT_PID_NAME)    
    let $fg := f:get-filegrp-entry($fg-key, $project-pid)
(:    let $log := util:log-app("DEBUG",$config:app-name,"app:list-resources-END"):)
    (:for $res in $ress
        let $dmd := resource:dmd($res, $model("config") ):)            
        return repo-utils:serialise-as($fg, $x-format, 'file-list', $model("config"))
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

declare
%templates:wrap
%templates:default("filter", "")
%templates:default("x-format", "html")
%templates:default("res-type", "xml")
function app:include-detail($node as node(), $model as map(*), $path-detail as xs:string, $filter as xs:string, $res-type as xs:string, $x-format as xs:string) {
    let $content := config:resolve($model, $path-detail)
        let $log := util:log-app("DEBUG",$config:app-name,"app:include-detail.path-detail: "||$path-detail||" res-type:"||$res-type)
    let $restricted-content := if ($filter != '' and exists($content)) then 
            (: try to handle namespaces dynamically 
                by switching  to source namespace :)
            let $ns-uri := namespace-uri($content[1]/*)        	       
            let $ns := util:declare-namespace("",xs:anyURI($ns-uri))
           return util:eval(concat("$content//", $filter)) else $content 
    return if ($x-format='') then templates:process($restricted-content , $model)
             else repo-utils:serialise-as($content, $x-format, $res-type, $model("config"))
};
declare
%templates:wrap
%templates:default("lang", "en")
function app:language-switch($node as node(), $model as map(*), $lang as xs:string) as node() {
    let $log := util:log-app("DEBUG",$config:app-name,"app:language-switch $lang := "||$lang),
        $langCodeToNames := map {
            "en" := "English",
            "de" := "Deutsch"
        },
        $lang-ext := if ($lang != 'en') then "-"||$lang else "",
        $filename-with-code := functx:substring-after-last(request:get-attribute("$exist:path"), '/'),
        $fileext := functx:substring-after-last($filename-with-code, '.'),
        $filename-without-code := functx:substring-before-last($filename-with-code, '-'),
        $filename := if ($filename-without-code != "") then $filename-without-code else functx:substring-before-last($filename-with-code, '.'),
        $path-after-controller := functx:substring-before-last(request:get-attribute("$exist:path"), '/'),
        $target := request:get-attribute("$exist:context")||request:get-attribute("$exist:prefix")||request:get-attribute("$exist:controller")||$path-after-controller||"/"||$filename||$lang-ext||"."||$fileext,
        $ret := <a href="{$target}">{$langCodeToNames($lang)}</a>,
        $logRet := util:log-app("DEBUG",$config:app-name,"app:language-switch return "||serialize($ret))
    return $ret    
};
