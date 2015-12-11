xquery version "3.0";
module namespace gen = "http://aac.ac.at/content_repository/generate-index";
import module namespace project = "http://aac.ac.at/content_repository/project" at "../../core/project.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "../../core/config.xqm";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at "../../core/repo-utils.xqm";
import module namespace index = "http://aac.ac.at/content_repository/index" at "../../core/index.xqm";

declare namespace xconf = "http://exist-db.org/collection-config/1.0";

declare variable $gen:INDEX_TYPE_FT := 'ft';
declare variable $gen:xpath-type := ('base','match','label','match-only','label-only');
declare variable $gen:cr := "&#10;";
declare variable $gen:project-index-functions-ns-base-uri := "http://aac.ac.at/content-repository/projects-index-functions/";
declare variable $gen:project-index-functions-ns-short := "ixfn";
declare variable $gen:project-index-functions-module-name := "index-functions";
declare variable $gen:project-index-functions-module-filename := $gen:project-index-functions-module-name||".xqm";

(:~ generates the code for translating abstract index names to explicit xpaths based on the mappings defined for given project
and stores it as a file in the modules collection of given project 
@param $project project identifier as xs:string or project config as element(mets:METS)
@returns result of storing the module
:)
declare function gen:generate-index-functions($project) as item()* {
let $project-pid := project:get-id($project)
let $log := util:log-app("DEBUG",$config:app-name, "gen:generate-index-functions("||$project-pid||")")
let $config := config:config($project-pid)
let $map := index:map($project-pid)
(:    <map><index name="person">:)
(:                    <path>tei:person</path>:)
(:                    </index>:)
(:                <index name="place">:)
(:                <path>tei:place</path>:)
(:                </index>:)
(:                </map>:)

let $indexes := $map//index

let $generated-code :=
    <processor-code>xquery version '3.0';
module namespace {gen:ns-short($project-pid)} = "{gen:ns($project-pid)}";
(:import module namespace config="http://exist-db.org/xquery/apps/config" at "../../core/config.xqm";:)

{(
       for $ns in $map//namespaces/ns
       return "declare namespace "||$ns/@prefix||" = '"||$ns/@uri||"';"||$gen:cr,
       (: we want to make sure that the system namespaces are declared, even if they are missing in the project configuration :)
       if (not($map//namespace/ns = "http://www.loc.gov/METS/"))
       then "&#10;declare namespace mets = 'http://www.loc.gov/METS/';"
       else (),
       if (not($map//namespace/ns = "http://clarin.eu/fcs/1.0"))
       then "&#10;declare namespace fcs = 'http://clarin.eu/fcs/1.0';"
       else (),
       if (not($map//namespace/ns = "http://aac.ac.at/content_repository"))
       then "&#10;declare namespace cr = 'http://aac.ac.at/content_repository';"
       else ()
)}

(: project-specific mapping of abstract indexes to xpaths as defined in the "map" in project-configuration :)

declare {"function "||gen:ns-short($project-pid)||":apply-index" (: this is just to fool the script analyzing the dependencies :) }($data as node()*, $index-name as xs:string, $x-context as xs:string, $type as xs:string?) as item()* {{ {$gen:cr}
     
       
      switch ($type) 
      {
      for $xtype in ($gen:xpath-type,'default')
       let $case :=  if ($xtype='default') then 'default' else "case '"||$xtype||"'"         
       return ($case||" return switch ($index-name) ", $gen:cr, 
        for $ix in $indexes
        let $ix-name := $ix/data(@key)         
(:        let $ix-path := $ix/path/text():)
        let $ix-path := index:index-as-xpath($ix-name,$config, $xtype),
            $relative-ix-path := if (starts-with($ix-path, '/')) then $ix-path else '/'||$ix-path
        
        return 
           "&#09;case '"||$ix-name||"' return $data"||$relative-ix-path||$gen:cr,
           
           (:"&#09;default return util:log-app('WARN',$config:app-name, concat('Index ',$index-name,' is not defined.'))"||$gen:cr:)
           "&#09;default return ()"||$gen:cr
           
    ) }
  }};

</processor-code>
(:"&#09;default return util:eval('$data//'||$index-name) ", $gen:cr:)

let $store := gen:store-index-functions($generated-code, $project-pid)

(: regenerate the top-level index-functions module, so that the new index functions are available immediately :)
(:return gen:register-project-index-functions():)
return $store
};
 
(:~ stores given code as a file in the modules collection of given project
if the module is written first time then also regenerate the top level module, so that it imports the newly created project-specific module
however the top-level module generation is invoked  only after storing the project-specific module, because the generating function checks for existence of the file 

@param $code the generated code to be stored
@param $project-pid project identifier
@returns result of storing the module
:) 
declare function gen:store-index-functions($code as xs:string, $project-pid) {
    let $module-dir-path := project:path($project-pid,'home')||'/modules'
    
    let $mkcol :=   if (xmldb:collection-available($module-dir-path))
                    then ()
                    else repo-utils:mkcol("/", $module-dir-path)
                    
    let $module-path := project:path($project-pid,'home')||'/modules/'||$gen:project-index-functions-module-filename
    let $generate-top-level-module-first-time := not(util:binary-doc-available($module-path))
    
                    
    let $store:=    xmldb:store($module-dir-path, $gen:project-index-functions-module-filename, $code, 'application/xquery')
    let $exec:=     xmldb:set-resource-permissions($module-dir-path, $gen:project-index-functions-module-filename, 'guest', 'guest', 755)
    (: top-level module generation only after storing the project-specific module, because the generating function checks for existence of the file :)
    let $top-level-module :=
        if ($generate-top-level-module-first-time) then 
            let $log := util:log-app("INFO",$config:app-name,"gen:store-index-functions first time generating, registering module using gen:register-project-index-functions()")
            return gen:register-project-index-functions()
        else 
            let $log := util:log-app("INFO",$config:app-name,"gen:store-index-functions regenerating, NOT registering module!")
            return ()
    return $store 
};

(:~ generates the top level module that imports the project-specific index-function modules 
and provides one function that dispatches to project-specific index functions
the import and switch-case is generated only for projects that already have an index-function module
this module is stored directly under $app-root/modules
:)
declare function gen:register-project-index-functions() {
    let $projects := config:list-projects()
    
(: check if the project has custom index-functions generated :)
    let $projects-with-index-functions := 
        for $project-pid in $projects        
            let $module-path := project:path($project-pid,'home')||'/modules/'||$gen:project-index-functions-module-filename
            return if (util:binary-doc-available($module-path)) then $project-pid else ()

    let $import-statements := 
        for $project-pid in $projects-with-index-functions       
            let $module-path := project:path($project-pid,'home')||'/modules/'||$gen:project-index-functions-module-filename
            return  "import module namespace "||gen:ns-short($project-pid)||"='"||gen:ns($project-pid)||
                                        "' at '"||$module-path||"';"||$gen:cr
                   
(:return (xs:anyURI($gen:project-index-functions-ns-base-uri),$gen:project-index-function-modulename,xs:anyURI($module-path))  :)
let $generated-code :=
    <processor-code>xquery version '3.0';
module namespace {$gen:project-index-functions-ns-short} = "{$gen:project-index-functions-ns-base-uri}"; 

{$import-statements }

declare function {$gen:project-index-functions-ns-short||":apply-index" (: this is just to fool the script analyzing the dependencies :) }($data as node()*, $index-name as xs:string, $x-context as xs:string, $type as xs:string?) as item()* {{ { $gen:cr}
  
{    let $project-case-statements :=  for $project in $projects-with-index-functions
                let $case-statement := "&#09;case '"||$project||"' return "||gen:ns-short($project)||":apply-index($data, $index-name, $x-context, $type)"
                return $case-statement

    return "switch ($x-context)"||$gen:cr||string-join($project-case-statements, $gen:cr)||$gen:cr
            ||"&#09;default return ()"||$gen:cr
        
 }      
  }};

</processor-code>
(:        ||"&#09;default return util:eval('$data//'||$index-name)"||$gen:cr:)
(:let $store := gen:store-index-functions($generated-code, $project-pid):)
(:return $generated-code/text():)
 
    let $module-path:=     $config:app-root||'/modules/'||$gen:project-index-functions-module-name||'/'
    
    let $store:=    xmldb:store($module-path, $gen:project-index-functions-module-filename, $generated-code/text(), 'application/xquery')
    let $exec:=     xmldb:set-resource-permissions($module-path, $gen:project-index-functions-module-filename, 'guest', 'guest', 755)
    return $exec
};


(:~ helper function to consistently formulate the namespace for the project index functions 
:)
declare function gen:ns($project-pid) {
$gen:project-index-functions-ns-base-uri||$project-pid
};

(:~ helper function to consistently formulate the namespace shortcut for the project index functions 
:)
declare function gen:ns-short($project-pid) {
$gen:project-index-functions-ns-short||"-"||$project-pid
};

(:~ OBSOLETED
 Meant to dynamically import project specific index mapping functions
 however this would require a dynamic module import + function loookup upon every apply-index request, which may be rather inefficient
 Thus this approach is deprecated in favor of explicit setup, where the correct function is found via switch, that is generated upon project-map creation. 
:)
declare function gen:import-project-index-functions($x-context) {
let $module-path := project:path($x-context,'home')||"/modules/index-functions.xqm"
(:return (xs:anyURI($gen:project-index-functions-ns-base-uri),$gen:project-index-function-modulename,xs:anyURI($module-path))  :)
return if (util:binary-doc-available($module-path)) then
(:    util:import-module(xs:anyURI($gen:project-index-functions-ns-base-uri||$x-context),$x-context,xs:anyURI($module-path)):)
    util:import-module(xs:anyURI($gen:project-index-functions-ns-base-uri),$gen:project-index-function-ns-short,xs:anyURI($module-path))
   else
    
    util:import-module(xs:anyURI($gen:project-index-functions-ns-base-uri),$gen:project-index-function-ns-short,xs:anyURI($module-path))
};
