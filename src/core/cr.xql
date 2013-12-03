xquery version "3.0";

import module namespace project = "http://aac.ac.at/content_repository/project" at "project.xqm";
import module namespace resource = "http://aac.ac.at/content_repository/resource" at "resource.xqm";
import module namespace rf = "http://aac.ac.at/content_repository/resourcefragment" at "resourcefragment.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";

declare namespace public = "http://aac.ac.at/content_repository/project/public";
declare namespace mets = "http://www.loc.gov/METS/";
declare namespace cr = "http://aac.ac.at/content_repository"; 

(:~
 : This XQuery is the endpoint for any user-driven content management.
 : It basically maps the lower level functions in project.xqm, resource.xqm and resourcefragment.xqm to a 
 : public interface by interpreting the annotations in the 
 : modules' function definitions.
 :
 : @author Daniel Schopper
 : @since 2013-11 
~:)

(:~
 : We automatically determine which entity has been requested. In the following order: 
 :  - if present, the header/parameter 'entity'
 :  - if there's only a project-pid, 'project' is assumed,
 :  - if there's a project-pid and a resource-pid, latter is assumed,
 :  - if there's project-pid, resource-pid and resource-fragment-pid, latter is assumed.
 : - by default 'project' is returned 
~:)
declare variable $entity :=
    let $req:=      local:get-parameter("entity"),
        $params:=   local:get-parameter-names()
    return
    switch (true())
        case $req !="" return $req
        case $params='project-pid' and not($params='resource-pid') and not($params='resourcefragment-pid') return "project"
        case $params='project-pid' and $params='resource-pid' and not($params='resourcefragment-pid') return "resource"
        case $params='project-pid' and $params='resource-pid' and $params='resourcefragment-pid' return " "
        default return "project"
; 
    
declare variable $namespaces :=  map {
    "project" := "http://aac.ac.at/content_repository/project",
    "resource" := "http://aac.ac.at/content_repository/resource",
    "resourcefragment" := "http://aac.ac.at/content_repository/resourcefragment"
};

declare variable $prefixes :=  map {
    "project" := "project",
    "resource" := "resource",
    "resourcefragment" := "rf"
};

declare variable $entity-ns := $namespaces($entity);
declare variable $entity-ns-prefix := $prefixes($entity);


declare variable $functions:=
    for $f in inspect:module-functions(xs:anyURI($config:app-root||"/core/"||$entity||".xqm"))
    return inspect:inspect-function($f);


declare variable $local:properties := $functions[annotation[@name='property:name']];
declare variable $public-properties := $local:properties[annotation[@name='property:realm']/value='public'];
declare variable $protected-properties := $local:properties[annotation[@name='property:realm']/value='protected'];
declare variable $properties-names := $local:properties/annotation[@name="property:name"]/data(value);

declare variable $local:methods := $functions[annotation/@name='method:name'];
declare variable $public-methods := $local:methods[annotation[@name='method:realm']/value='public'];
declare variable $protected-methods := $local:methods[annotation[@name='method:realm']/value='protected'];
declare variable $methods-names := $local:methods/annotation[@name='method:name']/data(value);


declare variable $project-pid := local:get-parameter("project-pid");
declare variable $resource-pid := local:get-parameter("resource-pid");
declare variable $resourcefragment-pid := local:get-parameter("resourcefragment-pid");

(: a shortcut to the main entity's id :)
declare variable $id :=
    switch($entity)
        case "resourcefragment" return $resourcefragment-pid
        case "resource"         return $resource-pid
        case "project"          return $project-pid
        default                 return $project-pid
;


declare function local:get() {
    switch($entity)
        case "project"              return project:get($project-pid)
        case "resource"             return resource:get($resource-pid,$project-pid)
        case "resourcefragment"     return rf:get($resourcefragment-pid,$resource-pid,$project-pid)
        default                     return ()
};

(:~
 : Helper functions for output formatting
~:)
declare function local:wrap($id as xs:string, $content as item()*){
    element {QName($entity-ns,$entity)} {
        attribute id {$id},
        $content
    }
};

(: TODO transfer to WSDL :)
declare function local:format-content($content as item()*){
    let $format := request:get-header("Accept") 
    return 
        switch (true())
            case contains($format,"xml")    return $content
            case contains($format,"html")   return $content
            default                 return $content
};


(:~
 : Helper function which gets parameters either as reqeust parameters or http headers, 
 : depending on the reqeust method.    
~:)
declare function local:get-parameter($name as xs:string) {
    local:get-parameter($name,"")
};

declare function local:get-parameter($name as xs:string, $default as item()?) {
    if ($name eq 'data')
    then $default
    else 
        if (request:get-method() = ("POST","DELETE","PUT")) 
        then (request:get-header($name),$default)[1] 
        else request:get-parameter($name,$default)
};

(:~
 : Get parameter names and add a 'virtual' parameter $data when the request body is not empty.
~:)
declare function local:get-parameter-names() as xs:string* {
   if (request:get-method() = ("POST","DELETE","PUT")) 
   then (request:get-header-names(),if(exists(request:get-data())) then 'data' else ())
   else (request:get-parameter-names(),if(exists(request:get-data())) then 'data' else ())
};


declare function local:user-role(){
    ()
};

declare function local:describe($id){
    local:wrap($id,(
        element {QName($entity-ns,'properties')} {
            <usage>Properties are queried via GET requests, adding one or more request parameters with name 'property' and the name of the property to retrieve. Request parameter id (id of the project to query) is required. 'Realm' denotes whether the property is world readable or not.</usage>,
            for $p in $local:properties
            let $name := $p/annotation[@name='property:name']/data(value),
                $realm := $p/annotation[@name='property:realm']/data(value)
            return 
            element {QName($entity-ns,'property')} {
                attribute realm {$realm},
                attribute name {$name},
                element description {data($p/normalize-space(description))}
            }
        },
        element {QName($entity-ns,'methods')} {
            <usage>Methods are execute via POST, PUT or DELETE requests, adding one or more request headers with appropriate names. Header 'id' (id of the project to query) is required.</usage>,
            for $me in $local:methods  
            let $parameters:= $me/argument[@var!='data'],
                $realm := $me/annotation[@name='method:realm']/data(value),
                $group := $me/annotation[@name='method:group']/data(value),
                $name := $me/annotation[@name='method:name']/data(value)
            return 
               element {QName($entity-ns,'method')} {
                    attribute name {$name},
                    attribute method {"POST"}, 
                    attribute realm {$realm},
                    attribute groups {$group},
                    attribute data {exists($me/argument[@var='data'])},
                    element description {data($me/normalize-space(description))},
                    for $p in $parameters return
                        element {QName($entity-ns,'parmeter')} {
                            attribute name {$p/@var},
                            attribute type {$p/@type},
                            element description {data($p)}
                        }
                }
        }
    ))
};

declare function local:find-function($description as element(function)) as item()* {
    try {
    function-lookup(xs:QName($description/xs:string(@name)),count($description/argument))
    } catch * {
        ()
    }
};

declare function local:apply($f as function, $s as item()*){
    switch(count($s))
        case 0 return $f()
        case 1 return $f($s)
        case 2 return $f($s[1],$s[2])
        case 3 return $f($s[1],$s[2],$s[3])
        case 4 return $f($s[1],$s[2],$s[3],$s[4])
        case 5 return $f($s[1],$s[2],$s[3],$s[4],$s[5])
        case 6 return $f($s[1],$s[2],$s[3],$s[4],$s[5],$s[6])
        case 7 return $f($s[1],$s[2],$s[3],$s[4],$s[5],$s[6],$s[7])
        case 8 return $f($s[1],$s[2],$s[3],$s[4],$s[5],$s[6],$s[7],$s[8])
        case 9 return $f($s[1],$s[2],$s[3],$s[4],$s[5],$s[6],$s[7],$s[8],$s[9])
        case 10 return $f($s[1],$s[2],$s[3],$s[4],$s[5],$s[6],$s[7],$s[8],$s[9],$s[10])
        default return $f($s)
};

(: we only accept one project-id and one method (to avoid side-effects), but several 'property' request parameters :)
let $request-method := request:get-method()
let $method :=  local:get-parameter("method","")[1],
    $property :=local:get-parameter("property","")
                
    
let $data := 
    let $d:=request:get-data()
    return 
        typeswitch($d)
            case document-node()    return $d/node()
            default                 return $d


let $content:=
    switch (true())
        (: all request methods except PUT require an id to be set :)
        case ($id = "" and $request-method != 'PUT') return <cr:error>missing required parameter id</cr:error>
        case $request-method != 'PUT' and not(local:get()) return <cr:error>{$entity-ns-prefix} with id "{$id}" does not exist</cr:error>
        default return
            switch ($request-method)
                case 'DELETE' return
                    switch($entity)
                        case "project" return
                            if (xs:boolean(local:get-parameter("purge")) eq true())
                            then project:purge($id,true())
                            else project:purge($id)
                        case "project" return
                            if (xs:boolean(local:get-parameter("purge")) eq true())
                            then resource:purge($id,true())
                            else resource:purge($id,false())
                        default return ()
                case 'POST' return
                    if ($method = $methods-names)
                    then 
                        (: here we map request parameters to function arguemnts, i.e. remove 'method' request parmaeter, add a data argument with the content of the request body :)
                        (: get all function definitions for this function name :)
                        let $all-defs := $local:methods[annotation[@name='method:name']/value = $method]
                        (: iterate over all fn definitions and find those, whose arguments are provided in request-parameters :)
                        let $def:= 
                            let $match-args:=for $x in $all-defs return $x[every $a in $x/argument/xs:string(@var) satisfies $a = local:get-parameter-names()]
                            (: get the matching function with the most number of arguments :)
                            return $match-args[count(arguments) = max(count($match-args/arguments))]
                        let $fn := 
                            if (exists($def)) 
                            then local:find-function($def) 
                            else () 
                        return 
                            if (exists($fn))
                            then 
                                let $args:= 
                                    for $x in $def/argument/xs:string(@var) return 
                                    if ($x eq 'data') then $data
                                    else local:get-parameter($x)
                                return local:apply($fn,$args) 
                            else <error>no function found for method {$method}</error> 
                    else
                        if ($method = '')
                        then <cr:error>Missing parameter 'method'.</cr:error>
                        else <cr:error>undefined method '{$method}'</cr:error>
                
                case 'PUT' return
                    switch ($entity-ns-prefix)
                        case "project" return 
                            switch (true())
                                case ($id!='' and $data instance of element (mets:mets)) return project:new($data, $id)
                                case ($id!='') return project:new($id)
                                default return project:new()
                        case "resource" return 
                            let $resource-pid:=
                                if (local:get-parameter("prepareData") = true())
                                then resource:new($data,$project-pid, true())
                                else resource:new($data,$project-pid, false())
                            return resource:get($resource-pid,$project-pid)
                        default return ()
                        
                (: GET only serves static properties :)
                case 'GET' return
                    if (exists($property))
                    then 
                        let $values := 
                        (: filter: only consider valid propertise:)
                            let $properties := distinct-values($property),
                                $total := count($properties)
                            return
                                for $p at $pos in $properties return
                                    element project:property {
                                            attribute id {$p},
                                            attribute n {$pos},
                                            attribute total {$total},
                                            attribute known {$p = $properties-names},
                                            if ($p = $properties-names)
                                            then 
                                                let $description := $local:properties[annotation[@name='property:name']/value=$p]
                                                let $f := local:find-function($description)
                                                return
                                                    if (exists($f))
                                                    then $f($id)
                                                    else <error>function for property {$p} not found. {xs:anyURI($description/@name)} {count($description/argument)} {$local:properties[annotation[@name='property:name']/value=$p]}</error>
                                            else ()
                                    }
                        return 
                            if (some $x in $property satisfies $x != '')
                            then local:wrap($id,$values)
                            (: by default just describe the available properties and methods :)
                            else local:describe($id)
                    else local:describe($id)
                default 
                    return local:describe($id) 

return local:format-content($content)