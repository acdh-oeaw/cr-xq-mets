xquery version "1.0";

import module namespace config="http://exist-db.org/xquery/apps/config" at "core/config.xqm";
import module namespace login="http://exist-db.org/xquery/login" at "resource:org/exist/xquery/modules/persistentlogin/login.xql";

declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;
declare variable $exist:prefix external;
declare variable $exist:root external;


(:let $params := text:groups($exist:path, '^([^/]+)*/([^/]+)$'):)
let $params := tokenize($exist:path, '/')

 let $project :=  if (config:project-exists($params[2])) then $params[2] 
                  else if (config:project-exists(request:get-parameter('project',"default"))) then 
                            request:get-parameter('project',"default") 
                  else "default" 
                  
let $project-config :=  config:project-config($project)
let $project-config-map := map { "config" := $project-config}
let $full-config :=  config:config($project) 
let $full-config-map := map { "config" := $full-config}

 let $modules := config:list-modules()
let $module := if ($params[3] = $modules) then $params[3] else ''
let $module-protected := config:param-value((),$full-config-map,$module,'','visibility',true())='protected'
let $module-users := tokenize(config:param-value((),$full-config-map,$module,'','users',true()),',')

 let $template-id := config:param-value($project-config-map,'template')
 
 let $file-type := tokenize($exist:resource,'\.')[last()]
 (: remove project from the path to the resource  needed for web-resources (css, js, ...) :)
 let $rel-path := if (contains($exist:path,$project )) then substring-after($exist:path, $project) else $exist:path
 
 let $protected := config:param-value($project-config-map,'visibility')='protected'
 let $allowed-users := tokenize(config:param-value($full-config-map,'users'),',')
 
return         

if ($exist:path eq "/" or $rel-path eq "/") then
    (: forward root (project) path to index.html :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="index.html"/>
    </dispatch>
else      
 if (ends-with($exist:resource, ".html")) then
 
 (: this is a sequence of two steps, delivering result XOR (either one or the other)
    the first one only delivers result if login is necessary
    the second one, only if login is not necessary (i.e. project not protected or user already logged-in)
    :)
    (if ($protected) then 
       (login:set-user("org.exist.demo.login", (), false()),    
            if (not(request:get-attribute("org.exist.demo.login.user")=$allowed-users)) then
 
              <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
                  <forward url="{$exist:controller}/modules/access-control/login.html"/>
                  <view>
                      <forward url="{$exist:controller}/core/view.xql">
                          <add-parameter name="project" value="{$project}"/>
                  <add-parameter name="exist-path" value="{$exist:path}"/>
                  <add-parameter name="exist-resource" value="{$exist:resource}"/>
                  <add-parameter name="exist-controller" value="{$exist:controller}"/>
                  <add-parameter name="exist-root" value="{$exist:root}"/>
                  <add-parameter name="exist-prefix" value="{$exist:prefix}"/>
                          <set-header name="Cache-Control" value="no-cache"/>
                      </forward>
                  </view>
              </dispatch>
           else () (: it is an allowed user, so just go to the second part :) 
        )
    else (), (: not protected, so also go to second part :)

   if (not($protected) or request:get-attribute("org.exist.demo.login.user")=$allowed-users) then
    let $user := request:get-attribute("org.exist.demo.login.user")
   let $path := config:resolve-template-to-uri($project-config-map, $rel-path)
    (:      <forward url="{$exist:controller}/{$config:templates-dir}{$template-id}/{$exist:resource}"/>
         :)
    return  <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
         <forward url="{$path}" />
          
          <view>
            <forward url="{$exist:controller}/core/view.xql" >
                <add-parameter name="project" value="{$project}"/>
                <add-parameter name="user" value="{$user}"/>
                <add-parameter name="exist-path" value="{$exist:path}"/>
                <add-parameter name="exist-resource" value="{$exist:resource}"/>
                <add-parameter name="exist-controller" value="{$exist:controller}"/>
                <add-parameter name="exist-root" value="{$exist:root}"/>
                <add-parameter name="exist-prefix" value="{$exist:prefix}"/>
            </forward>
        	<error-handler>
    			<forward url="{$exist:controller}/error-page.html" method="get"/>
    			<forward url="{$exist:controller}/core/view.xql"/>
    		</error-handler>
    	   </view>
        </dispatch>
    else () (: login :)
    )
(: Requests for js, css are resolved via our special resolver 
<forward url="{concat('/sade/templates/', $template-id, '/', $rel-path )}" />
:)
else if ($file-type = ('js', 'css', 'png', 'jpg', 'gif', 'pdf')) then
    (: if called from a module (with separate path-step (currently only /get) :)
    let $corr-rel-path := if (starts-with($rel-path, "/get")) then substring-after($rel-path, '/get') else $rel-path
    let $path := config:resolve-template-to-uri($project-config-map, $corr-rel-path)
    return 
        (: daniel 2013-06-12 catch requests for facsimile :)
        if (starts-with($path,'/facs'))
        then
            <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
                <forward url="{$exist:controller}/modules/facsviewer/facsviewer.xql" >
                    <add-parameter name="project" value="{$project}"/>
                    <add-parameter name="exist-path" value="{$exist:path}"/>
                    <add-parameter name="exist-resource" value="{$exist:resource}"/>
                </forward>
            </dispatch>
            
        else
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <forward url="{$path}" />        
        </dispatch>
(: DEBUG
else if (not($module='')) then
    (login:set-user("org.exist.demo.login", (), false()),
        <a>{tokenize(config:param-value($full-config-map,'users'),',')}</a>)
else if (false()) then
:)        
 else if (not($module='')) then
   (if ($module-protected) then 
       (login:set-user("org.exist.demo.login", (), false()),    
            if (not(request:get-attribute("org.exist.demo.login.user")=$module-users)) then
 
               <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
                  <forward url="{$exist:controller}/modules/access-control/login.html"/>
                  <view>
                      <forward url="{$exist:controller}/core/view.xql">
                          <add-parameter name="project" value="{$project}"/>
                  <add-parameter name="exist-path" value="{$exist:path}"/>
                  <add-parameter name="exist-resource" value="{$exist:resource}"/>
                  <add-parameter name="exist-controller" value="{$exist:controller}"/>
                  <add-parameter name="exist-root" value="{$exist:root}"/>
                  <add-parameter name="exist-prefix" value="{$exist:prefix}"/>
                          <set-header name="Cache-Control" value="no-cache"/>
                      </forward>
                  </view>
              </dispatch>
           else () (: it is an allowed user, so just go to the second part :) 
        )
    else (), (: not protected, so also go to second part :)

   if (not($module-protected) or request:get-attribute("org.exist.demo.login.user")=$module-users) then
    let $user := request:get-attribute("org.exist.demo.login.user")
   let $path := config:resolve-template-to-uri($project-config-map, $rel-path)
    (:      <forward url="{$exist:controller}/{$config:templates-dir}{$template-id}/{$exist:resource}"/>
         :)
      
     return  <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <forward url="{$exist:controller}/modules/{$module}/{$module}.xql" >
                <add-parameter name="project" value="{$project}"/>
                <add-parameter name="user" value="{$user}"/>
                <add-parameter name="exist-path" value="{$exist:path}"/>
                <add-parameter name="exist-resource" value="{$exist:resource}"/>
            </forward>    	
        </dispatch>
        
    else () (: login :)
    )

else if (contains($exist:path, "fcs")) then

<dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/modules/fcs/fcs.xql" >
            <add-parameter name="project" value="{$project}"/>
            <add-parameter name="exist-path" value="{$exist:path}"/>
            <add-parameter name="exist-resource" value="{$exist:resource}"/>
        </forward>
	
    </dispatch>
else if (contains($exist:path, "aqay")) then

<dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/modules/aqay/aqay.xql" >
            <add-parameter name="project" value="{$project}"/>
            <add-parameter name="exist-path" value="{$exist:path}"/>
            <add-parameter name="exist-resource" value="{$exist:resource}"/>
        </forward>
	
    </dispatch>
else if (contains($exist:path, "resource")) then

<dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/modules/resource/resource.xql" >
            <add-parameter name="project" value="{$project}"/>
            <add-parameter name="exist-path" value="{$exist:path}"/>
            <add-parameter name="exist-resource" value="{$exist:resource}"/>
        </forward>
	
    </dispatch>
else if (starts-with($rel-path, "/get")) then
(:        <forward url="{$exist:controller}/modules/viewer/get.xql" >
<forward url="index.html" />
      <view>
       :)
let $id := request:get-parameter ('id',substring-after($rel-path,'/get/'))
let $format := request:get-parameter ('format','xml')
return
    if ($format='xml') then
       <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
                  <forward url="{$exist:controller}/modules/viewer/get.xql" >
                   <add-parameter name="resource-id" value="{$id}"/>
                   <add-parameter name="project" value="{$project}"/>
                   <add-parameter name="exist-path" value="{$exist:path}"/>
                   <add-parameter name="exist-resource" value="{$exist:resource}"/>
               </forward>
           </dispatch>
     else
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
                  <forward url="{$exist:controller}/modules/viewer/get.xql" >
                   <add-parameter name="resource-id" value="{$id}"/>
                   <add-parameter name="project" value="{$project}"/>
                   <add-parameter name="exist-path" value="{$exist:path}"/>
                   <add-parameter name="exist-resource" value="{$exist:resource}"/>
               </forward>
              <view>
                <forward url="{$exist:controller}/core/view.xql" >
                    <add-parameter name="project" value="{$project}"/>
                    <add-parameter name="exist-path" value="{$exist:path}"/>
                    <add-parameter name="exist-resource" value="{$exist:resource}"/>
                    <add-parameter name="exist-controller" value="{$exist:controller}"/>
                    <add-parameter name="exist-root" value="{$exist:root}"/>
                    <add-parameter name="exist-prefix" value="{$exist:prefix}"/>
                </forward>
              </view>
        </dispatch>
        
else
(:   <result>{$rel-path}</result>  :)
  (: everything else is passed through :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <cache-control cache="yes"/>
    </dispatch>

  (:<dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="/default/index.html"/>
    </dispatch>
:)  
