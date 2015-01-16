xquery version "3.0";
module namespace projectAdmin = "http://aac.ac.at/content_repository/projectAdmin";
import module namespace project = "http://aac.ac.at/content_repository/project" at "../../core/project.xqm";
import module namespace resource = "http://aac.ac.at/content_repository/resource" at "../../core/resource.xqm";


declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace xhtml="http://www.w3.org/1999/xhtml";
declare namespace cr = "http://aac.ac.at/content_repository";

declare variable $projectAdmin:config:=doc("config.xml");
declare variable $projectAdmin:default-language:=$projectAdmin:config//lang[@default='true']/@xml:id;

declare 
    %rest:GET
    %rest:path("/projectAdmin/languages")
function projectAdmin:languages() as element(languages){
    $projectAdmin:config//languages
};

declare 
    %rest:GET
    %rest:path("/projectAdmin/i18n/{$form-id}/{$lang}")
    %output:media-type("text/xml")
    %output:method("xml")
function projectAdmin:labels($form-id as xs:string?, $lang as xs:string) as element(xf:instance) {
    let $form := $projectAdmin:config//form[@xml:id = $form-id],
        $labels := ($form/labels[@xml:lang = $lang]|$projectAdmin:config//i18n/common/labels[@xml:lang = $lang])
    return
        <xf:instance id="labels" xmlns="">
        	<labels>{
	            switch(true())
	                case exists($labels) return $labels/*
	                case exists($form/labels[@xml:lang = $projectAdmin:default-language]) return $form/labels[@xml:lang = $projectAdmin:default-language]/*
	                case exists($form//labels[@xml:lang = "en"]) return $form/labels[@xml:lang = "en"]/*
	                case exists($form[1]/*) return $form[1]/* 
	                default return <label/>
        	}</labels>
        </xf:instance>
};

declare 
    %rest:GET
    %rest:path("/projectAdmin/i18n/{$form}/{$form-control}/{$lang}")
    %output:media-type("text/plain")
    %output:method("text")
function projectAdmin:label($form as xs:string, $form-control as xs:string, $lang as xs:string) as xs:string? {
    let $label:=$projectAdmin:config//(form[@xml:id eq $form]|common)[1]//label[@key eq $form-control]
    return 
        switch(true())
            case exists($label[parent::*/@xml:lang = $lang]) return $label[parent::*/@xml:lang = $lang]
            case exists($label[parent::*/@xml:lang = $projectAdmin:default-language]) return $label[parent::*/@xml:lang = $projectAdmin:default-language]
            case exists($label[parent::*/@xml:lang = 'en']) return $label[parent::*/@xml:lang = "en"]
            case exists($label) return $label[1]
            default return $form-control 
};

(:~
 : Maps the name of a form to the function in the project.xqm or resource.xqm modules, which
 : provide the data for editing - either by looking it up in config.xml or 
 : by looking up the function. 
 : I.e. if nothing else  was explicitly defined in config.xml a form named 
 : "project-dmd" will be mapped to "project:dmd", a form "metsHdr"  
 : to "project:metsHdr" (by default the project module is assumed).
 : 
 : @param $form the form / data entity to be set or get.
 : @param $type retrieve the setter or getter method (default "getter")
 : @return a map with the keys "arity" and "function"
~:)
declare function projectAdmin:function-by-form($form as xs:string, $type as xs:string) as map()? {
    let $functionName :=
        switch(true())
            case exists($projectAdmin:config//function[@form = $form]) return $projectAdmin:config//function[@form = $form]
            case starts-with($form,'project-') return "project:"||substring-after($form,'project-')
            case starts-with($form,'project:') return $form
            case starts-with($form,'resource-') return "resource:"||substring-after($form,'resource-')
            case starts-with($form,'resource:') return $form
            case starts-with($form,'resourcefragment-') return "resourcefragment:"||substring-after($form,'resourcefragment-')
            case starts-with($form,'resourcefragment:') return $form
            default return "project:"||$form 
    let $arity as xs:integer :=
        if ($type = "setter") then 
            (: project setters have per default at least two parameters: $data and $project-pid,
               resource setters have $resource-pid as third parameter :)
            if (exists($projectAdmin:config//function[@form = $form]/@setter-arity))
            then $projectAdmin:config//function[@form = $form]/@setter-arity
            else 
                if (starts-with($functionName,'project:')) 
                then 2
                else 3
        else
            (: project getters have per default at least one parameter $project-pid,
               resource getters have $resource-pid as first parameter :)
            if (exists($projectAdmin:config//function[@form = $form]/@getter-arity))
            then $projectAdmin:config//function[@form = $form]/@getter-arity
            else 
                if (starts-with($functionName,'project:')) 
                then 1
                else 2
    return 
        try {
            map {
                "function" := function-lookup(xs:QName(xs:string($functionName)), $arity),
                "arity" := $arity
            }
        } catch * {
            let $log := util:log("INFO", "could not lookup getter function for form "||$form||", I tried "||$functionName||" with arity "||$arity)
            return ()
        }
};

declare function projectAdmin:instancedata($project-pid as xs:string, $form as xs:string) as element(xf:instance)* {
    let $function-found := exists(projectAdmin:function-by-form($form,"getter")) 
    let $function := if ($function-found)
                     then map:get(projectAdmin:function-by-form($form,"getter"),"function")
                     else ()
    let $data:= if (not($function-found))
                then <empty xmlns=""/>
                else $function($project-pid)
    return <xf:instance id="{$form}" xmlns="">
                <cr:data entity="{$form}" project-pid="{$project-pid}">{$data}</cr:data>
           </xf:instance>
};

declare function projectAdmin:data($project-pid as xs:string, $entity as xs:string) as element()? {
    let $function := map:get(projectAdmin:function-by-form($entity,"getter"),"function")
    let $data:= if ($function instance of xs:boolean)
                then ()
                else $function($project-pid)
    return <cr:data entity="{$entity}" project-pid="{$project-pid}">{$data}</cr:data> 
};

declare %private function projectAdmin:expandAVTs($node as node(), $variables as map(*)) {
    typeswitch ($node) 
        case attribute() return
            attribute {QName(namespace-uri($node),name($node))} {
                projectAdmin:expandAVTs(
                    text { xs:string($node) },
                    $variables
                )
            }
        case element() return 
            element {QName(namespace-uri($node),name($node))} { 
                for $n in ($node/@*,$node/node())
                return projectAdmin:expandAVTs($n,$variables)
            }
        case text() return 
            let $matches := fn:analyze-string($node,"\{\$(.*?)\}")
            return
                string-join(
                    for $i in $matches/* return
                        if ($i/self::fn:match and map:contains($variables,$i/fn:group))
                        then map:get($variables,$i/fn:group)
                        else $i
                    , ""
                )  
        case document-node() return
            projectAdmin:expandAVTs($node/root(),$variables)
        default return $node
};

declare function projectAdmin:bind($project-pid as xs:string, $form as xs:string, $variables as map()) as element()* {
    if (doc-available($form||".xml"))
    then
        let $doc :=         doc($form||".xml") 
        let $elts := $doc//(xf:bind|xf:instance|xf:submission)
        return 
            for $elt in $elts
                let $exp := projectAdmin:expandAVTs($elt,map:new((map:entry("project-pid",$project-pid),$variables)))
                return $exp
    else ()
};

declare function projectAdmin:form($form as xs:string?)  {
    if (doc-available($form||".html"))
    then doc($form||".html")/*
    else util:log("INFO", "Error: unknown form "||$form||".")
};

declare function projectAdmin:help($form as xs:string, $lang as xs:string) as element(xhtml:div)?{
    let $data  := doc("help-"||$lang||".html")//xhtml:div[@id eq "help-"||$form]
    return    
    <xf:instance id="help" xmlns="">{
        if (exists($data))
        then $data
        else 
            <xhtml:div>
                <xhtml:p>No help available for this context.</xhtml:p>
            </xhtml:div>
    }</xf:instance>
};

declare function projectAdmin:store($data as document-node(), $parameters as map()) {
    let $entity := $data/cr:data/xs:string(@entity)
    let $log := util:log("INFO", util:serialize($data,"method=xml indent=yes"))
    let $log := util:log("INFO", "$entity: "||$entity)
    return 
    switch ($entity)
        case "project-label"    return
                                   let $project-pid := $parameters("project-pid"),
                                        $log := util:log("INFO", $project-pid)
                                   return 
                                        if ($project-pid != '') 
                                        then 
                                            let $store := project:label($project-pid, document {($data/node())})
                                            return 
                                                if ($store)
                                                then $data
                                                else ()
                                        else ()
        case "uploadResource"   return 
                                   let $project-pid := $parameters("project-pid"),
                                       $resource-label :=  $parameters("resource-label")
                                   let $new := resource:new-with-label($data,$project-pid,$resource-label)
                                   return <data/>
        case "start"            return $data
        default                 return ()
};