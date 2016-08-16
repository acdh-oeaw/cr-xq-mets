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

module namespace repo-utils = "http://aac.ac.at/content_repository/utils";
declare namespace mets="http://www.loc.gov/METS/";
declare namespace xlink="http://www.w3.org/1999/xlink";
declare namespace fcs = "http://clarin.eu/fcs/1.0";
declare namespace cr="http://aac.ac.at/content_repository";
declare namespace xi="http://www.w3.org/2001/XInclude";


import module namespace xdb="http://exist-db.org/xquery/xmldb";
import module namespace diag =  "http://www.loc.gov/zing/srw/diagnostic/" at  "../modules/diagnostics/diagnostics.xqm";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace project="http://aac.ac.at/content_repository/project" at "project.xqm";
import module namespace resource="http://aac.ac.at/content_repository/resource" at "resource.xqm";
import module namespace ltb="http://aac.ac.at/content_repository/lookuptable" at "lookuptable.xqm";
import module namespace rf="http://aac.ac.at/content_repository/resourcefragment" at "resourcefragment.xqm";
import module namespace index="http://aac.ac.at/content_repository/index" at "/db/apps/cr-xq-dev0913/core/index.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
(:~ HELPER functions - configuration, caching, data-access
:)

(:
: this all cannot be defined as global variable, because we want different configurations,
: thus the $config has to be sent sas param everywhere
: declare variable $repo-utils:config := doc("config.xml");
: declare variable $repo-utils:mappings := doc(repo-utils:config-value('mappings'));
: declare variable $repo-utils:data-collection := collection(repo-utils:config-value('data.path'));
: declare variable $repo-utils:md-collection := collection(repo-utils:config-value('metadata.path'));
: declare variable $repo-utils:cachePath as xs:string := repo-utils:config-value('cache.path');
:)

declare variable $repo-utils:xmlExt as xs:string := ".xml";
declare variable $repo-utils:responseFormatXml as xs:string := "xml";
declare variable $repo-utils:responseFormatJSon as xs:string := "json";
declare variable $repo-utils:responseFormatText as xs:string := "text";
declare variable $repo-utils:responseFormatHTML as xs:string := "html";
declare variable $repo-utils:responseFormatHTMLpage as xs:string := "htmlpage";

declare variable $repo-utils:sys-config-file := "conf/config-system.xml";

declare function repo-utils:base-url($config as item()*) as xs:string* {
        (: On Jetty 9+ this is actually done by Jetty, exist-db usess Jetty 8 :)
    let $mets :=    $config/descendant-or-self::mets:mets[@TYPE='cr-xq project'],
        $urlScheme := if ((lower-case(request:get-header('X-Forwarded-Proto')) = 'https') or 
                          (lower-case(request:get-header('Front-End-Https')) = 'on')) then 'https:' else 'http:',
        $realUrl := replace(request:get-url(), '^http:', $urlScheme)
    return substring-before($realUrl,$config:app-root-collection)||$config:app-root-collection||$mets/xs:string(@OBJID)||"/"     
};

declare function repo-utils:base-uri($config as item()*) as xs:string* {
   let $mets :=    $config/descendant-or-self::mets:mets[@TYPE='cr-xq project']
   return substring-before(request:get-uri(),$config:app-root-collection)||$config:app-root-collection||$mets/xs:string(@OBJID)||"/"
};

(:~
 : Helper function which programmatically defines prefix-namespace-bindings 
 : in a project map.
 : 
 : @param $config: the config of the current project.
~:)
declare function repo-utils:declare-namespaces($config as item()*) as empty() {
    let $mappings:=config:mappings($config),
        $namespaces:=$mappings//namespaces
    return 
        for $ns in $namespaces/ns
        let $prefix:=$ns/@prefix,
            $namespace-uri:=$ns/@uri
        let $log:=util:log("INFO", "declaring namespace "||$prefix||"='"||$namespace-uri||"'")
        return util:declare-namespace(xs:string($prefix), xs:anyURI($namespace-uri))
};

declare function repo-utils:config($config-file as xs:string) as node()* {
let $sys-config := if (doc-available($repo-utils:sys-config-file)) then doc($repo-utils:sys-config-file) else (),
    $config := if (doc-available($config-file)) then (doc($config-file), $sys-config) 
                        else diag:diagnostics("general-error", concat("config not available: ", $config-file))
    return $config
};

declare function repo-utils:config-value($config, $key as xs:string) as xs:string? {
    let $project-config:=$config/config[not(xs:string(@type)='system' or xs:string(@type)='module')]//(param|property)[xs:string(@key)=$key],
        $module-config:=$config/config[xs:string(@type)='module']//(param|property)[xs:string(@key)=$key],
        $system-config:=$config/config[xs:string(@type)='system']//(param|property)[xs:string(@key)=$key],
        $top-level-config:=$config//(param|property)[xs:string(@key)=$key]
    return ($project-config,$module-config,$system-config,$top-level-config)[1]
};

declare function repo-utils:config-values($config, $key as xs:string) as xs:string* {
    ($config/config[not(xs:string(@type)='system' or xs:string(@type)='module')]//(param|property)[xs:string(@key)=$key],
      $config/config[xs:string(@type)='module']//(param|property)[xs:string(@key)=$key],
      $config/config[xs:string(@type)='system']//(param|property)[xs:string(@key)=$key],
      $config//(param|property)[xs:string(@key)=$key]  (: accept also top-level param|property :)
      )
};

(:declare function repo-utils:config-value($config, $key as xs:string) as xs:string* {
    ($config[not(@type='system')]//(param|property)[@key=$key], $config[@type='system']//property[@key=$key])[1]
};
:)
(:~ Get value of a param based on a key, from config or from request-param (precedence) :)
declare function repo-utils:param-value($config, $key as xs:string, $default as xs:string) as xs:string* {
(:    let $param := request:get-parameter($key, $default):)
    let $param := $config//(param|property)[@key=$key]
    return 
        if ($param) 
        then $param 
        else $default
};

(:~ This function returns a node set consisting of all available documents of the project as listed in mets:fileGrp[@USE="Project Data"]     
 : 
 : @param $project-pid: The CR-Context
 : @param $config: The mets-config of the project
~:)
declare function repo-utils:context-to-collection($project-pid as xs:string, $config) as node()* {
    let $dbcoll-path := repo-utils:context-to-collection-path($project-pid, $config)
    let $docs:= 
        if ($dbcoll-path = "" ) then ()
        else
            for $p in $dbcoll-path
            return
                if (ends-with($p,'.xml'))
                then doc($p)                
                else if (xmldb:collection-available($p)) then
                   collection($p)
                 else ()
     return ($docs)
};


(:~ This function returns a node set consisting of all available documents of the project as listed in mets:fileGrp[@USE="Project Data"]     
 : 
 : @param $project-pid: The CR-Context
 : @param $config: The mets-config of the project
~:)
declare function repo-utils:context-to-fragments($x-context as xs:string) as item()* {
    let $projects:=config:path("projects"),
    	$contexts:=tokenize($x-context,",")
    return 
        for $c in $contexts
    	let $id := normalize-space($c),
    		$div:= collection($projects)//mets:div[@ID eq $id],
(:    		$project := if (exists($div)) then () else collection($projects)//mets:mets[@OBJID eq $id]:)
    		$fileid := ($div/mets:fptr/@FILEID,$div/mets:fptr/mets:area/@FILEID),
    		$uri := root($div)//mets:file[ancestor::mets:fileGrp[@ID eq $config:PROJECT_DATA_FILEGRP_ID] and @ID eq $fileid]/mets:FLocat/@xlink:href
(:    		$doc := doc($uri):)
    	return xs:string($uri) 
    	    (:if ($fileid/parent::mets:area)
    	    then $doc//fcs:resourceFragment[@cr:id=$fileid/parent::mets:area/@BEGIN]
    	    else $doc:)
};


(:~ This function returns paths to all available data files of the given project.
if $x-context is empty the path to the project' collection of working copies is returned,
otherwise the list of all data files of the project is returned
 :
 : @param $x-context: The CR-Context
 : @param $config: The mets-config of the project
~:)
declare function repo-utils:context-to-collection-path($x-context as xs:string*, $config) as xs:string* {
    let $context-type := repo-utils:context-to-type($x-context,$config)
    return
        if ($context-type = "project")
        then project:path($x-context, 'workingcopies')
        else 
            if ($context-type='resource')
            then 
                let $project-pid := repo-utils:context-to-project-pid($x-context,$config)
                return resource:path($x-context,$project-pid,'workingcopy')
            else ()
(:    project:path($x-context, 'workingcopies'):)
    (:let $projectData:=     $config//mets:fileGrp[@USE="Project Data"]//mets:file/mets:FLocat
    return 
        for $d in $projectData/@xlink:href return
            if (doc-available($d)) 
            then xs:string($d)
            else ():)
};

declare function repo-utils:context-to-type($x-context as xs:string*, $config) as xs:string* {
    let $projects := config:path("projects"),
        $div := collection($projects)//mets:div[@ID = normalize-space($x-context)],
        $mets := collection($projects)//mets:mets[@OBJID = normalize-space($x-context)]
    return 
        switch(true())
            case exists($mets) return "project"
            case exists($div) return $div/xs:string(@TYPE)
            default return util:log-app("ERROR",$config:app-name,"Can't resolve $x-context '"||normalize-space($x-context)||"'")
};

declare function repo-utils:context-to-project-pid($x-context as xs:string?, $config) as xs:string* {
    let $projects := collection(config:path("projects"))
    return 
        switch(true())
            case exists($projects//mets:mets[@OBJID = $x-context]) return $x-context
            case exists($projects//mets:div[@ID = $x-context]) return $projects//mets:div[@ID = $x-context]/ancestor::mets:mets/@OBJID/xs:string(.)
            default return ()
};

declare function repo-utils:context-to-resource-pid($x-context as xs:string?) as map()* {
    repo-utils:context-to-resource-pid($x-context,())
};

declare function repo-utils:context-to-resource-pid($x-context as xs:string?, $config) as map()* {
    let $projects := collection(config:path("projects"))
    let $div := $projects//mets:div[@ID = $x-context]
    let $project-pid := $div/ancestor::mets:mets/@OBJID/xs:string(.),
        $resource-pid := if ($div/@TYPE='resource') then $x-context else $div/ancestor::mets:div[@TYPE='resource']/xs:string(@ID)
    return
        if (exists($div))
        then 
            map:new((
                    map:entry("project-pid",$project-pid),
                    map:entry("resource-pid",$resource-pid)
               ))
        else ()
};

(: returns 0-n map(s) in the form
 : [
 :   ["id"      : "abacus2.2_16" ],
 :   ["operand" : "except" ],
 :   ["type"    : "resourcefragment" ],
 : ]
:)
declare function repo-utils:parse-x-context($x-context as xs:string, $config) as map()* {
    let $contexts := tokenize($x-context,',')
    let $maps := 
        for $c at $pos in distinct-values($contexts)
            let $operand := switch (true())
                                        case substring($c,1,1) = "+" return "union"
                                        case substring($c,1,1) = "-" return "except"
                                        default return "union"
            let $c-id := normalize-space(if (substring($c,1,1) = ("+","-")) then substring($c,2) else $c)
            let $type := repo-utils:context-to-type($c-id,$config)
            return 
                if ($type)
                then
                    let $log := util:log-app("TRACE",$config:app-name,"parsing x-context '"||$x-context||"' part #"||$pos||" - id: '"||$c-id||"', "||"type: '"||$type||"', operand: '"||$operand||"'")
                    return 
                    map:new((
                        map:entry("operand",$operand),
                        map:entry("type",$type),
                        switch ($type)
                            case "resourcefragment" return (map:entry("resourcefragment-pid",$c-id),repo-utils:context-to-resource-pid($c-id,$config))
                            case "resource" return repo-utils:context-to-resource-pid($c-id,$config)
                            default return map:entry("project-pid",$c-id)
                   ))
                else ()
    return $maps
};

declare function repo-utils:context-to-data($x-context as xs:string, $config) as item()* {
    repo-utils:context-map-to-data(repo-utils:parse-x-context($x-context, $config),$config)
   };

(:~
 : returns nodes of the given context, e.g. "x-context=abacus2" or "x-context=abacus2.1,abacus2.2".
 : resources or fragments *excluded* via x-context ("x-context=abacus2,-abacus2.1") are not filtered out
 : here but  
~:)
declare function repo-utils:context-map-to-data($x-context as map()*, $config) as item()* {
    let $path-expressions := 
        for $p at $pos in $x-context  
        let $type := map:get($p,'type'),
            $operand := if ($pos=1) then () else " "||map:get($p,'operand')||" "
        let $log := util:log-app("TRACE",$config:app-name,"$type: '"||$type||"' $operand: '"||$operand||"'")
        let $path := 
            switch ($type)
                    case "project" return $operand||"collection('"||project:path($p("project-pid"),"workingcopy")||"')"
                    case "resource" return $operand||"doc('"||resource:path($p("resource-pid"),$p("project-pid"),'workingcopy')||"')"
                    case "resourcefragment" return " union doc('"||resource:path($p("resource-pid"),$p("project-pid"),'workingcopy')||"')"
                    default return ()
        return $path
    let $log := util:log-app("TRACE",$config:app-name,"constructed data path: "||string-join($path-expressions,''))        
    let $data := util:eval(string-join($path-expressions,''))
    return $data 
};


declare function repo-utils:filter-by-context($data as item()*, $x-context as map()+, $config) as item()* { 
        if (not(exists($x-context))) 
        then $data
        else 
            let $assertions-by-type := 
                map:new(
                    for $a in $x-context 
                    group by $assertion-type := map:get($a,'type')
                    return map:entry($assertion-type,$a)),
                $assertion-types := map:keys($assertions-by-type)
            return
                (: we aggregate the nodes by resource and 
                   apply those assertions that refer to this resource :)
                for $x in $data
                group by $r-pid := $x/@cr:resource-pid
                return 
                    (: get maps that directly exclude or include this resource :)
                    let $r-map := for $p in $assertions-by-type("resource")
                                  return 
                                      if (map:get($p,'resource-pid') = $r-pid)
                                        then $p 
                                        else ()
                    return
                        if (not(exists($r-map)) and $assertion-types = "resource")
                        then ()
                        else 
                             if (some $x in $r-map satisfies map:get($x,'operand') = 'except')
                             then ()
                             else  
                                 (: we gather cr:ids of elements in this resource $r-pid 
                                    that are referenced via fragment-pids in the x-context,
                                    and group them as keys in a map.
                                    [
                                       "exclude": ("cr:id1","cr:id2","cr:id3",...)
                                       "include": ("cr:id4","cr:id5",...)
                                    ]
                                    :)
                                 
                                 if (map:contains($assertions-by-type,"resourcefragment"))
                                 then 
                                     let $rf-assertions-for-current-resource := map:get($assertions-by-type,"resourcefragment")
                                     let $element-ids-by-operand := 
                                         let $maps := 
                                             for $assertions-by-operand in $rf-assertions-for-current-resource
                                             group by $operand := $assertions-by-operand("operand")
                                             return
                                                 let $cr-ids:=
                                                     for $a in $assertions-by-operand
                                                     return
                                                         if ($a("resource-pid") = $r-pid)
                                                         then ltb:dump($a("resourcefragment-pid"),$a("resource-pid"),$a("project-pid"))//data(cr:id)
                                                         else ()
                                                 return map:entry($operand,$cr-ids)
                                         return map:new($maps)
                                     return
                                         if (exists($element-ids-by-operand("except")))
                                         then  
                                            if (exists($element-ids-by-operand("union")))
                                            then $x[not(@cr:id = $element-ids-by-operand("except"))][@cr:id = $element-ids-by-operand("union")]
                                            else $x[not(@cr:id = $element-ids-by-operand("except"))]
                                         else 
                                            if (exists($element-ids-by-operand("union")))
                                            then $x[@cr:id = $element-ids-by-operand("union")]
                                            else $x
                                 else $x
};

(: filters a set of nodes by its project, resource or resourcefragment.
 : the 'assertion' maps (second parameter) take the following form:
 : map {
 :    "type" := "resourcefragment",
 :    "id" := "abacus2.1_64",
 :    "operand" := "exclude"
 : }
:)
(:declare function repo-utils:filter-by-context($data as item()*, $assertions as map()*, $config) as item()* {
    if (count($assertions) eq 0)
    then $data
    else
        let $assertions-ordered :=  for $a in $assertions
                                    let $type := map:get($a,'type'),
                                        $order := ("resourcefragment","resource","project")
                                    order by index-of($order,$type)
                                    return $a
        let $current := $assertions-ordered[1]
};:)

(:~
 : Retrieves the id of the resourcefragment(s) a given element is part of.
 : 
 : @param $resource-pid: the PID of the resource to be looked into
 : @param $x-elementID: the internal cr:id of the element to be looked up
 : @param $project-pid: the context/project
 : @param $config: the mets-config of the project 
 : @return one or more resourcefragment-pids 
~:)
declare function repo-utils:element-pid-to-resourcefragment-pid($resource-pid as xs:string, $x-element-pid as xs:string, $project-pid as xs:string, $config) as xs:string* {
    let $tables-path:=$config//param[@key='lookuptable.path']/xs:string(.)
    let $lookup-table:=repo-utils:get-from-cache($project-pid||"-"||$resource-pid||".xml",$tables-path,$config)
    let $fragments:=$lookup-table//fcs:ResourceFragment[cr:id=$x-element-pid]
    return $fragments/xs:string(@pid)
};
(:
(\:~ This function returns paths to all available resources of the given project by looking at the 
 : projects struct map.
 : 
 : a resource may consist of 
 :      - a single xml instance 
 :      - multiple fragment instances, which constitute the resource in sum
 : 
 : Here we only sum up only the the _full_ resources.  
 :
 : @param $project-pid: The CR-Context
 : @param $config: The mets-config of the project
 : @return 
~:\)
declare function repo-utils:resources-in-project($project-pid as xs:string, $config)  {
    let $projectResources:=project:resources($config//mets:mets)
    return 
    for $d in $projectResources return
        if ($d/mets:fptr/@FILEID) 
        then 
            let $resource-pid := xs:string($d/@ID) 
            let $fileID:=xs:string($d/mets:fptr/@FILEID)
            let $file:=$config//mets:file[@ID eq $fileID]
            return 
                if (doc-available($file/mets:FLocat/@xlink:href))
                then 
                    map{
                        "resource-pid" := $resource-pid,
                        "content" := doc($file/mets:FLocat/@xlink:href)
                    }
                else util:log("INFO","document "||$file||" not available")
        else ()
};:)

declare function repo-utils:fileuri-to-resource-pid($filepath as xs:string, $project-pid as xs:string, $config) as xs:string? {
    let $fileID:=$config//mets:file[mets:FLocat/@xlink:href eq $filepath]/@ID
    return $config//mets:div[@TYPE='resource' and mets:fptr/@FILEID eq $fileID]/xs:string(@ID) 
};

(:~ Get the resource by PID/handle/URL or some known identifier.
  TODO: NOT ADAPTED YET! (taken from CMD)
  TODO: be clear about resource itself and metadata-record!
:)
(:declare function repo-utils:get-resource-by-id($id as xs:string) as node()* {
  let $collection := collection($cr:dataPath)
  return 
    if ($id eq "" or $id eq $cr:collectionRoot) then
    $collection//IsPartOf[. = $cr:collectionRoot]/ancestor::CMD
  else
    util:eval(concat("$collection/ft:query(descendant::MdSelfLink, <term>", xdb:decode($id), "</term>)/ancestor::CMD"))
 (\: $collection/descendant::MdSelfLink[. = xdb:decode($id)]/ancestor::CMD :\)
};
:)

(:~ Checks whether the document is available or not.
  generic, currently not used
:)
declare function repo-utils:is-doc-available($collection as xs:string, $doc-name as xs:string) as xs:boolean {
  fn:doc-available(fn:concat($collection, "/", $doc-name))
};

declare function repo-utils:is-in-cache($doc-name as xs:string,$config) as xs:boolean {
    repo-utils:is-in-cache($doc-name,$config, 'indexes') 
};

declare function repo-utils:is-in-cache($doc-name as xs:string,$config, $type as xs:string) as xs:boolean {
    let   $project-pid := config:param-value($config,'project-pid'),
        $cache-path := project:path($project-pid, $type)  
    return fn:doc-available($cache-path||"/"||$doc-name)
};


declare function repo-utils:get-from-cache($doc-name as xs:string,$config) as item()* {
        repo-utils:get-from-cache($doc-name, $config, 'indexes')     
};

declare function repo-utils:get-from-cache($doc-name as xs:string,$config, $type) as item()* {
   let   $project-pid := config:param-value($config,'project-pid'),
        $cache-path := project:path($project-pid, $type)
    let $path := fn:concat($cache-path, "/", $doc-name)
    let $log := util:log-app("DEBUG",$config:app-name,"retrieving from path "||$path)
    return if (util:is-binary-doc($path))
            then util:binary-doc($path)
            else fn:doc($path)
};

(:
This seems weird - TO BE DEPRECATED
declare function repo-utils:get-from-cache($doc-name as xs:string,$path,$config) as item()* {
    if (util:is-binary-doc($path))
    then util:binary-doc($path)
    else fn:doc($path)
};
:)
(:~ 
 : Store the data in Cache, which is set in the parameter "cache.path" in the config. 
 : The function uses its own writer-account. 
 :  
 : @param $doc-name: the filename of the resource to create/update.
 : @param $data: the data to store
 : @param $config: the config for the current project  
 
~:)
declare function repo-utils:store-in-cache($doc-name as xs:string, $data as node(),$config) as item()* {    
    repo-utils:store-in-cache($doc-name,$data,$config,'indexes')
};

(:~ 
 : Store the data in Cache to the specified collection. 
 : The function uses its own writer-account. 
 : if the file exists, it will be overwritten
 
  : instead of sending the cache-collection, the correct path is established based on project-context and $type 
 : @param $doc-name: the filename of the resource to create/update.
 
 : @param $data: the data to store
 : @param $config: the config for the current project
 : @param $type: type of cache

~:)
declare function repo-utils:store-in-cache($doc-name as xs:string, $data as node(),$config,$type) as item()* {
  let   $project-pid := config:param-value($config,'project-pid'),
        $cache-path := project:path($project-pid, $type),
        $writer := fn:doc(config:path('writer.file')),
        $writer-name :=  $writer//write-user/text(),
        $writer-pw := $writer//write-user-cred/text()
    let $log := util:log-app("DEBUG",$config:app-name,"storing to file "||$cache-path||"/"||$doc-name)
    let $log := util:log-app("DEBUG",$config:app-name,"reading credentials from "||config:path('writer.file'))
  return system:as-user($writer-name, $writer-pw,
        let $mkcol :=   if (xmldb:collection-available($cache-path))
                    then ()
                    else local:mkcol-recursive(tokenize($cache-path,'/')[1],tokenize($cache-path,'/')[position() gt 1]),
        
            $rem :=if (util:is-binary-doc(concat($cache-path, $doc-name))) then
                            xdb:remove($cache-path, $doc-name)
                          else if (doc-available(concat($cache-path, $doc-name))) 
                            then xdb:remove($cache-path, $doc-name)  
                            else (),
                            
            $store := try { xdb:store($cache-path, $doc-name, $data)
                        } catch * {
                            let $msg := "problem storing "||$doc-name||" to "||$cache-path
                            let $dummy-log := util:log-app("ERROR", $config:app-name, $msg)
                            return diag:diagnostics("general-error", $msg )
                            }, 
            $stored-doc := 
                if (util:is-binary-doc(concat($cache-path, "/", $doc-name))) 
                then util:binary-doc(concat($cache-path, "/", $doc-name))
                else fn:doc(concat($cache-path, "/", $doc-name))
        return $stored-doc
    )
};


(: 
this tries to create sub-collections in index for
individual data-collection - but it makes the retrieval etc. also more complicated 
so rather encoding the data-collection also in the name  

declare function repo-utils:store-in-cache($data-collection as item(), $doc-name as xs:string, $data as node()) as item()* {
    let $data-coll-name := collection-name($data-collection) 
    let $index-coll-path := concat($repo-utils:cachePath, "/", $data-coll-name )
   let $create-coll := if (not(xmldb:collection-available($index-coll-path ))) then 
                           xmldb:create-collection($repo-utils:cachePath, $data-collname) else ()
  let $store-result := repo-utils:store($index-coll-path, $doc-name, $data, true())

return $store-result
};
:)

(:~ Store the data somewhere (in $collection)
checks for logged in user and only tries to use the internal writer, if no user logged in.
:)
(:<options><option key="update">yes</option></options>:)
declare function repo-utils:store($collection as xs:string, $doc-name as xs:string, $data as node(), $overwrite as xs:boolean, $config) as item()* {
    let $log := util:log-app("INFO",$config:app-name,"repo-util:store($collection:"||$collection||",$doc-name:"||$doc-name||")")
  let $writer := fn:doc(config:path('writer.file')),
(: this fails out of request context: 
        $dummy := if (request:get-attribute("org.exist.demo.login.user")='') then:)
  $dummy := if (xmldb:get-current-user()='') then
                xdb:login($collection, $writer//write-user/text(), $writer//write-user-cred/text())
             else ()  

(:  let $rem := if ($overwrite and doc-available(concat($collection, $doc-name))) then xdb:remove($collection, $doc-name) else () :)

 let $mkcol :=   if (xmldb:collection-available($collection))
                    then ()
                    else repo-utils:mkcol("/", $collection)
  
let $rem :=if (util:is-binary-doc(concat($collection, $doc-name)) and $overwrite) then
                        xdb:remove($collection, $doc-name)
                      else if ($overwrite and doc-available(concat($collection, $doc-name))) 
                        then xdb:remove($collection, $doc-name)  
                        else ()
  
  let $store := (: util:catch("org.exist.xquery.XPathException", :) xdb:store($collection, $doc-name, $data),  
  $stored-doc := if (util:is-binary-doc(concat($collection, "/", $doc-name))) then  util:binary-doc(concat($collection, "/", $doc-name)) else fn:doc(concat($collection, "/", $doc-name))
  return $stored-doc
  
};


declare function repo-utils:gen-cache-id($type-name as xs:string, $keys as xs:string+, $depth as xs:string) as xs:string {   
    repo-utils:gen-cache-id($type-name , ($keys, $depth) )
};  
(:~ Create document name with md5-hash for selected collections (or types) for reuse.
:)
declare function repo-utils:gen-cache-id($type-name as xs:string, $keys as xs:string+) as xs:string {  
       let $sanitized-names := for $key in $keys return repo-utils:sanitize-name($key)
    return
(:    fn:concat($name-prefix, "-", util:hash(string-join($sorted-names, ""), "MD5"), $repo-utils:xmlExt):)
    fn:concat($type-name, "-", string-join($sanitized-names, "-"), $repo-utils:xmlExt)
};

(:~ wipes out problematic characters from names
:)
declare function repo-utils:sanitize-name($name as xs:string) as xs:string {
    translate($name, ":/",'_')
};

declare function repo-utils:serialise-as($item as node()?, $format as xs:string, $operation as xs:string, $config) as item()? {
    repo-utils:serialise-as($item, $format, $operation, $config, ())
};

(:~ 
 : Generic formating function which transforms results into the following formats, according to the function's 2nd parameter.
 :
 : Currently implemented formats are: 
 : <ul>
 :  <li>JSON</li>
 :  <li>HTML (fragment or full page)</li>
 :  <li>XML (default)</li>
 : </ul>
 : 
 : Possible names for each format are defined in the following module variables:
 : @see $repo-utils:responseFormatXml
 : @see $repo-utils:responseFormatJSon
 : @see $repo-utils:responseFormatText
 : @see $repo-utils:responseFormatHTML
 : @see $repo-utils:responseFormatHTMLpage
 : 
 : @param $item the data to be output
 : @param $format the output format  
 : @param $parameters optional additional parameters to be passed to xsl  
~:)
declare function repo-utils:serialise-as($item as node()?, $format as xs:string, $operation as xs:string, $config, $parameters as node()* ) as item()? {
(: FIXME: empty x-context macht wenig sinn!! :) 
        repo-utils:serialise-as($item, $format, $operation, $config, '', $parameters)
};
declare function repo-utils:serialise-as($item as node()?, $format as xs:string, $operation as xs:string, $config, $x-context as xs:string, $parameters as node()* ) as item()? {
    switch(true())
        case ($format eq $repo-utils:responseFormatJSon) return	       
	       let $xslDoc := repo-utils:xsl-doc($operation, $format, $config),
	           $xslParams:=    <parameters>
	                               <param name="format" value="{$format}"/>
	                               <param name="x-context" value="{$x-context}"/>
	                               <param name="cr_project" value="{config:param-value($config, 'project-pid')}"/>
	                               <param name="base_url" value="{config:param-value($config,'base-url')}"/>
	                               <param name="base_url_public" value="{config:param-value($config,'base-url-public')}"/>
	                               <param name="fcs_prefix" value="{config:param-value($config,'fcs-prefix')}"/>
	                               <param name="mappings-file" value="{config:param-value($config, 'mappings')}"/>
	                               <param name="scripts_url" value="{config:param-value($config, 'scripts.url')}"/>
	                               <param name="site_name" value="{config:param-value($config, 'site.name')}"/>
	                               <param name="site_logo" value="{config:param-value($config, 'site.logo')}"/>
	                               {$parameters/param}
	                           </parameters>
	       let $res := if ($xslDoc) 
	                   then
	                       let $option := util:declare-option("exist:serialize", "method=text media-type=application/json")
	                       return transform:transform($item,$xslDoc,$xslParams)
                       else 
                           let $option := util:declare-option("exist:serialize", "method=json media-type=application/json")    
                           return $item
	       return $res
	       
	    case (contains($format, $repo-utils:responseFormatHTML)) return
	       let $xslDoc :=      repo-utils:xsl-doc($operation, $format, $config),
	           $xslParams:=    <parameters>
	                               <param name="format" value="{$format}"/>
              			           <param name="operation" value="{$operation}"/>
              			           <param name="x-context" value="{$x-context}"/>
              			           <param name="cr_project" value="{config:param-value($config, 'project-pid')}"/>
	                               <param name="base_url" value="{config:param-value($config,'base-url')}"/>
	                               <param name="base_url_public" value="{config:param-value($config,'base-url-public')}"/>
              			           <param name="resource-id" value="{config:param-value($config, 'resource-pid')}"/>
                                    <param name="fcs_prefix" value="{config:param-value($config,'fcs-prefix')}"/>
                                    <param name="mappings-file" value="{config:param-value($config, 'mappings')}"/>
                                    <param name="dict_file" value="{config:param-value($config, 'dict_file')}"/>
	                               <param name="scripts_url" value="{concat(config:param-value($config, 'base-url'),config:param-value($config, 'scripts-url'))}"/>
	                               <param name="site_name" value="{config:param-value($config, 'site-name')}"/>
	                               <param name="site_logo" value="{concat(config:param-value($config, 'base-url'),config:param-value($config, 'site-logo'))}"/>
	                               <param name="site_url" value="{config:param-value($config, 'public-baseurl')}"/>
              			           {$parameters/param}
              			       </parameters>
(:                <param name="base_url" value="{config:param-value($config,'base-url')}"/>
<param name="base_url" value="{config:param-value($config,'public-repo-baseurl')}"/>
:)
	       let $res := if (exists($xslDoc)) 
	                   then transform:transform($item,$xslDoc, $xslParams)
	                   else 
	                       let $log:=util:log-app("ERROR", $config:app-name, "repo-utils:serialise-as() could not find stylesheet '"||$xslDoc||"' for $operation: "||$operation||", $format: "||$format||".")
	                       return diag:diagnostics("unsupported-param-value",concat('$operation: ', $operation, ', $format: ', $format))
	       let $option := util:declare-option("exist:serialize", "method=xhtml media-type=text/html")
	       return $res
	   default return
	       let $option := util:declare-option("exist:serialize", "method=xml media-type=application/xml")
	       return $item
};


(:~
 : Getter function for output formatting stylesheets: returns an document node() with the appropriate stylesheet
 : given the current operation ($operation) and the desired output format ($format).
 : 
 : It tries to determine the best fitting XSL file by looking in any db collection mentioned 
 : in any <code>param key='scripts.path'</code> in $config (this includes project configs as well as module configs). 
 : In there tries to fetch files witch are mentioned in any config param named  
 : <ul>
 :      <li>'$operation-$format.xsl' or </li>
 :      <li>'$operation.xsl' or </li>
 : <ul>
 : 
 : It returns the <b>first</b> document in the resulting sequence.
 :
 :  
 : @param $operation the operation which produced the result to be output. (no restriction)
 : @param $format the name of the desired output format
 : @param $config the global configuration map.
 : @return zero or one XSL documents 
~:)
declare function repo-utils:xsl-doc($operation as xs:string, $format as xs:string, $config) as document-node()? {        
    let $scripts-paths := (config:param-value($config,'scripts.path'),config:path('scripts'))
    let $log := util:log-app("DEBUG",$config:app-name,"looking for xsl-doc in "||string-join($scripts-paths,' '))
    let $xsldoc :=  for $p in $scripts-paths
                    let $path := replace($p,'/$','')
                    return 
(:                        let $path := replace($path,'/$',''):)
                        let $operation-format-xsl:= $path||'/'||config:param-value($config, $operation||'-'||$format||".xsl"),
                            $operation-xsl:= $path||'/'||config:param-value($config, $operation||".xsl")
                        return 
                        switch(true())
                            case (doc-available($operation-format-xsl)) 
                                return (
                                    util:log-app("DEBUG",$config:app-name,"found xsl-doc "||$operation-format-xsl||" for operation "||$operation||", format "||$format),
                                    doc($operation-format-xsl)
                                    )
                            case (doc-available($operation-xsl)) return 
                                (util:log-app("DEBUG",$config:app-name,"found xsl-doc "||$operation-xsl||" for operation "||$operation||", format "||$format),doc($operation-xsl))
                            default return util:log-app("DEBUG",$config:app-name,"Could not find xsl-doc "||$operation-xsl||" for operation "||$operation||", format "||$format)
    return ($xsldoc)[1]
};

(:~ helper function. Performs multiple replacements, using pairs of replace parameters. based on standard xpath2 function replace() 
taken from: http://www.xqueryfunctions.com/xq/functx_replace-multi.html
:)
declare function repo-utils:replace-multi   ( $arg as xs:string? ,    $changeFrom as xs:string* ,    $changeTo as xs:string* )  as xs:string? {
       
   if (count($changeFrom) > 0)
   then repo-utils:replace-multi(
          replace($arg, $changeFrom[1],
                  repo-utils:if-absent($changeTo[1],'')),
          $changeFrom[position() > 1],
          $changeTo[position() > 1])
   else $arg
 } ;
 
 (:~ used by replace-multi()
taken from: http://www.xqueryfunctions.com/xq/functx_if-absent.html
:)
declare function repo-utils:if-absent ( $arg as item()* , $value as item()* )  as item()* {
    if (exists($arg)) then $arg else $value
 } ;


(: Helper function to recursively create a collection hierarchy. 
xmldb:create-collection actually obviously can do this - no need for recursive call (anymore?) :)
declare function repo-utils:mkcol($collection as xs:string, $path as xs:string) {
    try {
    xmldb:create-collection($collection, $path)
    } catch * {
      let $log := util:log-app("ERROR",$config:app-name, "Could not create collection "||$path||" in collection "||$collection||". "||string-join(($err:code , $err:description, $err:value),' - ') )
      return ()
    }
    
(:    local:mkcol-recursive($collection, tokenize($path, "/")):)
};

(:~
OBSOLETED by xmldb:create-collection()
:)
declare function local:mkcol-recursive($collection, $components) {
    if (exists($components) and exists($collection)) 
    then
        let $newColl := concat($collection, "/", $components[1])
        return (
            xdb:create-collection($collection, $components[1]),
            local:mkcol-recursive($newColl, subsequence($components, 2))
        )
    else ()
};


(:declare function repo-utils:get-record-pid($reference) as xs:string? {
    typeswitch($reference)
        case xs:string return $reference
        case text() return $reference
        case attribute(OBJID) return $reference/parent::mets:mets/xs:string(@OBJID)
        case attribute(ID) return $reference/parent::mets:div/xs:string(@ID)
        case element(mets:mets) return $reference/xs:string(@OBJID)
        case element(mets:div) return $reference/xs:string(@ID)
        case document-node() return $reference/mets:mets/xs:string(@OBJID)
        default return ()
}; 


(\:~ Returns the METS record of a project or resource, regardless of what 
 : kind of reference (project-pid string, text(), @OBJID, is passed to the function.
 : This allows us to pass either a project-pid, resource-pid or their resolved records in
 : function definitions.
 : @param $reference any item with relation to a resource or a mets record (elements like mets:div, mets:mets, PIDs, document-nodes etc.)
:\)
declare function repo-utils:get-record($reference) as element()? {
    typeswitch($reference)
        case xs:string return (project:get($reference),collection(config:path("projects"))//mets:div[@ID = $reference])[1]
        case text() return (project:get($reference),collection(config:path("projects"))//mets:div[@ID = $reference])[1]
        case attribute(OBJID) return project:get($reference)
        case attribute(ID) return collection(config:path("projects"))//mets:div[@ID = $reference]
        case element(mets:mets) return $reference
        case element(mets:div) return $reference
        case document-node() return $reference/*
        default return ()
}; 
:)



declare function repo-utils:get-record-pid($reference-param) as xs:string? {
    for $reference in $reference-param return 
    typeswitch($reference)
        case xs:string return 
            let $log := util:log-app("TRACE",$config:app-name,"$reference is xs:string '"||$reference||"'.")
            return $reference
        
        case text() return 
            let $log := util:log-app("TRACE",$config:app-name,"$reference is text() '"||$reference||"'.")
            return $reference
        
        case attribute(OBJID) return 
            let $log := util:log-app("TRACE",$config:app-name,"$reference is @OBJID '"||$reference||"'.")
            return $reference/parent::mets:mets/xs:string(@OBJID)
        
        case attribute(ID) return 
            let $log := util:log-app("TRACE",$config:app-name,"$reference is @ID '"||$reference||"'.")
            return $reference/parent::mets:div/xs:string(@ID)
        
        case element(mets:mets) return 
            let $log := util:log-app("TRACE",$config:app-name,"$reference is <mets:mets OBJID='"||$reference/@OBJID||"'/>.")
                return $reference/xs:string(@OBJID)
                
        case element(mets:div) return
            let $log := util:log-app("TRACE",$config:app-name,"$reference is <mets:div ID='"||$reference/@  ID||"'/>.")
            return $reference/xs:string(@ID)
            
        case document-node() return 
            let $log := util:log-app("TRACE",$config:app-name,"$reference is document-node()/"||$reference/local-name(*)||".")
            return ($reference/mets:mets/xs:string(@OBJID),$reference/mets:div/xs:string(@ID))[1]
        
        default return ()
}; 


(:~ Returns the METS record of a project or resource, regardless of what 
 : kind of reference (project-pid string, text(), @OBJID, is passed to the function.
 : This allows us to pass either a project-pid, resource-pid or their resolved records in
 : function definitions.
 : @param $reference any item with relation to a resource or a mets record (elements like mets:div, mets:mets, PIDs, document-nodes etc.)
:)
declare function repo-utils:get-record($reference-param) as element()? {
    let $references-resolved := 
        for $reference in $reference-param return  
        typeswitch($reference)
            case xs:string return 
                let $log := util:log-app("TRACE",$config:app-name,"$reference is xs:string '"||$reference||"'.")
                return (project:get($reference),collection(config:path("projects"))//mets:div[@ID = $reference])[1]
                
            case text() return 
                let $log := util:log-app("TRACE",$config:app-name,"$reference is text() '"||$reference||"'.")
                return (project:get($reference),collection(config:path("projects"))//mets:div[@ID = $reference])[1]
                
            case attribute(OBJID) return 
                let $log := util:log-app("TRACE",$config:app-name,"$reference is @OBJID '"||$reference||"'.")
                return project:get($reference)
                
            case attribute(ID) return 
                let $log := util:log-app("TRACE",$config:app-name,"$reference is @ID '"||$reference||"'.")
                return collection(config:path("projects"))//mets:div[@ID = $reference]
                
            case element(mets:mets) return 
                let $log := util:log-app("TRACE",$config:app-name,"$reference is <mets:mets OBJID='"||$reference/@OBJID||"'/>.")
                return $reference
                
            case element(mets:div) return 
                let $log := util:log-app("TRACE",$config:app-name,"$reference is <mets:div ID='"||$reference/@  ID||"'/>.")
                return $reference
            
            case document-node() return 
                let $log := util:log-app("TRACE",$config:app-name,"$reference is document-node()/"||$reference/local-name(*)||".")
                return ($reference/mets:mets,$reference/mets:div)[1]
            
            default return ()
    return $references-resolved
}; 



(: returns the database-nodes the given xinclude element refers to (instead of making an in-memory-copy)
 : @param $include one xi:include element
 : @return zero or more nodes
:)
declare function repo-utils:xinclude-to-fragment($include as element(xi:include)) as element()* {
    let $doc := doc($include/@href),
        $xpointer := $include/@xpointer,
        $xpAna := fn:analyze-string(xs:string($xpointer),'(xpointer\((.+?)\)|xmlns\((.+?)\))')
    let $xpath :=  $xpAna//fn:group[starts-with(.,'xpointer(')]/fn:group/text(),
        $nsDecls := $xpAna//fn:group[starts-with(.,'xmlns(')]/fn:group/text()
    return 
        switch(true())
            case (not(exists($doc))) return util:log-app("ERROR",$config:app-name,"repo-utils:xinclude-to-fragment(): document at "||$include/@href||" not available")
            case (not(exists($xpath)) or $xpath = '') return util:log-app("ERROR",$config:app-name,"repo-utils:xinclude-to-fragment(): could not parse xpath in "||$xpointer)
            default return  
                let $ns := for $nsdecl in $nsDecls
                               let $p := substring-before($nsdecl,'='), 
                                   $uri := substring-after($nsdecl,'=') 
                               return 
                                switch(true())
                                    case ($uri='') return util:log-app("ERROR",$config:app-name, " empty uri in xpointer")
                                    case (not($uri castable as xs:anyURI)) return util:log-app("ERROR",$config:app-name, $uri||" could not be cast to xs:anyURI; ignoring")
                                    case ($p='') return util:log-app("ERROR",$config:app-name, " empty prefix for uri "||$uri)
                                    default return (
                                        util:log-app("DEBUG",$config:app-name, "repo-utils:xinclude-to-fragment(): Declaring namespace "||$p||"="||$uri),
                                        util:declare-namespace($p,xs:anyURI($uri))
                                    ) 
                return 
                    try {
                        util:eval("$doc"||$xpath)
                    }
                    catch * {(
                        util:log-app("ERROR",$config:app-name, "An error occured evaluating $doc"||$xpath),
                        util:log-app("ERROR",$config:app-name, concat($err:code, ": ", $err:description)), 
                        util:log-app("ERROR",$config:app-name, "@xpointer "||$xpointer),
                        util:log-app("ERROR",$config:app-name, util:serialize($xpAna,'method=xml')),
                        util:log-app("ERROR",$config:app-name, $nsDecls)
                    )}
};