xquery version "3.0";
(:~
 : Main rewrite controller for the cr-xq content repository.
 :  
 : @author Daniel Schopper 
 : @author vronk
~:)

import module namespace config="http://exist-db.org/xquery/apps/config" at "core/config.xqm";
import module namespace login="http://exist-db.org/xquery/login" at "resource:org/exist/xquery/modules/persistentlogin/login.xql";
import module namespace projectAdmin="http://aac.ac.at/content_repository/projectAdmin" at "modules/projectAdmin/projectAdmin.xqm";

declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;
declare variable $exist:prefix external;
declare variable $exist:root external;



(:~ if debug=controller - divert to debugging controller
if debug set at all (possible config:app-info() is activated in the UI (depends on the template)
:)
let $debug := request:get-parameter("debug", '')
(:~
 : The variable <code>$params</code> holds contextual request parameters. 
 : Tokenizing the $exist:path by slashes we expect the following structure:   
 : request = "http://host/exist/apps/cr-xq/abacus/fcs?query=string"
 : $exist:path = "/cr-xq/abacus/fcs?query=string"
 : $params[1] = ""
 : $params[2] = ID of cr-project
 : $params[3] = optionally: name of a core module to operate in the current project's scope, 
                for example the 'resource' module, which summarizes the structure of a project's resources.   
~:)
let $params := tokenize($exist:path, '/')

(:~
 : The variable <code>$cr-instance</code> holds the base path of the current content repository instance.
 :  
 : This allows to differentiat between logins to concurrent cr-instances by setting unique login domains.
 : 
 : @see $domain   
~:)
let $cr-instance := $params[1]  

(:~
 : The variable <code>$project</code> holds the ID of the current project. 
 : Its value is determined by:
 :  <ul>
 :      <li>the request path</li>
 :      <li>a explicit request parameter named 'project'</li>
 :  </ul>
 : If none of these two is set or the requested project does not exist, it falls back on the 'default' project.
~:)
let $project := 
    if (config:project-exists($params[2])) 
    then $params[2]
    else 
        if (config:project-exists(request:get-parameter('project',$config:DEFAULT_PROJECT_ID))) 
        then request:get-parameter('project',$config:DEFAULT_PROJECT_ID)
        else $config:DEFAULT_PROJECT_ID

(:~ if x-context parameter not set, set project-id as x-context :)
let $x-context := request:get-parameter("x-context", $project)

(:~
 : The variable <code>$project-config</code> holds the current project's configuration, 
 : i.e. it's <code>project.xml</code> setup.  
~:)
let $project-config :=  config:project-config($project)

(:~
 : The variable <code>$project-config-map</code> holds a map containing the 
 : current project's <code>project.xml</code> setup at under one single <code>config</code> key.
 : This map is passed into the templating framework and is queried by most subsequent 
 : functions. 
~:)
let $project-config-map := map { "config" := $project-config}

(:~
 : The variables <code>$full-config</code> and <code>$full-config-map</code> hold: 
 : <ol>
 :      <li>the current project's catalog</li>
 :      <li>the configuration files (<code>conf.xml</code>) of all available cr-xq modules located in $app-root/modules</li>
 : </ol>
~:)
let $full-config :=  config:config($project), 
    $full-config-map := map { "config" := $full-config}
    

(:~ 
 : The variable <code>$module</code> contains the name of a cr-xq module which is 
 : requested to work in the current project's scope. 
 : 
 : Will be an empty string if the name does not refer to an available module. 
~:)
let $module := 
        if ($params[3] = config:list-modules()) 
        then $params[3]            
        else if ($project = $config:DEFAULT_PROJECT_ID) then $params[2]
        else ''

(:~
 : The variable <code>$module-protected</code> holds a boolean value determining 
 : whether the requested cr-xq module may only be used by a closed list of 
 : users (<code>true()</code>) or by any user (<code>false()</code>).
 :
 : Defaults to <code>false()</code> when the parameter 'visibility' in the modules's 
 : configuration file (<code>config.xml</code>) is not set or has a value other than 'protected'.  
 ~:)
let $module-protected := config:param-value((),$full-config-map,$module,'','visibility',true())='protected'

(:~
 : The varible <code>$module-users</code> holds a sequence of user names which 
 : have rights to use the requested cr-xq module. This is set as comma separated values
 : in the module's <code>conf.xml</code>.   
~:)
let $module-users := tokenize(config:param-value((),$full-config-map,$module,'','users',true()),'\s*,\s*')



(:~
 : The variable <code>$template-id</code> holds the name of the set of HTML templates 
 : the current project is using. This is set in the project's configuration.  
~:)
let $template-id := config:param-value($project-config-map,'template')
 

(:~
 : The variable <code>$file-type</code> holds the requested resource's filename suffix. 
~:)
let $file-type := tokenize($exist:resource,'\.')[last()]

(:~
 : The variable <code>$web-resources</code> contains filename suffixes of thos file types whose
 : actual location in the database should be autogmagically resolved by config:resolve-template-to-uri().
 : This is used to serve files which reside in 'templates'.  
~:)
let $web-resources := ('js', 'css', 'png', 'jpg', 'gif', 'pdf', 'ttf', 'woff', 'eot')

(: remove project from the path to the resource needed for web-resources (css, js, ...) :)
let $rel-path := 
    if (contains($exist:path,$project)) 
    then substring-after($exist:path, $project) 
    else $exist:path
 

(:~
 : The variable <code>$protected</code> holds a boolean value determining 
 : whether the current project is to be accessed only by a closed list of users
 : (<code>true()</code>) or by all users (<code>false()</code>).
 :
 : Defaults to <code>false()</code> when the parameter 'visibility' in the projects's 
 : configuration file (<code>project.xml</code>) is not set or has a value other than 'protected'.
  
  FIXME: this is inconsistent with the implementation in config:param:value that operates on security-manager information
~:)
let $protected := config:param-value($project-config-map,'visibility')='protected'

(:~
 : The varible <code>$allowed-users</code> holds a sequence of user names which 
 : have rights to accses the requested project. These are set as comma separated values
 : in the project's configuration file (<code>project.xml</code>).
 : FIXME: this is inconsistent with the implementation in config:param:value that operates on security-manager information
~:)
(:let $allowed-users := 'guest' :)
let $user-may := 
        if ($file-type = $web-resources) then true()
        else if (not($protected)) then true()
        else 
        let $allowed-users :=  tokenize(config:param-value($full-config-map,'users'),'\s*,\s*')
        
        let $project-dir := config:param-value($project-config-map,'project-dir')
        (:let $domain:=   "at.ac.aac.exist."||$cr-instance:)
        let $domain:= "org.exist.login"
        
        (: login:set-user() must go before checking the user :) 
        let $login:=login:set-user($domain, (), false())
        
        let $db-user := request:get-attribute($domain||".user")
        (:let $db-current-user := xmldb:get-current-user():)
        let $shib-user := config:shib-user()
        let $user := if ((not(exists($db-user)) or $db-user='guest') and $shib-user) then                    
                            let $login := xmldb:login($project-dir, 'shib', config:param-value($project-config-map,'shib-user-pwd'))
                            return 'shib'
                            else $db-user
        return ($user=$allowed-users)
(:~
 : The variable <code>$domain</code> holds the name of the login domain to which the users  
 : of the current cr-xq instance will be logged into.
 : 
 : This allows to differentiate between logins to different concurrent cr-instances.
 :
 : @see call to login:set-user() below.    
~:)

let $exist-resource-index := if ($exist:path eq "/" or $rel-path eq "/") 
            then 'index.html' 
            else $exist:resource 

return         

switch (true())
    (:~
     : Requests for the bases of the cr-xq instance or a cr-project are redirected 
     : to the 'index.html' view.         
    ~:)
    case ($debug='controller') return
                let $allowed-users :=  tokenize(config:param-value($full-config-map,'users'),'\s*,\s*')
        
        let $project-dir := config:param-value($project-config-map,'project-dir')
        (:let $domain:=   "at.ac.aac.exist."||$cr-instance:)
        let $domain:= "org.exist.login"
        
        (: login:set-user() must go before checking the user :) 
        let $login:=login:set-user($domain, (), false())
        
        let $db-user := request:get-attribute($domain||".user")
        (:let $db-current-user := xmldb:get-current-user():)
        let $shib-user := config:shib-user()
        let $user := if ((not(exists($db-user)) or $db-user='guest') and $shib-user) then                    
                            let $login := xmldb:login($project-dir, 'shib', config:param-value($project-config-map,'shib-user-pwd'))
                            return 'shib'
                            else $db-user
        return
(:        <DEBUG>{$exist-resource-index, '-', $exist:resource }</DEBUG>:)
         <DEBUG >USER exists db-user: {exists($db-user)}; project-dir: {$project-dir}; usermay: {$user-may}; user:{$user}; shib-user:{$shib-user}
         <allowed-users>{$allowed-users}</allowed-users>
         <current-user >{($db-user,'-',xmldb:get-current-user())}</current-user>
         <attrs>{string-join(request:attribute-names(),', ')}</attrs>
         <rel-path>{$rel-path}</rel-path>
         <module>{$module}</module>
         <logout>{request:get-parameter("logout","")}</logout>
         </DEBUG>
         
(:        <DEBUG>module: {$module}, project: {$project} </DEBUG>:)
    (:case (($exist:path eq "/" or $rel-path eq "/" ) return 
        (\: forward root (project) path to index.html :\)
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <redirect url="index.html"/>    
        </dispatch>
    :)    (:let $path := config:resolve-template-to-uri($project-config-map, "index.html")
        return <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
                    <forward url="{$path}" />    
                    <view>
                        <forward url="{$exist:controller}/core/view.xql" >
                            <add-parameter name="project" value="{$project}"/>
                            <add-parameter name="x-context" value="{$x-context}"/>
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
                </dispatch>:)
        
   (: if logout parameter we need to remove it before trying to login - otherwise the login fails b:)        
    case (not(request:get-parameter("logout","")="")) return
        
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <redirect url="index.html"/>    
        </dispatch>
    (:~
     : Requests that should be proxied 
    ~:)
    case ($exist:resource eq "proxy.xql") return 
        let $url := request:get-parameter("url",""),
            $token := util:random()
        let $session := session:set-attribute($url||"-token",$token)
        return
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
                <forward url="{$exist:controller}/proxy.xql">
                    <add-parameter name="{$url}-token" value="{$token}"/>
                    <set-header name="Cache-Control" value="no-cache"/>
                </forward>
        </dispatch>

    (:~
     : Requests for HTML views are handled by the templating system after check for user authorization. 
    ~:)
    case (ends-with($exist-resource-index, ".html")) return
        (: this is a sequence of two steps, delivering result XOR (either one or the other) :)
        (: step 1: only delivers a result if the project's visibility is protected :)
        (if ($protected) 
        then 
            (:let $login:=login:set-user($domain, (), false()):)
(:            return:)
            (:if (not(request:get-attribute($domain||".user")=$allowed-users)):) 
            if (not($user-may))             
            then
(:                let $log:=util:log("INFO",'user='||request:get-attribute($domain||".user")):)
(:                return:)
                <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
                    <forward url="{$exist:controller}/modules/access-control/login.html"/>
                    <view>
                        <forward url="{$exist:controller}/core/view.xql">
                            <add-parameter name="project" value="{$project}"/>
                            <add-parameter name="x-context" value="{$x-context}"/>
                            <add-parameter name="exist-path" value="{$exist:path}"/>
                            <add-parameter name="exist-resource" value="{$exist-resource-index}"/>
                            <add-parameter name="exist-controller" value="{$exist:controller}"/>
                            <add-parameter name="exist-root" value="{$exist:root}"/>
                            <add-parameter name="exist-prefix" value="{$exist:prefix}"/>
                            <set-header name="Cache-Control" value="no-cache"/>
                        </forward>
                    </view>
                </dispatch>
            (: it is an allowed user, so just go to the second part :)
            else ()  
        (: not protected, so also go to second part :)
        else (), 
       
       (: step 2: only delivers result if login is not necessary (i.e. project not protected or user already logged-in) :)
       if (not($protected) or $user-may) 
       then
(:            let $user := request:get-attribute($domain||".user"):)
            let $path := config:resolve-template-to-uri($project-config-map, if ($exist-resource-index='index.html') then $exist-resource-index else $rel-path   )
(:              <add-parameter name="user" value="{$user}"/>:)
            return  
                <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
                    <forward url="{$path}" />    
                    <view>
                        <forward url="{$exist:controller}/core/view.xql" >
                            <add-parameter name="project" value="{$project}"/>
                            <add-parameter name="x-context" value="{$x-context}"/>
                          
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
        (: else login :)
        else () 
        )
        
        
    (:~ 
     : Requests for web resources like JS or CSS are resolved via our special resolver. 
     : Requests for facsimilia which are likely to reside somewhere else, are prefixed 
     : with a "/facs" url-step, and are resolved by the facswiewer module. 
    ~:)
    case ($file-type = $web-resources) return
        (: If the request is made from a module (with separate path-step (currently only /get) :)
        let $corr-rel-path := 
            if (starts-with($rel-path, "/get")) 
            then substring-after($rel-path, '/get') 
            else $rel-path
        let $path := config:resolve-template-to-uri($project-config-map, $corr-rel-path)
        let $facs-requested:=starts-with($path,'/facs')
        return
            if ($facs-requested)
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


    (:~
     : projectAdmin module
    ~:)
    case ($module = "projectAdmin" ) return
(:        let $user := request:get-attribute($domain||".user"):)
        let $path := config:resolve-template-to-uri($project-config-map, $rel-path)
        return
            let $target := 
            	(: requests for xql endpoints (like store.xql) are passed on, 
            	everything else is forwarded to the main xquery projectAdmin.xql :)
            	if (ends-with($exist:resource, "xql"))
            	then $exist:resource
            	else "projectAdmin.xql"
            let $url := $exist:controller||"/modules/"||$module||"/"||$target
            let $path-steps := tokenize($exist:path,'/'), 
                $form := projectAdmin:form($path-steps[4]),
                $form-id :=  if (exists($form))
                             then $path-steps[4]
                             else false()
            let $project := $path-steps[2]
            return
                switch(true())
                    case $target = "store.xql" return
                        let $parameters := 
                            let $maps := 
                                (for $p in request:get-parameter-names() 
                                    let $value := request:get-parameter($p,"")
                                    return 
                                        if ($value!='') 
                                        then () 
                                        else map:entry($p,$value),
                                 for $h in request:get-header-names()
                                    let $val := request:get-header($h)
                                    return 
                                        if ($val!='') 
                                        then () 
                                        else map:entry($h,$val),
                                  map:entry("project-pid",$project)
                                 )
                            return map:new($maps)
                        let $process := projectAdmin:store(request:get-data(),$parameters)
                        return $process
                        
                    case $target = "get.xql" return
                        let $entity := request:get-parameter("entity",""),
                            $log := util:log("INFO", $entity)
                        return projectAdmin:data($project, $entity)
                    
                    case ($form-id or $target != 'projectAdmin.xql') return
(:                    <add-parameter name="user" value="{$user}"/>:)
                        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">   
                            <forward url="{$url}">
                                <add-parameter name="project" value="{$project}"/>
                                
                                <add-parameter name="path" value="{$path}"/>
                                <add-parameter name="exist-path" value="{$exist:path}"/>
                                <add-parameter name="exist-resource" value="{$exist:resource}"/>
                             </forward>
                        </dispatch>
                    
                    default return
                        let $log := util:log("INFO", "redirected request to /exist/"||$exist:prefix||$exist:controller||"/"||$project||"/projectAdmin/start")
                        return
                        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">   
                            <redirect url="/exist/{$exist:prefix}{$exist:controller}/{$project}/projectAdmin/start"/>
                        </dispatch>
      
    (:~
     : Requests for a specific module are forwarded after having checked user authorization. 
    ~:)
    case (not($module='')) return
        (if ($module-protected) 
        then 
            (: CHECK: $logout ?? :)
(:            let $logout:= login:set-user($domain, (), false())
            return :)
                if (not($user-may)) 
                then
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
                (: it is an allowed user, so just go to the second part :)
                else ()
        (: not protected, so also go to second part :)
        else (), 
        
        if (not($module-protected) or $user-may) 
        then
(:            let $user := request:get-attribute($domain||".user")          :)
            (: used by get-module :)          
            let $corr-rel-path := if (starts-with($rel-path, "/"||$module)) 
                                  then substring-after($rel-path, "/"||$module) 
                                  else $rel-path
            let $path := config:resolve-template-to-uri($project-config-map, $rel-path)
            return
            	let $target := $module||".xql"
            	let $url := $exist:controller||"/modules/"||$module||"/"||$target
(:            	     <add-parameter name="user" value="{$user}"/>:)
            	return 
                <dispatch xmlns="http://exist.sourceforge.net/NS/exist">   
                    <forward url="{$url}">
                        <add-parameter name="project" value="{$project}"/>
                   
                        <add-parameter name="path" value="{$path}"/>
                        <add-parameter name="exist-path" value="{$exist:path}"/>
                        <add-parameter name="exist-resource" value="{$exist:resource}"/>
                        <add-parameter name="exist-controller" value="{$exist:controller}"/>
                        <add-parameter name="exist-root" value="{$exist:root}"/>
                         <add-parameter name="exist-prefix" value="{$exist:prefix}"/>
                         <add-parameter name="rel-path" value="{$corr-rel-path}"/>
                    </forward>
                </dispatch>
            (: login :)
            else ()
        )

    (:~ 
     : FCS requests are forwarded to the FCS module. 
    ~:)
    case (contains($exist:path, "fcs")) return
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <forward url="{$exist:controller}/modules/fcs/fcs.xql" >
                <add-parameter name="project" value="{$project}"/>
                <add-parameter name="exist-path" value="{$exist:path}"/>
                <add-parameter name="exist-resource" value="{$exist:resource}"/>
            </forward>
    	</dispatch>
    
    
    (:~
     : AQAY Requests are forwarded to the aqay module: 
    ~:)
    case (contains($exist:path, "aqay")) return
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <forward url="{$exist:controller}/modules/aqay/aqay.xql" >
                <add-parameter name="project" value="{$project}"/>
                <add-parameter name="exist-path" value="{$exist:path}"/>
                <add-parameter name="exist-resource" value="{$exist:resource}"/>
            </forward>
        </dispatch>
    (:~
     : Requests for specific resources are forwarded to the resource module: 
    ~:)
    case (contains($exist:path, "resource")) return
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <forward url="{$exist:controller}/modules/resource/resource.xql" >
                <add-parameter name="project" value="{$project}"/>
                <add-parameter name="exist-path" value="{$exist:path}"/>
                <add-parameter name="exist-resource" value="{$exist:resource}"/>
            </forward>
        </dispatch>
    

   (: case (starts-with($rel-path, "/get")) return
        let $id := request:get-parameter ('id',substring-before(substring-after($rel-path,'/get/'),'/'))
        let $format := request:get-parameter('format','xml')
        return
            if ($format='xml') 
            then
                <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
                    <forward url="{$exist:controller}/modules/get/get.xql">
                        <add-parameter name="resource-id" value="{$id}"/>
                        <add-parameter name="project" value="{$project}"/>
                        <add-parameter name="rel-path" value="{$rel-path}"/>
                        <add-parameter name="exist-path" value="{$exist:path}"/>
                        <add-parameter name="exist-resource" value="{$exist:resource}"/>
                    </forward>
                </dispatch>
             else
                <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
                    <forward url="{$exist:controller}/modules/get/get.xql">
                        <add-parameter name="resource-id" value="{$id}"/>
                        <add-parameter name="project" value="{$project}"/>
                        <add-parameter name="exist-path" value="{$exist:path}"/>
                        <add-parameter name="rel-path" value="{$rel-path}"/>
                        <add-parameter name="exist-resource" value="{$exist:resource}"/>
                    </forward>
                    <view>
                        <forward url="{$exist:controller}/core/view.xql">
                            <add-parameter name="project" value="{$project}"/>
                            <add-parameter name="exist-path" value="{$exist:path}"/>
                            <add-parameter name="exist-resource" value="{$exist:resource}"/>
                            <add-parameter name="exist-controller" value="{$exist:controller}"/>
                            <add-parameter name="exist-root" value="{$exist:root}"/>
                            <add-parameter name="exist-prefix" value="{$exist:prefix}"/>
                        </forward>
                    </view>
                </dispatch>
        :)
    default return
    (:~
     : everything else is passed through 
    ~:)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <cache-control cache="yes"/>
    </dispatch>