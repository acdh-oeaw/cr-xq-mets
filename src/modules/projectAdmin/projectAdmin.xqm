xquery version "3.0";
module namespace projectAdmin = "http://aac.ac.at/content_repository/projectAdmin";
import module namespace project = "http://aac.ac.at/content_repository/project" at "../../core/project.xqm";

declare namespace rest="http://exquery.org/ns/restxq";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace xhtml="http://www.w3.org/1999/xhtml";

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
    let $form := $projectAdmin:config//form[@xml:id eq $form-id],
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
 : Maps the name of a form to the function in the project.xqm module, which
 : provides the data for editing - either by looking it up in config.xml or 
 : by searching for the function with the same name. 
 : (so a form named "dmd" will be mapped to "project:dmd" if nothing else  
 : was otherwise in config.xml.  
~:)
declare %private function projectAdmin:function-by-form($form as xs:string) {
    let $functionName := xs:string(($projectAdmin:config//function[@form = $form],"project:"||$form)[1])
    return  
        try {
            function-lookup(xs:QName($functionName), 1)
        } catch * {
            let $log := util:log("INFO", "could not lookup getter function for form "||$form||", I tried "||$functionName)
            return false()
        }
};

declare function projectAdmin:data($project-pid as xs:string, $form as xs:string) as element(xf:instance)* {
    let $function := projectAdmin:function-by-form($form)
    let $data:= if ($function instance of xs:boolean)
                then <empty xmlns=""/>
                else $function($project-pid)
    return <xf:instance id="{$form}" xmlns="">{$data}</xf:instance>
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
