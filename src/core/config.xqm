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
declare namespace mets="http://www.loc.gov/METS/";
declare namespace mods="http://www.loc.gov/mods/v3";
declare namespace xlink="http://www.w3.org/1999/xlink";
declare namespace cmd="http://www.clarin.eu/cmd/";
declare namespace sm="http://exist-db.org/xquery/securitymanager";



(:~
 : Contains the uri of the application root collection, determined from the current module load path.
 ~:)
declare variable $config:app-root := 
    let $rawPath := system:get-module-load-path()
    let $modulePath :=
        (: strip the xmldb: part :)
        if (starts-with($rawPath, "xmldb:exist://")) 
        then
            if (starts-with($rawPath, "xmldb:exist://null")) 
            then
                (: seems necessary when the calling module is not stored (e.g. test script in exide) :)
                substring($rawPath, 19)
            else 
                if (starts-with($rawPath, "xmldb:exist://embedded-eXist-server")) 
                then substring($rawPath, 36)
                else substring($rawPath, 15)
        else $rawPath
    return substring-before($modulePath, "/core")
;

declare variable $config:app-name := 'cr-xq';
declare variable $config:app-root-key := 'app-root';

(:~ 
 : extracting the context collection of the application 
~:)  
declare variable $config:app-root-collection := concat( '/', (tokenize($config:app-root, '/'))[not(.='')][position()=last()], '/');



declare variable $config:cr-config-filename := "conf.xml";
declare variable $config:cr-config := doc($config:app-root||"/"||$config:cr-config-filename);

declare variable $config:templates-dir := "templates/";
declare variable $config:modules-dir := $config:app-root||"/modules/";
declare variable $config:project-static-dir := "static/";
declare variable $config:templates-baseuri:= $config:app-root-collection||$config:templates-dir;
declare variable $config:repo-descriptor := doc($config:app-root||"/repo.xml")/repo:meta;
declare variable $config:expath-descriptor := doc($config:app-root||"/expath-pkg.xml")/expath:package;

declare variable $config:default-data-path := "/db/cr-data/";
declare variable $config:default-workingcopy-path := config:path("workingcopy");
declare variable $config:default-resourcefragments-path := config:path("resourcefragments");
declare variable $config:default-lookuptable-path := config:path("lookuptables");

declare variable $config:DEFAULT_PROJECT_ID :="defaultProject";
declare variable $config:PROJECT_DATA_FILEGRP_ID:="projectData";
declare variable $config:PROJECT_STRUCTMAP_ID:="cr-data";
declare variable $config:PROJECT_STRUCTMAP_TYPE:="internal";
declare variable $config:PROJECT_TOC_STRUCTMAP_TYPE:="logical";
declare variable $config:PROJECT_TOC_STRUCTMAP_ROOT_TYPE:="cr-xq-corpus";
declare variable $config:PROJECT_RESOURCE_DIV_TYPE:="resource";
declare variable $config:PROJECT_RESOURCEFRAGMENT_DIV_TYPE:="resourcefragment";
declare variable $config:PROJECT_PID_NAME:="project-pid";

(: Project Account naming conventions :)
declare variable $config:PROJECT_ACCOUNTS_ADMIN_ACCOUNTNAME_PREFIX:= "";
declare variable $config:PROJECT_ACCOUNTS_ADMIN_ACCOUNTNAME_SUFFIX:= "Admin";
declare variable $config:PROJECT_ACCOUNTS_USER_ACCOUNTNAME_PREFIX:= "";
declare variable $config:PROJECT_ACCOUNTS_USER_ACCOUNTNAME_SUFFIX:= "";


declare variable $config:PROJECT_STATUS_AVAILABLE :=    "available";
declare variable $config:PROJECT_STATUS_REVISION :=     "under revision";
declare variable $config:PROJECT_STATUS_REMOVED :=      "removed"; 
declare variable $config:PROJECT_STATUS_RESTRICTED :=   "restricted";

declare variable $config:PROJECT_DMDSEC_ID := "projectDMD";
declare variable $config:PROJECT_AMDSEC_ID := "projectAMD";
declare variable $config:PROJECT_MAPPINGS_ID := "projectMappings";
declare variable $config:PROJECT_PARAMETERS_ID := "projectParameters";
declare variable $config:PROJECT_MODULECONFIG_ID := "moduleConfig";
declare variable $config:PROJECT_RIGHTSMD_ID := "projectLicense";
declare variable $config:PROJECT_ACL_ID := "projectACL";

declare variable $config:PROJECT_FACS_FILEGRP_ID := "imgResources";
declare variable $config:PROJECT_FACS_FILEGRP_USE := "Image Resources";

(:~
 : This variable stores the content of the @USE attribute on the <fileGrp> element,
 : which contains all <file>s of a resource.  
~:)
declare variable $config:PROJECT_RESOURCE_FILEGRP_USE:="RESOURCE FILES";
declare variable $config:PROJECT_RESOURCE_FILEGRP_SUFFIX:="_files";

declare variable $config:RESOURCE_FACS_SUFFIX:="_facs";

(:~
 : The variable <code></code> stores the content of the @USE attribute on the <file> element,
 : which contains the working copy of a resources.  
~:)
declare variable $config:RESOURCE_WORKINGCOPY_FILE_USE:="WORKING COPY";
declare variable $config:RESOURCE_MASTER_FILE_USE:="MASTER";
declare variable $config:RESOURCE_RESOURCEFRAGMENTS_FILE_USE:="EXTRACTED RESOURCEFRAGMENTS";
declare variable $config:RESOURCE_LOOKUPTABLE_FILE_USE:="LOOKUP TABLE";

declare variable $config:RESOURCE_WORKINGCOPY_FILEID_SUFFIX:="_wc";
(: the id of the mets:file element representing the resourcefragments file is 
   generated by resource-pid + $config:RESOURCE_RESOURCEFRAGMENT_FILEID_SUFFIX :)
declare variable $config:RESOURCE_RESOURCEFRAGMENT_FILEID_SUFFIX:="_frgts";
(: the resourcefragment-pid is generated by 
   resource-pid + $config:RESOURCE_RESORUCEFRAGMENT_ID_SUFFIX + running number 
:)
declare variable $config:RESOURCE_RESOURCEFRAGMENT_ID_SUFFIX := "_";
declare variable $config:RESOURCE_MASTER_FILEID_SUFFIX:="_master";
declare variable $config:RESOURCE_LOOKUPTABLE_FILEID_SUFFIX:="_lt";

declare variable $config:RESOURCE_DMDID_SUFFIX:="_dmd";
declare variable $config:RESOURCE_PID_NAME:="resource-pid";
(:~
 : Declaration of XML element names and namespaces for stored resource fragments and lookup tables. 
~:)
declare variable $config:RESOURCE_RESOURCE_ELEMENT_NSURI:="http://clarin.eu/fcs/1.0";
declare variable $config:RESOURCE_RESOURCE_ELEMENT_NAME:="resource";
declare variable $config:RESOURCE_RESOURCEFRAGMENT_ELEMENT_NSURI:=$config:RESOURCE_RESOURCE_ELEMENT_NSURI;
declare variable $config:RESOURCE_RESOURCEFRAGMENT_ELEMENT_NAME:="resourceFragment";
declare variable $config:RESOURCE_LOOKUPTABLE_ELEMENT_NSURI:=$config:RESOURCE_RESOURCE_ELEMENT_NSURI;
declare variable $config:RESOURCE_LOOKUPTABLE_ELEMENT_NAME:="lookupTable";


declare variable $config:RESOURCEFRAGMENT_PID_NAME:="resourcefragment-pid";
declare variable $config:RESOURCEFRAGMENT_LABEL_NAME:="rf-label";

declare variable $config:INDEX_RESOURCEFRAGMENT_DELIMITER:="rf";
declare variable $config:INDEX_INTERNAL_RESOURCEFRAGMENT:="fcs.rf";

(:~
 : Prefixes to prepend to the filename of a resource, when storing working copies, 
 : lookup tables and extracted resource fragments. 
~:)
declare variable $config:RESOURCE_WORKINGCOPY_FILENAME_PREFIX := "wc-";
declare variable $config:RESOURCE_LOOKUPTABLE_FILENAME_PREFIX := "lt-";
declare variable $config:RESOURCE_RESOURCEFRAGMENT_FILENAME_PREFIX := "frg-";
declare variable $config:RESOURCE_DMD_FILENAME_PREFIX := "md-";

declare variable $config:cr-writer-accountname :=   if (doc-available("../modules/access-control/writer.xml"))
                                                    then doc("../modules/access-control/writer.xml")/write/xs:string(write-user)
                                                    else "cr-writer";


declare variable $config:app-version := $config:expath-descriptor/xs:string(@version);
declare variable $config:app-name-full := $config:expath-descriptor/xs:string(@name);
declare variable $config:app-name-abbreviation := $config:expath-descriptor/xs:string(@abbrev);

(:~
 : Resolves one path path key to the full db-path.
 :
 : This function accepts either one single argument, the key, and resolves 
 : it to the 'paths' branch of the conf.xml file in config:app-root; or it accepts two 
 : arguments, the first being a sequence of config:path elements, the second one the key 
 : of the path to resolve. 
 : The latter function makes it possible to inject arbitrary paths to the resolver
 : which are only known at run time, e.g. the home collection of a specific project.
 : @param $key the path element to be resolved
 : @return the resolved path (zero or one string)  
:)
declare function config:path($key as xs:string) as xs:string? {
    let $path:=$config:cr-config//config:path[@key eq $key]
    return
        if (exists($path))
        then config:path-relative-to-absolute($path)
        else ()
};

(:~
 : Resolves one path path key to the full db-path.
 :
 : This function accepts either one single argument, the key, and resolves 
 : it to the 'paths' branch of the conf.xml file in config:app-root; or it accepts two 
 : arguments, the first being a sequence of config:path elements, the second one the key 
 : of the path to resolve. 
 : The latter function makes it possible to inject arbitrary paths to the resolver
 : which are only known at run time, e.g. the home collection of a specific project.
 : @param $key the path element to be resolved
 : @param $paths the path elements the key should be resolved against
 : @return the resolved path (zero or one string)  
:)
declare function config:path($paths as element(config:path)*, $key as xs:string)  {
    let $path:=$paths/self::config:path[@key eq $key]
    return
        if (exists($path))
        then config:path-relative-to-absolute($paths,$path)
        else ()
};


(:~
 : Resolves one single path element in conf.xml to the full db-path.
 :
 : path elements look like this (note the @base attribute):
 : 
 : <path key="data" xml:id="data">/db/cr-data</path>
 : <path key="metadata" base="#data">_md</path>
 :
 : This function accepts either one single argument, the path element, and resolves 
 : it to the 'paths' branch of the conf.xml file in config:app-root; or it accepts two 
 : arguments, the first being a sequence of config:path elements, the second one the path element
 : to resolve. The latter function makes it possible to inject arbitrary paths to the resolver
 : which are only known at run time, e.g. the home collection of a specific project.
 : @param $path the path element to be resolved
 : @return the resolved path (zero or one string)  
:)
declare function config:path-relative-to-absolute($path as element(config:path)) as xs:string? {
    if (starts-with($path,'/'))
    then $path
    else 
        let $static-paths:=$config:cr-config//config:path
        return config:path-relative-to-absolute($static-paths, $path, ())
};


(:~
 : Resolves one single path element in conf.xml to the full db-path.
 :
 : path elements look like this (note the @base attribute):
 : 
 : <path key="data" xml:id="data">/db/cr-data</path>
 : <path key="metadata" base="#data">_md</path>
 :
 : This function accepts either one single argument, the path element, and resolves 
 : it to the 'paths' branch of the conf.xml file in config:app-root; or it accepts two 
 : arguments, the first being a sequence of config:path elements, the second one the path element
 : to resolve. The latter function makes it possible to inject arbitrary paths to the resolver
 : which are only known at run time, e.g. the home collection of a specific project.
 : @param $path the path element to be resolved
 : @return the resolved path (zero or one string)  
:)
declare function config:path-relative-to-absolute ($paths as element(config:path)*, $path as element(config:path)) as xs:string? {
    if (starts-with($path,'/'))
    then $path
    else config:path-relative-to-absolute($paths, $path, ())
};

declare function config:path-relative-to-absolute($paths as element(config:path)*, $path as element(config:path), $steps-before as element(config:path)*) as xs:string? {
    if (starts-with($path,'/'))
    then string-join(($path,reverse($steps-before)),'/')
    else
        let $parent-id := substring-after($path/@base,'#')
        let $parent:= $paths[@key = $parent-id]
        return
            if (exists($parent))
            then config:path-relative-to-absolute($paths,$parent,($steps-before,$path))
            else if ($parent-id eq $config:app-root-key) then string-join(($config:app-root,$path,reverse($steps-before)),'/')  
            else string-join(($path,reverse($steps-before)),'/')
};

declare variable $config:paths as map := 
    map:new(for $p in $config:cr-config//config:path
            return map:entry($p/@key, data($p)))
;

(:~
 : Returns the xml resource by resolving the relative path $relPath using the current application context. 
 : If the app resides in the file system, the resource will be loaded from there. 
 :
 : @param $relPath the relative path to the xml resource
 : @return the xml resource  
 :)
declare function config:resolve($relPath as xs:string) as document-node()? {
    if (starts-with($config:app-root, "/db")) 
    then doc($config:app-root||"/"||$relPath)
    else doc("file://"||$config:app-root||"/"||$relPath)
};

(:~
 : Extended resolver. Tries to locate the requested XML resource in the following locations:
 : 
 : <ol>
 :      <li>'template' collection of the current project (as set in $model)</li>
 :      <li>'static' collection of the current project (ibd.)</li>
 :      <li>'template' collection in which the current template resides</li>
 : </ol>
 : 
 : Checks the availability of the resource via doc-available, which will throw an error when
 : confronted with a binary doc.
 : 
 : @param $model the model map as passed by the eXist-templating framework
 : @param $relPath the relative path to the XML resource to be loaded
 : @return the XML resource
~:)
declare function config:resolve($model as map(*), $relPath as xs:string) as document-node()? {
    doc(config:resolve-to-dbpath($model, $relPath))
};


(:~
 : Auxiliary function for the extended resolver. 
 : @see xqdoc/xqdoc-config;config:resolve
 : 
 : Checks the availability of the resource via <code>fn:doc-available()</code>, 
 : which will throw an error when confronted with a binary resource.
 : 
 : @param $model the model map as passed by the eXist-templating framework
 : @param $relPath the relative path to the xml resource to be loaded
 : @return the absolute path to the resource as anyURI
 :)
declare function config:resolve-to-dbpath($model as map(*), $relPath as xs:string) as xs:anyURI {
    let $project-template-dir := config:param-value($model, 'project-template-dir'),
        $project-dir := config:param-value($model, 'project-static-dir'),
        $template-dir := config:param-value($model, 'template-dir')
    return 
        if (doc-available($project-template-dir||$relPath)) 
        then xs:anyURI($project-template-dir||$relPath)
        else 
            if (doc-available($project-dir||$relPath)) 
            then xs:anyURI($project-dir||$relPath)
            else xs:anyURI($template-dir||$relPath)
};

(:~ 
 : Delivers the relative path (to base cr-xq-controller) of a template-resource, with precedence 
 : for templates from the current project. It checks for the resource in the following locations:
 : 
 : <ol>
 :      <li>in the 'templates' collection of the current project (as set in $model),</li>
 :      <li>in the 'static' collection of the current project (as set in $model),</li>
 :      <li>in the 'data' collection for the current project (as set in $model),</li>
 :      <li>in the 'template' collection in which the current template resides,</li>
 :      <li>in the root collection of the cr-xq app.</li>
 :      <li>Otherwise returns $relPath as received.</li>
 : </ol> 
~:)
declare function config:resolve-template-to-uri($model as map(*), $relPath as xs:string) as xs:anyURI {
    let $project-template-dir := config:param-value($model, 'project-template-dir'),
        $project-template-baseuri:= config:param-value($model, 'project-template-baseuri'),
        $project-static-dir := config:param-value($model, 'project-static-dir'),
        $project-static-baseuri:= config:param-value($model, 'project-static-baseuri'),
        $project-data-dir := config:param-value($model, 'project-data-dir'),
        $project-data-baseuri:= config:param-value($model, 'project-data-baseuri'),
        $template-dir := config:param-value($model, 'template-dir'),
        $template-baseuri := config:param-value($model, 'template-baseuri')
    let $dirs:=(    $project-template-dir||$relPath,
                    $project-static-dir||$relPath,
                    $project-data-dir||$relPath,
                    $template-dir||$relPath,
                    $config:app-root||$relPath)
    
    let $base-uris:=(   $project-template-baseuri||$relPath,
                        $project-static-baseuri||$relPath,
                        $project-data-baseuri||$relPath,
                        $template-baseuri||$relPath,
                        $config:app-root-collection||$relPath)
    return
        let $available:=
            for $i at $pos in $dirs 
            let $is-binary-doc:=util:is-binary-doc($i)
            return
                switch (true())
                    case ($is-binary-doc and util:binary-doc-available(xs:anyURI($i))) return $base-uris[$pos]
                    case (doc-available($i)) return $base-uris[$pos]
                    default return ()
        return 
            if (exists($available))
            then xs:anyURI($available[1])
            else xs:anyURI($relPath)
};

(:~
 : Fetches XHTML-snippets from the project to be inserted into the <head> of the page-template. 
 : 
 : either put code directly into :  `<container key="html-head">`
 : or if a module is mentioned in the config, its config is checked for <container key="html-head" >
 : 
 : @return zero or more XHTML fragment 
~:)
declare function config:html-head($node as node(), $model as map(*)) as element()* {
   ($model("config")//mets:file[@USE='projectHtmlHead']/mets:FContent/mets:xmlData/*,
    $model("config")//container[@key='html-head']/*)
};



(:~
 : Returns the repo.xml descriptor for the current application.
 : 
 : @return the repo.xml descriptor for the running cr-xq instance.
 :)
declare function config:repo-descriptor() as element(repo:meta) {
    $config:repo-descriptor
};

(:~
 : Returns the expath-pkg.xml descriptor for the current application.
 :
 : @return the expath-pkg.xml descriptor for the running cr-xq instance.
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
    <table class="table table-bordered table-striped">{
        for $key in config:param-keys($model)
        order by $key
        return 
            <tr>
                <td>{$key}</td>
                <td>{config:param-value($node, $model,'','',$key)}</td>
            </tr>
    }</table>
};

(:~ lists all parameter keys in the configuration file
 :  sorted alphabetically
~:)
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

(:~ Helper function which reads mets:file element and returns either the value from FContent or the @xlink:href uri from FLocat. If both are provided, the former is returned.
 :
 : @param element(mets:file) 
 : @return uri or xmldata
~:)
declare function config:mets-file($file as element(mets:file)?) as item()* {
    switch (true())
        case (not(exists($file))) return ()
        case (exists($file/mets:FContent/mets:xmlData)) return
            $file/mets:FContent/mets:xmlData/*
        case (exists($file/mets:FLocat)) return
            let $uri:=$file/mets:FLocat/@xlink:href
            return config:db-to-relative-path(xs:string($uri))
        default return ()
};

(:~
 : Returns the relative path of a project resource as needed by the config module.  
~:)
declare function config:db-to-relative-path($path as xs:string) as xs:string {
    let $steps:=tokenize($path,'/')
    return ($steps[position() eq count($steps)-1]||"/"||$steps[last()])
};


(:~ Lookup function for values in the current configuration and request. T
 : Following precedence levels:
 : <ol>
 : <li>a few special parameters regarding project and template collections</li>
 : <li>request parameter</li>
 : <li>config parameter for given function within given container (config:container/function/param)</li>
 : <li>config parameter for given function (config:function/param)</li>
 : <li>config parameter for given module (config:module/param)</li>
 : <li>global config param (config:param)</li>
 :  </ol>
 : 
 : @param strict only returns a value if it exists for given level of precedence (module) 
 : @return either the string-value of the @value-attribute or the content of the param-node (in that order)
 :)
declare function config:param-value($node as node()*, $model, $module-key as xs:string, $function-key as xs:string, $param-key as xs:string, $strict as xs:boolean) as item()* {

    let $node-id := $node/xs:string(@id)
    let $config :=  if ($model instance of map(*)) then $model("config") else $model,
        $mets :=    $config/descendant-or-self::mets:mets[@TYPE='cr-xq project'],
        $crProjectParameters:= $mets//mets:techMD[@ID=$config:PROJECT_PARAMETERS_ID]/mets:mdWrap/mets:xmlData
    
    let $param-special:=
        switch($param-key)
            case "app-root"                 return $config:app-root
            case "app-root-collection"      return $config:app-root-collection
            case "projects-baseuri"         return $config-params:projects-baseuri            
            case "shib-user-pwd"            return $config-params:shib-user-pwd
            case "request-uri"              return xs:string(request:get-uri())
(:            case "base-url"                 return string-join(tokenize(request:get-url(),'/')[position() != last()],'/')||'/':)
(:            case "base-url"                 return substring-before(request:get-url(),$config:app-root-collection)||$config:app-root-collection
            trying to add project-part to the "base-url": :)
              case "base-url"                 return substring-before(request:get-url(),$config:app-root-collection)||$config:app-root-collection||$mets/xs:string(@OBJID)||"/" 
            case $config:PROJECT_PID_NAME   return $mets/xs:string(@OBJID)
            case "project-dir"              return util:collection-name($config[self::mets:mets])||"/"
            case "project-static-dir"       return 
                                                let $project-dir:= util:collection-name($config[self::mets:mets])
                                                return concat($project-dir, "/", $config:project-static-dir)
            case "project-static-baseuri"   return
                                                let $project-id:=$mets/xs:string(@OBJID)
                                                return $config-params:projects-baseuri||$project-id||"/"||$config:project-static-dir
            
            case "public-project-baseurl"   return replace($config:cr-config//param[@key='public-repo-baseurl'],'/$','')||"/"||$mets/xs:string(@OBJID)||"/"
            
            case 'project-template-dir'     return
                                                let $project-dir:= util:collection-name($config[self::mets:mets])
                                                let $template := $crProjectParameters//param[@key='template']
                                                return $project-dir||'/'||$config:templates-dir||$template||'/'
            case 'project-template-baseuri' return
                                                let $project-id:=$mets/xs:string(@OBJID)
                                                let $template := $crProjectParameters//param[@key='template']
                                                return $config-params:projects-baseuri||$project-id||'/'||$config:templates-dir||$template||"/"
            case 'template-dir'             return
                                                let $template := $crProjectParameters//param[@key='template']
                                                return $config:app-root||'/'||$config:templates-dir||$template||"/"
            case 'template-baseuri'         return
                                                let $template := $crProjectParameters//param[@key='template']
                                                return $config:templates-baseuri||$template||"/"
            case 'project-data-dir'     return
                                                let $project-id:=$mets/xs:string(@OBJID)
                                                let $data-path:=config:common-path-from-FLocat($model,'projectData')
                                                return $config-params:projects-baseuri||$project-id||'/'||$data-path
            case 'project-data-baseuri'     return
                                                let $project-id:=$mets/xs:string(@OBJID)
                                                let $data-path:=config:common-path-from-FLocat($model,'projectData')||"/"
                                                return $config-params:projects-baseuri||$project-id||'/'||$data-path
            case 'visibility'               return 
                                                let $ace:=$mets//sm:ace[@who='other']
                                                return 
                                                    if ($ace/(@access_type='DENIED' and starts-with(@mode,'r')))
                                                    then 'protected'
                                                    else 'unprotected'
            case 'users'                    return
                                                (: sm:get-group-members-function need to be executed as a logged in user :)
(:                                                let $login:=        xmldb:login($config:app-root,"cr-xq","cr=xq!"):)
                                                let $ace:=          $mets//sm:ace[@access_type='ALLOWED' and starts-with(@mode,'r')],
                                                    $users:=        $ace[@target='USER']/@who,
                                                    $groups:=       $ace[@target='GROUP']/@who,
                                                    $group-members:=()
                                                    (:for $g in $groups
                                                                    return
                                                                        system:as-user("cr-xq","cr=xq!",
                                                                            if (sm:group-exists($g))
                                                                            then sm:get-group-members($g)
                                                                            else ()
                                                                        ):),
                                                    $allowed-users:=    ($group-members,$users)
                                                return string-join($allowed-users,',')
            
            case $config:PROJECT_DMDSEC_ID  return $mets//mets:dmdSec[@ID=$config:PROJECT_DMDSEC_ID]/(mets:mdWrap/mets:xmlData|doc(mets:mdRef/@xlink:href))/cmd:CMD
            case 'project-title'            return ($mets//mets:dmdSec[@ID=$config:PROJECT_DMDSEC_ID]/(mets:mdWrap/mets:xmlData|doc(mets:mdRef/@xlink:href))//cmd:CollectionInfo/cmd:Title[text()],$mets/@LABEL)[1]

            case 'mappings'                 return $mets//mets:techMD[@ID=$config:PROJECT_MAPPINGS_ID]/mets:mdWrap/mets:xmlData/map
            case 'teaser-text'              return config:mets-file($mets//mets:file[@USE='projectTeaserText'])
            case 'logo-image'               return config:mets-file($mets//mets:file[@USE='projectLogoImage']) 
            case 'logo-text'                return config:mets-file($mets//mets:file[@USE='projectLogoLink'])
            
            default                         return ()
            
    
    let $param-request := try { request:get-parameter($param-key,'') } catch * { () }
    let $param-cr := $config:cr-config//param[@key=$param-key]
    let $param-container := $config//container[@key=$node-id]/function[xs:string(@key)=concat($module-key, ':', $function-key)]/param[xs:string(@key)=$param-key]
    let $param-function := $config//function[xs:string(@key)=concat($module-key, ':', $function-key)]/param[xs:string(@key)=$param-key]
    let $param-module := $config//module[xs:string(@key)=$module-key]/param[xs:string(@key)=$param-key]
    let $param-repo := $config:cr-config//param[xs:string(@key)=$param-key]
    let $param-global:= $config//param[xs:string(@key)=$param-key]
    
    (: $strict currently only implemented for module :)
    let $param := 
        if ($strict) 
        then
            if ($module-key ne '' and  exists($param-module)) 
            then $param-module[1]
            else ""
        else
            switch(true())
                case ($param-special != '')     return $param-special
                case ($param-request != '')     return $param-request[1]
                case (exists($param-cr))        return $param-cr[1]
                case (exists($param-container)) return $param-container[1]
                case (exists($param-repo))      return $param-repo[1]
                case (exists($param-function))  return $param-function[1]
                case (exists($param-module))    return $param-module[1]
                case (exists($param-global))    return $param-global[1]
                default                         return ""
    
    let $param-value := 
        switch(true())
            case ($param instance of text() or $param instance of xs:string) return $param
            case ($param instance of attribute()) return data($param)
            case (exists($param/@value))    return $param/xs:string(@value)
            case (exists($param/*))         return $param
            default                         return $param/text()               
   return ($param-value)
    
};


(:~
 : This functions generates a data-path parameter by looking for common path to all files listed in project-data mets:fileGrp.
 : It is needed for compatability reasons as <code>config:param-value()</code> has to provide a 'project-data-dir' param which
 : was formerly hardcoded in conf.xml. With the METS-based project catalog, this is not necessary any more, strictly speaking.
 : 
 : Beware: This obviously only works, when all the data listed in project.xml share a common path.
 : 
 : @param $model a map with a "config" key, which provides the project's project.xml setup.
 : @result returns a path common to all project data files or the empty sequence if there's no common path. 
~:)
declare function config:common-path-from-FLocat($model as map(*), $fileGrpID as xs:string) as xs:string? {
    let $config:=   $model("config"),
        $data:=     $config//mets:fileGrp[@ID=$fileGrpID]//mets:FLocat/xs:string(@xlink:href)
    
    let $tokenized:=for $d in $data return tokenize($d,'/'),
        $pathSteps:=for $t in $tokenized
                    where count(index-of($tokenized,$t)) eq count($data)
                    return $t
    return 
        if (exists(distinct-values($pathSteps)))
        then string-join(distinct-values($pathSteps[.!='']),'/')
        else ()
};

(:~ override the full-function, without (later added) $strict-parameter (set to false()   
:)
declare function config:param-value($node as node()*, $model, $module-key as xs:string, $function-key as xs:string, $param-key as xs:string) as item()* {
   config:param-value($node,$model,$module-key,$function-key,$param-key, false())
};

(:~ returns the value of a parameter, but regards only request or global config param   
 :)
declare function config:param-value($model, $param-key as xs:string) as item()* {
    config:param-value((),$model,'','',$param-key)
};



(:~ 
 : Fetches the configuration (<code>project.xml</code>) of the requested project 
 : plus the configuration files (<code>config.xml</code>) of all modules.
 :
 : This function is called by templates:init() where it is used to pass all available 
 : configuration down to the eXist HTML templating function.  
 :
 : @param $project Project ID
 : @return
~:)
declare function config:config($project as xs:string) as item()* {
    let $project-config:=   config:project-config($project),
        $module-config:=    config:module-config(),
        $repo-config :=     $config:cr-config//params
    return ($project-config, $module-config,$repo-config)
};

declare function config:config-map($project as xs:string) as item()* {
    map { "config" := config:config($project)}
};

(:~ Gets the catalog file for the given project. 
 : <b>Beware:</b> Former fall-back mechanisms have been deprecated.
 : 
 : @param $project project identifier
 : @return config element with relevant parameters.
 :)
declare function config:project-config($project as xs:string) as element()* {
    let $project := collection($config-params:projects-dir)//mets:mets[@OBJID eq $project]
    return $project
};


(:~
 : Getter function for a cr-project's mappings.
 :
 : @param $item: input. We accept strings or elements() as well as a map. This may contain one of the following keys:
 : <ol>
 :      <li>'config': the 'classic' config with project and module-wide configuration</li>
 :      <li>'mets': the cr-project file of the project</li>
 :      <li>'mappings': a <map> of this specific project</li>
 : </ol>
 : @result: one or more <map> elements 
 ~:)
declare function config:mappings($config as item()*) as element(map)* {
    for $item in $config return 
        typeswitch ($item)
            case map()          return 
                                    ($item("config")//mets:techMD[@ID=$config:PROJECT_MAPPINGS_ID]/mets:mdWrap[1]/mets:xmlData/map,
                                    $item("mets")//mets:techMD[@ID=$config:PROJECT_MAPPINGS_ID]/mets:mdWrap[1]/mets:xmlData/map,
                                    $item("mappings"))[1]
            case xs:string      return config:project-config($item)//mets:techMD[@ID=$config:PROJECT_MAPPINGS_ID]/mets:mdWrap[1]/mets:xmlData/*
            case text()         return config:project-config($item)//mets:techMD[@ID=$config:PROJECT_MAPPINGS_ID]/mets:mdWrap[1]/mets:xmlData/*
            case element()      return $item//mets:techMD[@ID=$config:PROJECT_MAPPINGS_ID]/mets:mdWrap[1]/mets:xmlData/*
            default             return ()
};

(:~ lists all defined projects based on the project-id param in the config.
 :  this would only read the projects in separate folders:
    let  $projects := xmldb:get-child-collections($config-params:projects-dir)
    and we want to take also projects into account without a separate folder, defined solely by their config
    (especially meant for external projects, that shall have only a minimal mention)
    
@returns the ids of all projects 
:)
declare function config:list-projects() {
       collection($config-params:projects-dir)//mets:mets/xs:string(@OBJID)
};


(:~
 : Lists the names of currently available modules. 
 : This function simply lists the children in the cr-xq's 'modules'-collection as defined in $config:modules-dir.  
 :
 : @return sequence of modules' names 
~:)
declare function config:list-modules() as xs:string* {
       xmldb:get-child-collections($config:modules-dir)
};


(:~ Fetches configuration files for all avaiable modules.
 : This function tries to locate the file 'conf.xml' in each of the modules' collection 
 : found by <code>config:list:modules()</code>. 
 : 
 : @returns a sequence of module-config documents. 
~:)
declare function config:module-config() as item()* { 
    for $module in config:list-modules()
    return 
        if (doc-available($config:modules-dir||$module||"/config.xml"))
        then doc($config:modules-dir||$module||"/config.xml")
        else ()
};

(:~ checks if there is a cr-catalog file for given project
 :  
 : @param $project project identifier
~:)
declare function config:project-exists($project as xs:string) {
    exists(collection($config-params:projects-dir)//mets:mets[@OBJID = $project])
};

declare function config:shib-user() {
(for $attribute-name in ('cn', 'eppn', 'REMOTE_USER','affiliation')                            
                                    return request:get-attribute($attribute-name))[1]
};