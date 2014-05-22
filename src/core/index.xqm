xquery version "3.0";

module namespace index = "http://aac.ac.at/content_repository/index";
import module namespace project = "http://aac.ac.at/content_repository/project" at "project.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at "repo-utils.xqm";
declare namespace xconf = "http://exist-db.org/collection-config/1.0";

declare variable $index:INDEX_TYPE_FT := 'ft';

(:~
@param $project id of the working context project or project-file
:)
declare function index:map($project) as element(map) {
    project:map($project)
};

(:~
@param $project id of the working context project or project-file
:)
declare function index:index($key as xs:string+, $project) as element(index)? {
    index:index-from-map($key, index:map($project))
 };

declare function index:index-from-map($key as xs:string+, $map) as element(index)? {
    $map//index[@key=$key]
};

(:~ gets the mapping for the index and creates an xpath (UNION)

This is a rework of the original fcs:index-as-xpath()
it expects second parameter to be just project-pid (for now), contrary to fcs, that  

FIXME: takes just first @use-param - this prevents from creating invalid xpath, but is very unreliable wrt to the returned data
       also tried to make a union but problems with values like: 'xs:string(@value)' (union operand is not a node sequence [source: String])

@param $key index-key as known to mappings 
@param $project id of the working context project or project-file
@param $type 'base' (or empty) returns the base xpath (without the @use-attribute); 'match' adds the @match-attribute ;  'label' adds the @label-attribute if present
            (for separate evaluation relative to base path: )
            "match-only" delivers only the value of @match-attribute (without base-path), or '.' if no @match attribute is present 
            "label-only" delivers only the value of @label-attribute (without base-path) or '.' if no @label attribute is present
             
@returns xpath-equivalent of given index as defined in mappings; multiple xpaths are translated to a UNION, 
           value of @use-attribute is also attached;  
         if no mapping found, returns the input-index unchanged 
:)
declare function index:index-as-xpath($key as xs:string, $project, $type as xs:string?) as xs:string {
    index:index-as-xpath-from-map($key, index:map($project), $type)
};

(:~ this expects already the index-map of the project as param, as opposed to the project file or id 
- this is meant to skip the resolution of the map
:)
declare function index:index-as-xpath-from-map($key as xs:string, $map, $type as xs:string?) as xs:string {    
    let $index := index:index-from-map($key, $map)        
    return if (exists($index)) then
       (:                 let $match-on := if (exists($index-map/@use) ) then 
                                            if (count($index-map/@use) > 1) then  
                                               concat('/(', string-join($index-map/@use,'|'),')')
                                            else concat('/', xs:string($index-map/@use)) 
                                         else '' :)
(:                                  let $match-on := if (exists($index/@use) ) then concat('/', xs:string($index[1]/@use)) else '':)

                        let $paths := switch (true()) 
                                    case ($type='label' and $index/path/@label) return 
                                        for $x in $index/path[@label] return concat($x,'/',$x/@label)
                                    case ($type='match' and $index/path/@match) return 
                                        for $x in $index/path[@match] return concat($x,'/', $x/@match)
                                    case ($type='label-only' and $index/path/@label) return $index/path[@label]/@label
                                    case ($type='label-only' and not($index/path/@label)) return '.'
                                    case ($type='match-only' and $index/path/@match) return $index/path[@match]/@match
                                    case ($type='match-only' and not($index/path/@match)) return '.'
                                    
                                    default return $index/path
(:                        let $paths := $index/path:)
                        let $indexes := if (count($paths) > 1) 
                                        (:then translate(concat('(', string-join($paths ,'|'),')', $match-on),'.','/')
                                        else translate(concat($paths, $match-on),'.','/'):)
                                        then '('||string-join($paths ,'|')||')'
                                        else $paths
                           return $indexes
(: unknown index - return the key - except for match-only or label-only : return just '.' :)                           
                  else if ($type = ('label-only', 'match-only')) then '.'
                            else translate($key,'.','/')
    
};

(:~
@param $project id of the working context project or project-file
:)
declare function index:index-as-xpath($key as xs:string, $project) as xs:string {
    index:index-as-xpath($key,$project,()    )
};


(:~ evaluate given index on given piece of data

mainly used when formatting record-data (fcs:format-record-data), to put selected pieces of data (indexes) into the results record 

This is a rework of (and should replace) the original fcs:apply-index()

@param $project id of the working context project or project-file
@returns result of evaluating given index's path on given data. or empty node if no mapping index was found
:)
declare function index:apply-index($data as item(), $index as xs:string, $project) as item()* {
  index:apply-index($data, $index, $project, () )
};

declare function index:apply-index($data as item(), $index as xs:string, $project, $type as xs:string?) as item()* {
    (:    let $index-map := index:indexfcs:get-mapping($index,$x-context, $config),:)
        let $index-xpath := index:index-as-xpath($index,$project, $type)
    
(:    $match-on := if (exists($index-map/@use) ) then concat('/', xs:string($index-map[1]/@use)) else ''
, $match-on:)
    let $define-ns:=
                let $index-map:=     project:map($project),
                    $namespaces:=   $index-map//namespaces/ns
                return 
                    for $ns in $namespaces
                        let $prefix:=   $ns/@prefix,
                            $namespace-uri:=$ns/@uri
(:                        let $log:=util:log-app("DEBUG", $config:app-name, "declaring namespace "||$prefix||"='"||$namespace-uri||"'"):)
                        return util:declare-namespace(xs:string($prefix), xs:anyURI($namespace-uri))
    return
        if (exists($index-xpath)) 
        then 
            let $plain-eval:=util:eval("$data//"||$index-xpath)
            return 
                if (exists($plain-eval))
                then $plain-eval
                else util:eval("util:expand($data)//"||$index-xpath)
        else util:log-app("ERROR", $config:app-name, "Could not generate index-path for index "||$index||" in project "||$project) 
};

(:~
@param $project id of the working context project or project-file
:)
declare function index:default($project) as element(index)? {
    index:map($project)//index[@key='cql.serverChoice']
};


declare function index:generate-xconf($project-pid as xs:string) as element(xconf:collection) {
    let $mappings := index:map($project-pid),
        $xsl := doc("mappings2xconf.xsl"),
        $params := <parameters></parameters>,
        $xconf := transform:transform($mappings,$xsl,$params)
    return $xconf
};

declare function index:store-xconf($project-pid as xs:string) {
    let $xconf:=index:generate-xconf($project-pid)
    let $paths:=(
        project:path($project-pid,'workingcopies')
        (:project:path($project-pid,'resourcefragments'),
        project:path($project-pid,'metadata'),
        project:path($project-pid,'lookuptables'):)
    )
    return
        for $p in $paths
        return
            let $config-path :=  "/db/system/config"||$p
            let $mkPath := repo-utils:mkcol("/db/system/config",$p)
            let $store:=xmldb:store($config-path,"collection.xconf",$xconf)
            return xmldb:reindex($p)
(:            return $xconf:)
};

declare function index:facets($index-key as xs:string, $project-pid as xs:string) as element(index) {
    let $index := index:index($index-key,$project-pid)
    return
    <index key="{$index-key}">{
        for $f in $index/@facet/tokenize(.,'\s')
        return index:facets($f,$project-pid)
    }</index>
};