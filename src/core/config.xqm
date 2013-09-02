xquery version "3.0";
(:~
 : A set of helper functions to access the application context from
 : within a module.
 :
 : Based on config.xqm provided by the exist:templating system 
 : extended to recognize multiple projects and templates and project-specific configuration
 :)
module namespace config="http://exist-db.org/xquery/apps/config";

import module namespace config-params="http://exist-db.org/xquery/apps/config-params" at "config.xql";
import module namespace templates="http://exist-db.org/xquery/templates" at "templates.xql";

declare namespace repo="http://exist-db.org/xquery/repo";
declare namespace expath="http://expath.org/ns/pkg";




(: NOT USED! replaced by the projects-dir variable from config-params ! :)
declare variable $config:projects-dir := "USE config-params:projects-dir instead!" ;
(: NOT USED! replaced by the projects-baseuri variable from config-params ! :)
declare variable $config:projects-baseuri:= "USE config-params:projects-baseuri instead!";
declare variable $config:templates-dir := "templates/";
declare variable $config:modules-dir := concat($config:app-root, "/modules/");
declare variable $config:project-static-dir := "static/";
(:declare variable $config:templates-baseuri:= concat("/sade/", $config:templates-dir);:)
declare variable $config:templates-baseuri:= concat($config:app-root-collection, $config:templates-dir);

declare variable $config:repo-descriptor := doc(concat($config:app-root, "/repo.xml"))/repo:meta;

declare variable $config:expath-descriptor := doc(concat($config:app-root, "/expath-pkg.xml"))/expath:package;

(:~
 : Resolve the given path using the current application context.
 : If the app resides in the file system,
 :)
declare function config:resolve($relPath as xs:string) {
    if (starts-with($config:app-root, "/db")) then
        doc(concat($config:app-root, "/", $relPath))
    else
        doc(concat("file://", $config:app-root, "/", $relPath))
};

(: 
    Determine the application root collection from the current module load path.
:)
declare variable $config:app-root := 
    let $rawPath := system:get-module-load-path()
    let $modulePath :=
        (: strip the xmldb: part :)
        if (starts-with($rawPath, "xmldb:exist://")) then
             
            if (starts-with($rawPath, "xmldb:exist://null")) then
                (: seems necessary when the calling module is not stored (e.g. test script in exide) :)
                substring($rawPath, 19)
            else if (starts-with($rawPath, "xmldb:exist://embedded-eXist-server")) then
                substring($rawPath, 36)
            else
                substring($rawPath, 15)
        else
            $rawPath
    return
(:            $modulePath:)
        substring-before($modulePath, "/core")
;

(:~ extracting the context collection of the application :)  
declare variable $config:app-root-collection := concat( '/', (tokenize($config:app-root, '/'))[not(.='')][position()=last()], '/');
            
(:~
 : Extended resolver - projects and templates aware
 : try to find the resource in project-static content then in current template
 : @returns the resolved resource
 :)
declare function config:resolve($model as map(*), $relPath as xs:string) {
    doc(config:resolve-to-dbpath($model, $relPath))
};



(:~
 : Extended resolver - projects and templates aware
 : try to find the resource in project-template, then in project-static content then in current template
 : but return the path
 :)
declare function config:resolve-to-dbpath($model as map(*), $relPath as xs:string) as xs:anyURI {
(:    let $file-type := tokenize($relPath,"\.")[last()]:)
    let $project-template-dir := config:param-value($model, 'project-template-dir')
    let $project-dir := config:param-value($model, 'project-static-dir')
    let $template-dir := config:param-value($model, 'template-dir')
    
    return 
    if (doc-available(concat($project-template-dir,$relPath))) then
            xs:anyURI(concat($project-template-dir,$relPath))
    else if (doc-available(concat($project-dir,$relPath))) then
            xs:anyURI(concat($project-dir,$relPath))
    else 
            xs:anyURI(concat($template-dir,$relPath))
};

(:~ delivers a URI (relative to base sade-controller) to a template-resource, with precedence for templates within project. 
 : Function checks if given resource exists in a template within the project<br/> 
 : <code>(sade-projects)/{$project-id}/templates/{$project-template}/{$relPath}</code><br/>
: if not it checks for resource existence in the project-static content<br/> 
 : <code>(sade-projects)/{$project-id}/static/{$relPath}</code><br/> 
 : finally, if not it checks for resource existence in the template itself<br/> 
 : <code>(sade)/templates/{$project-template}/{$relPath}</code><br/> 
 : otherwise it returns the $relPath as it came in (knowing it will most probably result in 404)
 : special error handling for binary-docs necessary, as doc-available() will throw an error when confronted with binary docs 
 :)
declare function config:resolve-template-to-uri($model as map(*), $relPath as xs:string) as xs:anyURI {
(:    let $file-type := tokenize($relPath,"\.")[last()]:)
 let $project-template-dir := config:param-value($model, 'project-template-dir'),
     $project-static-dir := config:param-value($model, 'project-static-dir'),
     $project-data-dir := config:param-value($model, 'project-data-dir'),
     $template-dir := config:param-value($model, 'template-dir'),
     $project-template-baseuri:= config:param-value($model, 'project-template-baseuri'),
     $project-data-baseuri:= config:param-value($model, 'project-data-baseuri'),
     $project-static-baseuri:= config:param-value($model, 'project-static-baseuri'),
     $template-baseuri := config:param-value($model, 'template-baseuri')
 
 return
    try {
        if (doc-available(concat($project-template-dir,$relPath))) then
            xs:anyURI(concat($project-template-baseuri,$relPath))
        else if (doc-available(concat($project-static-dir,$relPath))) then
            xs:anyURI(concat($project-static-baseuri,$relPath))
        else if (doc-available(concat($project-data-dir,$relPath))) then
            xs:anyURI(concat($project-data-baseuri,$relPath))            
        else if (doc-available(concat($template-dir,$relPath))) then
              xs:anyURI(concat($template-baseuri,$relPath))
       else if (doc-available(concat($config:app-root,$relPath))) then
              xs:anyURI(concat($config:app-root-collection,$relPath))
        else xs:anyURI($relPath)
(: there was a problem with catching the specific error on one instance of exist (maybe not current code   
   } catch err:FODC0005 { :)
    } catch * {    
        if (util:binary-doc-available(concat($project-template-dir,$relPath))) then
            xs:anyURI(concat($project-template-baseuri,$relPath))
        else if (util:binary-doc-available(concat($project-static-dir,$relPath))) then
            xs:anyURI(concat($project-static-baseuri,$relPath))
        else if (util:binary-doc-available(concat($template-dir,$relPath))) then
              xs:anyURI(concat($template-baseuri,$relPath))
         else if (util:binary-doc-available(concat($config:app-root,$relPath))) then
              xs:anyURI(concat($config:app-root-collection,$relPath))
        else xs:anyURI($relPath)
    
    }
    
};

(:~
 : Returns the scripts and links required by the modules as configured in the project-config
 either put code directly into :  `<container key="html-head">`
 or if a module is mentioned in the config, its config is checked for <container key="html-head" >
 
 :)
declare function config:html-head($node as node(), $model as map(*)) {
 
    let $head := $model("config")//container[@key='html-head']
    
    return $head/*
};



(:~
 : Returns the repo.xml descriptor for the current application.
 :)
declare function config:repo-descriptor() as element(repo:meta) {
    $config:repo-descriptor
};

(:~
 : Returns the expath-pkg.xml descriptor for the current application.
 :)
declare function config:expath-descriptor() as element(expath:package) {
    $config:expath-descriptor
};

declare %templates:wrap function config:app-title($node as node(), $model as map(*)) as text() {
    $config:expath-descriptor/expath:title/text()
};

declare %templates:wrap function config:app-description($node as node(), $model as map(*)) as text() {
    $config:repo-descriptor/repo:description/text()
};

(:~
 : For debugging: generates a table showing all properties defined
 : in the application descriptors.
 :)
declare function config:app-info($node as node(), $model as map(*)) {
  (:  let $expath := config:expath-descriptor()
    let $repo := config:repo-descriptor()
    return :)
    (:{
                for $attr in ($expath/@*, $expath/*, $repo/*)
                where $attr/string() != ""
                return
                    <tr>
                        <td>{node-name($attr)}:</td>
                        <td>{$attr/string()}</td>
                    </tr>
            }:)
        <table class="table table-bordered table-striped">
             {   for $key in config:param-keys($model)
                order by $key
            return <tr><td>{$key}</td><td>{config:param-value($node, $model,'','',$key)}</td></tr>
            }
        </table>
};

(:~ lists all parameter keys in the configuration file
 :  sorted alphabetically
 :)
 declare function config:param-keys($config as map(*)*) as xs:string* {

    let $config := $config("config")
    let $special-params := ('app-root', 'app-root-collection', 'base-url', 'project-dir', 'template-dir', 'template-baseuri',
                'project-template-dir', 'project-template-baseuri', 
                'project-data-dir', 'project-data-baseuri',
                'project-static-dir', 'project-static-baseuri',
                'exist-controller', 'exist-path', 'exist-prefix', 'exist-resource', 'exist-root',
                'request-uri', 'request-url')
    
    for $key in (distinct-values($config//param/xs:string(@key)), $special-params)
        order by $key
        return $key
    
};


(:~ returns a value for given parameter reading from the config and the request
 : Following precedence levels:
 : <ol>
 : <li>a few special parameters regarding project and template collections</li>
 : <li>request parameter</li>
 : <li>config parameter for given function within given container (config:container/function/param)</li>
 : <li>config parameter for given function (config:function/param)</li>
 : <li>config parameter for given module (config:module/param)</li>
 : <li>global config param (config:param)</li>
 :  </ol>
 : @param strict only returns a value if it exists for given level of precedence (module) 
 : @returns either the string-value of the @value-attribute or the content of the param-node (in that order)
 :)
declare function config:param-value($node as node()*, $model as map(*)*, $module-key as xs:string, $function-key as xs:string, $param-key as xs:string, $strict as xs:boolean) as item()* {

    let $node-id := $node/xs:string(@id)
    let $config := $model("config")
    
    let $param-special := if ($param-key='app-root') then
                                $config:app-root
                          else if ($param-key='app-root-collection') then
                                $config:app-root-collection
                          else if ($param-key='request-uri') then
                                xs:string(request:get-uri())
                          else if ($param-key='request-url') then
                                xs:string(request:get-url())
                          else if ($param-key='base-url') then
                                concat(string-join(tokenize(request:get-url(),'/')[position() != last()],'/'),'/')
                          else if ($param-key='project-dir') then
                                concat(util:collection-name($config[1]),'/')
                          else if ($param-key='project-static-dir') then
                                  let $project-dir:= util:collection-name($config[1])
                                  return concat($project-dir, "/", $config:project-static-dir)
                          else if ($param-key='project-static-baseuri') then
                                  let $project-id:= $config//param[xs:string(@key)='project-id'][parent::config]
                                  return concat($config-params:projects-baseuri, $project-id, "/", $config:project-static-dir)
                          else if ($param-key='project-template-dir') then
                                  let $project-dir:= util:collection-name($config[1])
                                  let $template := $config//param[xs:string(@key)='template'][parent::config]
                                return concat($project-dir, '/', $config:templates-dir, $template,'/')
                          else if ($param-key='project-template-baseuri') then
                                  let $project-id:= $config//param[xs:string(@key)='project-id'][parent::config]
                                  let $template := $config//param[xs:string(@key)='template'][parent::config]
                                return concat($config-params:projects-baseuri, $project-id, '/', $config:templates-dir, $template,'/')
                          else if ($param-key='template-dir') then
                                  let $template := $config//param[xs:string(@key)='template'][parent::config]
                                return concat($config:app-root, '/', $config:templates-dir, $template,'/')
                          else if ($param-key='template-baseuri') then
                                  let $template := $config//param[xs:string(@key)='template'][parent::config]
                                return concat($config:templates-baseuri, $template,'/')
                          else if ($param-key='project-data-baseuri') then
                                  let $project-id:= $config//param[xs:string(@key)='project-id'][parent::config]
                                  let $data-path:= $config//param[xs:string(@key)='data-path'][parent::config]
                                return concat($config-params:projects-baseuri, $project-id, '/', $data-path)
                          else ()
    
    let $param-request := request:get-parameter($param-key,'')
    let $param-container := $config//container[@key=$node-id]/function[xs:string(@key)=concat($module-key, ':', $function-key)]/param[xs:string(@key)=$param-key]
    let $param-function := $config//function[xs:string(@key)=concat($module-key, ':', $function-key)]/param[xs:string(@key)=$param-key]
    let $param-module := $config//module[xs:string(@key)=$module-key]/param[xs:string(@key)=$param-key]
(:    let $param-global:= $config//param[xs:string(@key)=$param-key][parent::config]:)
    let $param-global:= $config//param[xs:string(@key)=$param-key]
    
    (: $strict currently only implemented for module :)
    let $param := if ($strict) then
                           if ($module-key ne '' and  exists($param-module)) then $param-module[1]
                           else ""
                    else 
                    if ($param-special != '') then $param-special[1]
                        else if ($param-request != '') then $param-request[1]
                        else if (exists($param-container)) then $param-container[1]
                        else if (exists($param-function)) then $param-function[1]
                           else if (exists($param-module)) then $param-module[1]
                              else if (exists($param-global)) then $param-global[1]
                              else ""
    
    let $param-value := if ($param instance of text() or $param instance of xs:string) then $param
                           else if (exists($param/@value)) then $param/xs:string(@value)
                           else if (exists($param/*)) then $param/*
                           else $param/text()
                           
   return ($param-value)
    
};

(:~ override the full-function, without (later added) $strict-parameter (set to false()   
:)
declare function config:param-value($node as node()*, $model as map(*)*, $module-key as xs:string, $function-key as xs:string, $param-key as xs:string) as item()* {
   config:param-value($node,$model,$module-key,$function-key,$param-key, false())
};

(:~ returns the value of a parameter, but regards only request or global config param   
 :)
declare function config:param-value($model as map(*), $param-key as xs:string) as item()* {
    config:param-value((),$model,'','',$param-key)
};



(:~ gets both the project and module configs
  : @param $project project identifier
 :)
declare function config:config($project as xs:string) {
  (config:project-config($project), config:module-config())
};

(:~ tries to resolve to the project-specific config file
    first tries to look for a 'config.xml' file in the project-dir,
    if not found, searches based on the project-id all configs in projects-dir
    <param key="project-id">ccv</param>
  : @param $project project identifier
 :)
declare function config:project-config($project as xs:string) {
       let $project-config-path := concat($config-params:projects-dir, $project, "/config.xml")
      
        let $project-config := if (doc-available($project-config-path)) then doc($project-config-path) 
                else 
                   collection($config-params:projects-dir)//config[param[xs:string(@key)='project-id'][.=$project]]
                    
        return $project-config
        
};


(:~ lists all defined projects based on the project-id param in the config.
 :  this would only read the projects in separate folders:
    let  $projects := xmldb:get-child-collections($config-params:projects-dir)
    and we want to take also projects into account without a separate folder, defined solely by their config
    (especially meant for external projects, that shall have only a minimal mention)
    
@returns the ids of all projects 
:)
declare function config:list-projects() {
       collection($config-params:projects-dir)//config/param[xs:string(@key)='project-id']/text()
};


(:~ lists all existing modules (i.e. present in the modules-colleciton) :)
declare function config:list-modules() {
       xmldb:get-child-collections($config:modules-dir)
};


(:~ tries to find module-specific configurations
  : @returns a sequence of module-config docs 
 :)
declare function config:module-config() as item()* {
    for $coll in xmldb:get-child-collections($config:modules-dir)
          return if (doc-available(concat($config:modules-dir, $coll, "/config.xml"))) 
          then doc(concat($config:modules-dir, $coll, "/config.xml"))else ()
};

(:~ checks if there is a config-file for given project
  : @param $project project identifier
 :)
declare function config:project-exists($project as xs:string) {
       let $project-config-path := concat($config-params:projects-dir, $project, "/config.xml")
       return doc-available($project-config-path)
};
