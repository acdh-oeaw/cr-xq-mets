xquery version "3.0";

import module namespace config="http://exist-db.org/xquery/apps/config" at "core/config.xqm";
import module namespace login="http://exist-db.org/xquery/login" at "resource:org/exist/xquery/modules/persistentlogin/login.xql";

declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;
declare variable $exist:prefix external;
declare variable $exist:root external;

(:~
 : Tokenizing the request path we expect the following structure:
 : $exist:path = "http://host/exist/apps/cr-xq/abacus/fcs?query=string"
 : $params[1] = eXist-app context, e.g. "cr-xq"
 : $params[2] = ID of cr-project
 : $params[3] = optionally: name of a core module to operate in the current project's scope, 
                for example the 'resource' module, which summarizes the structure of a project's resources.   
~:)
let $params := tokenize($exist:path, '/')

(:~
 : 
 
 :  
~:)
let $project := 
    if (config:project-exists($params[2])) 
    then $params[2]
    else 
        if (config:project-exists(request:get-parameter('project',"default"))) 
        then request:get-parameter('project',"default")
        else "default" 
                  
let $project-config :=  config:project-config($project),
    $project-config-map := map { "config" := $project-config}, 
    $full-config :=  config:config($project), 
    $full-config-map := map { "config" := $full-config}

let $modules := config:list-modules(),
    $module := 
        if ($params[3] = $modules) 
        then $params[3] 
        else ''

let $module-protected := config:param-value((),$full-config-map,$module,'','visibility',true())='protected'
let $module-users := tokenize(config:param-value((),$full-config-map,$module,'','users',true()),',')

let $template-id := config:param-value($project-config-map,'template')
 
let $file-type := tokenize($exist:resource,'\.')[last()]
(: remove project from the path to the resource needed for web-resources (css, js, ...) :)
let $rel-path := 
    if (contains($exist:path,$project)) 
    then substring-after($exist:path, $project) 
    else $exist:path
 
let $protected := config:param-value($project-config-map,'visibility')='protected'
let $allowed-users := tokenize(config:param-value($full-config-map,'users'),',')
 
return         

switch (true())
    (:~
     : Request URIs which end on "/" are redirected to index.html.  
    ~:)
    case ($exist:path eq "/" or $rel-path eq "/") return 
        (: forward root (project) path to index.html :)
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <redirect url="index.html"/>
        </dispatch>



    (:~
     : Requests for HTML views are handled by the templating system after check for user authorization. 
    ~:)
    case (ends-with($exist:resource, ".html")) return  
        (: this is a sequence of two steps, delivering result XOR (either one or the other) :)
        (: step 1: only delivers result if login is necessary :)
        (if ($protected) 
        then 
            let $logout:=login:set-user("org.exist.demo.login", (), false())
            return
            if (not(request:get-attribute("org.exist.demo.login.user")=$allowed-users)) 
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
       
       (: step 2: only delivers result if login is not necessary (i.e. project not protected or user already logged-in) :)
       if (not($protected) or request:get-attribute("org.exist.demo.login.user")=$allowed-users) 
       then
            let $user := request:get-attribute("org.exist.demo.login.user")
            let $path := config:resolve-template-to-uri($project-config-map, $rel-path)
            return  
                <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
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
        (: else login :)
        else () 
        )
        
        
    (:~ 
     : Requests for web resources like JS or CSS are resolved via our special resolver. 
     : Requests for facsimilia which are likely to reside somewhere else, are prefixed 
     : with a "/facs" url-step, and are resolved by the facswiewer module. 
    ~:)
    case ($file-type = ('js', 'css', 'png', 'jpg', 'gif', 'pdf')) return
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
     : Requests for a specific module are forwarded after having checked user authorization. 
    ~:)
    case (not($module='')) return
        (if ($module-protected) 
        then 
            let $logout:= login:set-user("org.exist.demo.login", (), false())
            return
                if (not(request:get-attribute("org.exist.demo.login.user")=$module-users)) 
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
        
        if (not($module-protected) or request:get-attribute("org.exist.demo.login.user")=$module-users) 
        then
            let $user := request:get-attribute("org.exist.demo.login.user")
            let $path := config:resolve-template-to-uri($project-config-map, $rel-path)
            return  
                <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
                    <forward url="{$exist:controller}/modules/{$module}/{$module}.xql">
                        <add-parameter name="project" value="{$project}"/>
                        <add-parameter name="user" value="{$user}"/>
                        <add-parameter name="exist-path" value="{$exist:path}"/>
                        <add-parameter name="exist-resource" value="{$exist:resource}"/>
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
    

    case (starts-with($rel-path, "/get")) return
        let $id := request:get-parameter ('id',substring-after($rel-path,'/get/'))
        let $format := request:get-parameter ('format','xml')
        return
            if ($format='xml') 
            then
                <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
                    <forward url="{$exist:controller}/modules/viewer/get.xql">
                        <add-parameter name="resource-id" value="{$id}"/>
                        <add-parameter name="project" value="{$project}"/>
                        <add-parameter name="exist-path" value="{$exist:path}"/>
                        <add-parameter name="exist-resource" value="{$exist:resource}"/>
                    </forward>
                </dispatch>
             else
                <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
                    <forward url="{$exist:controller}/modules/viewer/get.xql">
                        <add-parameter name="resource-id" value="{$id}"/>
                        <add-parameter name="project" value="{$project}"/>
                        <add-parameter name="exist-path" value="{$exist:path}"/>
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
        
    default return
    (:~
     : everything else is passed through 
    ~:)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <cache-control cache="yes"/>
    </dispatch>