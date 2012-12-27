(:~
 : A set of helper functions to access the application context from
 : within a module.
 : Based on confing.xqm provided by the exist:templating system 
 : extended to recognize multiple projects and templates and project-specific configuration
 :)
module namespace config="http://exist-db.org/xquery/apps/config";

import module namespace templates="http://exist-db.org/xquery/templates" at "templates.xql";

declare namespace repo="http://exist-db.org/xquery/repo";
declare namespace expath="http://expath.org/ns/pkg";

(: 
    Determine the application root collection from the current module load path.
:)
declare variable $config:app-root := 
    let $rawPath := system:get-module-load-path()
    let $modulePath :=
        (: strip the xmldb: part :)
        if (starts-with($rawPath, "xmldb:exist://")) then
            if (starts-with($rawPath, "xmldb:exist://embedded-eXist-server")) then
                substring($rawPath, 36)
            else
                substring($rawPath, 15)
        else
            $rawPath
    return
(:        substring-before($modulePath, "/modules"):)
        substring-before($modulePath, "/core")
;

declare variable $config:projects-dir := "/db/apps/sade-projects/";
declare variable $config:templates-dir := concat($config:app-root, "/templates/");
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


(:~
 : Extended resolver - projects and templates aware
 : try to find the resource in project-static content then in current template
 :)
declare function config:resolve($model as map(*), $relPath as xs:string) {
(:    let $file-type := tokenize($relPath,"\.")[last()]:)
    let $project-dir := config:param-value($model, 'project-dir')
    let $template-dir := config:param-value($model, 'template-dir')
    
    return 
    if (doc-available(concat($project-dir,$relPath))) then
        doc(concat($project-dir,$relPath))
      else 
        doc(concat($template-dir,$relPath))
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
            <tr>
                <td>app collection:</td>
                <td>{$config:app-root}</td>
            </tr>
            <tr>
                <td>system:get-module-load-path():</td>
                <td>{system:get-module-load-path()}</td>
            </tr>
            
            
        </table>
};

(:~ lists all parameter keys in the configuration file
 :  sorted alphabetically
 :)
 declare function config:param-keys($config as map(*)*) as xs:string* {

    let $config := $config("config")
    let $special-params := ('project-dir', 'template-dir')
    
    for $key in (distinct-values($config//param/xs:string(@key)), $special-params)
        order by $key
        return $key
    
};


(:~ returns a value for given parameter reading from the config and the request
 : Following precedence levels:
 : 0. two special parameters: project-dir, template-dir
 : 1. request parameter
 : 2. config parameter for given function within given container (config:container/function/param)
 : 3. config parameter for given function (config:function/param)
 : 4. config parameter for given module (config:module/param)
 : 5. global config param (config:param)
 : @returns either the string-value of the @value-attribute or the content of the param-node (in that order)
 :)
declare function config:param-value($node as node()*, $config as map(*)*, $module-key as xs:string, $function-key as xs:string, $param-key as xs:string) as item()* {

    let $node-id := $node/xs:string(@id)
    let $config := $config("config")
    
    let $param-special := if ($param-key='project-dir') then
                                concat(util:collection-name($config),'/')
                            else if ($param-key='template-dir') then
                                  let $template := $config//param[xs:string(@key)='template'][parent::config]
                                return concat($config:templates-dir, $template,'/')
                             else ''
    
    let $param-request := request:get-parameter($param-key,'')
    let $param-container := $config//container[@key=$node-id]/function[xs:string(@key)=concat($module-key, ':', $function-key)]/param[xs:string(@key)=$param-key]
    let $param-function := $config//function[xs:string(@key)=concat($module-key, ':', $function-key)]/param[xs:string(@key)=$param-key]
    let $param-module := $config//module[xs:string(@key)=$module-key]/param[xs:string(@key)=$param-key]
    let $param-global:= $config//param[xs:string(@key)=$param-key][parent::config]
    
    let $param := if ($param-special != '') then $param-special
                        else if ($param-request != '') then $param-request
                        else if (exists($param-container)) then $param-container 
                        else if (exists($param-function)) then $param-function
                           else if (exists($param-module)) then $param-module
                              else if (exists($param-global)) then $param-global
                              else ""
    
    let $param-value := if ($param instance of text() or $param instance of xs:string) then $param
                           else if (exists($param/@value)) then $param/xs:string(@value)
                           else if (exists($param/*)) then $param/*
                           else $param/text()
                           
   return $param-value
    
};

(:~ returns the value of a parameter, but regards only request or global config param   
 :)
declare function config:param-value($config as map(*), $param-key as xs:string) as item()* {
    config:param-value((),$config,'','',$param-key)
};

(:~ tries to resolve to the project-specific config file
  : @param $project project identifier
 :)
declare function config:project-config($project as xs:string) {
       let $project-config-path := concat($config:projects-dir, $project, "/config.xml")
        let $project-resolved := if (doc-available($project-config-path)) then $project else "no such project"
        let $project-config := if (doc-available($project-config-path)) then doc($project-config-path) else ()
        return $project-config
};
