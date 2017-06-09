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

module namespace templates="http://exist-db.org/xquery/templates";

(:~ 
 : HTML templating module
 : 
 : @version 2.0
 : @author Wolfgang Meier
:)
import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace project="http://aac.ac.at/content_repository/project" at "project.xqm";

declare namespace xhtml="http://www.w3.org/1999/xhtml";

declare variable $templates:CONFIG_STOP_ON_ERROR := "stop-on-error";

declare variable $templates:CONFIGURATION := QName("http://exist-db.org/xquery/templates", "configuration");
declare variable $templates:CONFIGURATION_ERROR := QName("http://exist-db.org/xquery/templates", "ConfigurationError");
declare variable $templates:NOT_FOUND := QName("http://exist-db.org/xquery/templates", "NotFound");
declare variable $templates:TOO_MANY_ARGS := QName("http://exist-db.org/xquery/templates", "TooManyArguments");
declare variable $templates:TYPE_ERROR := QName("http://exist-db.org/xquery/templates", "TypeError");

(:~ 
 : Start processing the provided content. Template functions are looked up by calling the
 : provided function $resolver. The function should take a name as a string
 : and return the corresponding function item. The simplest implementation of this function could
 : look like this:
 : 
 : <pre>function($functionName as xs:string, $arity as xs:int) { function-lookup(xs:QName($functionName), $arity) }</pre>
 :
 : @param $content the sequence of nodes which will be processed
 : @param $resolver a function which takes a name and returns a function with that name
 : @param $model a sequence of items which will be passed to all called template functions. Use this to pass
 : information between templating instructions.
:)
declare function templates:apply($content as node()+, $resolver as function(xs:string) as item()?, $model as map(*)?,
    $configuration as map(*)?) {
    let $model := if (exists($model)) then $model else map:new()
    let $configuration := 
        if (exists($configuration)) then 
            map:new(($configuration, map { "resolve" := $resolver }))
        else
            map { "resolve" := $resolver }
    let $model := map:new(($model, map:entry($templates:CONFIGURATION, $configuration)))
    for $root in $content
    return
        templates:process($root, $model)
};

declare function templates:apply($content as node()+, $resolver as function(xs:string) as item()?, $model as map(*)?) {
    templates:apply($content, $resolver, $model, ())
};

(:~
 : Continue template processing on the given set of nodes. Call this function from
 : within other template functions to enable recursive processing of templates.
 :
 : @param $nodes the nodes to process
 : @param $model a sequence of items which will be passed to all called template functions. Use this to pass
 : information between templating instructions.
:)
declare function templates:process($nodes as node()*, $model as map(*)) {
    for $node in $nodes
    return
        typeswitch ($node)
            case document-node() return
                for $child in $node/node() return templates:process($child, $model)
            case element() return
                let $instructions := templates:get-instructions($node/@class)
                return
                    if ($instructions) then
                        for $instruction in $instructions
                        return
                            templates:call($instruction, $node, $model)
                    else
                        element { node-name($node) } {
                            $node/@*, for $child in $node/node() return templates:process($child, $model)
                        }
            default return
                $node
};

declare %private function templates:get-instructions($class as xs:string?) as xs:string* {
    for $name in tokenize($class, "\s+")
    where templates:is-qname($name)
    return
        $name
};

declare %private function templates:call($class as xs:string, $node as element(), $model as map(*)) {
    let $paramStr := substring-after($class, "?"),
        $parameters := templates:parse-parameters($paramStr),
        $func := if ($paramStr) then substring-before($class, "?") else $class,
        $log := util:log-app('TRACE', $config:app-name, "templates:call $class := "||$class||', $paramStr := '||$paramStr||', $func := '||$func)
    let $call := templates:resolve(10, $func, $model($templates:CONFIGURATION)("resolve"))
    return
        if (exists($call)) then
            templates:call-by-introspection($node, $parameters, $model, $call)
        else if ($model($templates:CONFIGURATION)("stop-on-error")) then
            error($templates:NOT_FOUND, "No template function found for call " || $func)
        else
            (: Templating function not found: just copy the element :)
            element { node-name($node) } {
                $node/@*, for $child in $node/node() return templates:process($child, $model)
            }
};

declare %private function templates:call-by-introspection($node as element(), $parameters as element(parameters), $model as map(*), 
    $fn as function(*)) {
    let $inspect := util:inspect-function($fn)
    let $args := templates:map-arguments($inspect, $parameters)
    return
        templates:process-output(
            $node,
            $model,
            templates:call-with-args($fn, $args, $node, $model),
            $inspect
        )
};

declare %private function templates:call-with-args($fn as function(*), $args as (function() as item()*)*, 
    $node as element(), $model as map(*)) {
    switch (count($args))
        case 0 return
            $fn($node, $model)
        case 1 return
            $fn($node, $model, $args[1]())
        case 2 return
            $fn($node, $model, $args[1](), $args[2]())
        case 3 return
            $fn($node, $model, $args[1](), $args[2](), $args[3]())
        case 4 return
            $fn($node, $model, $args[1](), $args[2](), $args[3](), $args[4]())
        case 5 return
            $fn($node, $model, $args[1](), $args[2](), $args[3](), $args[4](), $args[5]())
        case 6 return
            $fn($node, $model, $args[1](), $args[2](), $args[3](), $args[4](), $args[5](), $args[6]())
        case 7 return
            $fn($node, $model, $args[1](), $args[2](), $args[3](), $args[4](), $args[5](), $args[6](), $args[7]())
        case 8 return
            $fn($node, $model, $args[1](), $args[2](), $args[3](), $args[4](), $args[5](), $args[6](), $args[7](), $args[8]())
        default return
            error($templates:TOO_MANY_ARGS, "Too many arguments to function " || function-name($fn))
};

declare %private function templates:process-output($node as element(), $model as map(*), $output as item()*, 
    $inspect as element(function)) {
    let $wrap := 
        $inspect/annotation[ends-with(@name, ":wrap")]
            [@namespace = "http://exist-db.org/xquery/templates"]
    return
        if ($wrap) then
            element { node-name($node) } {
                $node/@*,
                templates:process-output($node, $model, $output)
            }
        else
            templates:process-output($node, $model, $output)
};

declare %private function templates:process-output($node as element(), $model as map(*), $output as item()*) {
    typeswitch($output)
        case map(*) return
            templates:process($node/node(), map:new(($model, $output)))
        default return
            $output
};

declare %private function templates:map-arguments($inspect as element(function), $parameters as element(parameters)) {
    let $args := $inspect/argument
    return
        if (count($args) > 2) then
            for $arg in subsequence($inspect/argument, 3)
            return
                templates:map-argument($arg, $parameters)
        else
            ()
};

declare %private function templates:map-argument($arg as element(argument), $parameters as element(parameters)) 
    as function() as item()* {
    let $var := $arg/@var
    let $type := $arg/@type/string()
    let $passed-parameter := $parameters/param[@name = $var]/@value,
        $is-passed-parameter-important := substring-after($passed-parameter, "!important:"),
        $important-passed-parameter := if ($is-passed-parameter-important eq '') then () else $is-passed-parameter-important,
        $get-parameter := request:get-parameter($var, ()),
        $default-parameter := templates:arg-from-annotation($var, $arg),
(:        $log := util:log-app("DEBUG", $config:app-name, "templates:map-argument $var := "||xs:string($var)||
                                                                              " $important-passed-parameter := "||xs:string($important-passed-parameter)||
                                                                              " $get-parameter := "||xs:string($get-parameter)||
                                                                              " $passed-parameter := "||xs:string($passed-parameter)||
                                                                              " $default-parameter := "||xs:string($default-parameter)),:)
        $param := 
        (
            $important-passed-parameter,
            $get-parameter, 
            $passed-parameter,
            $default-parameter
        )[1]
    let $data :=
        try {
            templates:cast($param, $type)
        } catch * {
            error($templates:TYPE_ERROR, "Failed to cast parameter value '" || $param || "' to the required target type for " ||
                "template function parameter $" || $var || " of function " || ($arg/../@name) || ". Required type was: " ||
                $type || ". " || $err:description)
        }
    return
        function() {
            $data
        }
};

declare %private function templates:arg-from-annotation($var as xs:string, $arg as element(argument)) {
    let $anno := 
        $arg/../annotation[ends-with(@name, ":default")]
            [@namespace = "http://exist-db.org/xquery/templates"]
            [value[1] = $var]
    for $value in subsequence($anno/value, 2)
    return
        string($value)
};

declare %private function templates:resolve($arity as xs:int, $func as xs:string, 
    $resolver as function(xs:string, xs:int) as function(*)) {
    if ($arity < 2) then
        ()
    else
        let $fn := $resolver($func, $arity)
        return
            if (exists($fn)) then
                $fn
            else
                templates:resolve($arity - 1, $func, $resolver)
};

declare %private function templates:parse-parameters($paramStr as xs:string?) as element(parameters) {
    <parameters xmlns="">
    {
        for $param in tokenize($paramStr, "&amp;")
        let $key := substring-before($param, "=")
        let $value := substring-after($param, "=")
        where $key
        return
            <param name="{$key}" value="{$value}"/>
    }
    </parameters>
};

declare %private function templates:is-qname($class as xs:string) as xs:boolean {
    matches($class, "^[^:]+:[^:]+")
};

declare %private function templates:cast($values as item()*, $targetType as xs:string) {
    for $value in $values
    return
        if ($targetType != "xs:string" and string-length($value) = 0) then
            (: treat "" as empty sequence :)
            ()
        else
            switch ($targetType)
                case "xs:string" return
                    string($value)
                case "xs:integer" case "xs:int" case "xs:long" return
                    xs:integer($value)
                case "xs:decimal" return
                    xs:decimal($value)
                case "xs:float" case "xs:double" return
                    xs:double($value)
                case "xs:date" return
                    xs:date($value)
                case "xs:dateTime" return
                    xs:dateTime($value)
                case "xs:time" return
                    xs:time($value)
                case "element()" return
                    util:parse($value)/*
                case "text()" return
                    text { string($value) }
                default return
                    $value
};

(:-----------------------------------------------------------------------------------
 : Standard templates
 :-----------------------------------------------------------------------------------:)
 
  
(:~
 : This is the initializing function, that every template should call (very soon, i.e. at some of the top elements)
 : it provides context information to the other modules, currently it fetches the project-config file
 : 
 : @param $node the HTML node with the class attribute which triggered this call
 : @param $model a map containing arbitrary data - used to pass information between template calls
 : @param $project project-identifier
 :)
declare function templates:init($node as node(), $model as map(*), $project as xs:string?) {
       map {
       "config": config:config($project)
       }
};
 

(:declare function templates:include($node as node(), $model as map(*), $path as xs:string) {
    templates:process(config:resolve($model, $path), $model)
};

:)
declare %templates:default("filter", "") 
function templates:include($node as node(), $model as map(*), $path as xs:string, $filter as xs:string) {
    let $content := config:resolve($model, $path)
    let $restricted-content := if ($filter != '') then 
            (: try to handle namespaces dynamically 
                by switching  to source namespace :)
            let $ns-uri := namespace-uri($content[1]/*)        	       
            let $ns := util:declare-namespace("",xs:anyURI($ns-uri))
           return util:eval(concat("$content//", $filter)) else $content 
    return templates:process($restricted-content , $model)
};

(:~ extra function for detail-include, to be able to pass a path-param 
(otherwise it would overwrite also other includes )
:)
declare
%templates:wrap
%templates:default("filter", "")
function templates:include-detail($node as node(), $model as map(*), $path-detail as xs:string, $filter as xs:string) {
    let $content := config:resolve($model, $path-detail),
        $log := util:log-app("TRACE",$config:app-name,"templates:include-detail path-detail := "||$path-detail||', $filter := '||$filter)
    let $restricted-content := 
        if ($filter != '' and exists($content)) then 
            (: try to handle namespaces dynamically 
                by switching  to source namespace :)
            let $ns-uri := namespace-uri($content[1]/*),        	       
                $ns := util:declare-namespace("",xs:anyURI($ns-uri)),
                $ret := util:eval(concat("$content//", $filter)),
                $logRet := util:log-app("TRACE",$config:app-name,"templates:include-detail return restricted-content "||serialize($ret))
            return $ret
        else $content 
    return templates:process($restricted-content , $model)
};


declare function templates:surround($node as node(), $model as map(*), $with as xs:string, $at as xs:string?, $using as xs:string?) {
    let $path := concat($config:app-root, "/", $with)
    let $content :=
        if ($using) then
            config:resolve($model, $with)//*[@id = $using]
        else
            config:resolve($model, $with)
    let $merged := templates:process-surround($content, $node, $at)
    return
        templates:process($merged, $model)
};

declare function templates:process-surround($node as node(), $content as node(), $at as xs:string) {
    typeswitch ($node)
        case document-node() return
            for $child in $node/node() return templates:process-surround($child, $content, $at)
        case element() return
            if ($node/@id eq $at) then
                element { node-name($node) } {
                    $node/@*, $content/node()
                }
            else
                element { node-name($node) } {
                    $node/@*, for $child in $node/node() return templates:process-surround($child, $content, $at)
                }
        default return
            $node
};

declare function templates:if-parameter-set($node as node(), $model as map(*), $param as xs:string) as node()* {
    let $param := request:get-parameter($param, ())
    return
        if ($param and string-length($param) gt 0) then
            templates:process($node/node(), $model)
        else
            ()
};

declare function templates:if-parameter-unset($node as node(), $model as item()*, $param as xs:string) as node()* {
    let $param := request:get-parameter($param, ())
    return
        if (not($param) or string-length($param) eq 0) then
(:            $node:)
            templates:process($node/node(), $model)
        else
            ()
};

declare function templates:if-module-missing($node as node(), $model as map(*), $uri as xs:string, $at as xs:string) {
    try {
        util:import-module($uri, "testmod", $at)
    } catch * {
        (: Module was not found: process content :)
        templates:process($node/node(), $model)
    }
};

declare function templates:transform-with-xslt($node as node(), $model as map(*),$path-to-xml as xs:string, $path-to-xsl as xs:string) {
    let $xml := config:resolve($model, $path-to-xml),
        $xsl := config:resolve($model, $path-to-xsl)
    let $result := transform:transform($xml,$xsl,())
    return templates:process($result,$model)
};

declare function templates:display-source($node as node(), $model as map(*), $lang as xs:string?) {
    let $source := replace($node/string(), "^\s*(.*)\s*$", "$1")
    let $context := request:get-context-path()
    let $eXidePath := if (doc-available("/db/eXide/index.html")) then "apps/eXide" else "eXide"
    return
        <div class="code">
            <pre class="brush: {if ($lang) then $lang else 'xquery'}">
            { $source }
            </pre>
            <a class="btn" href="{$context}/{$eXidePath}/index.html?snip={encode-for-uri($source)}" target="eXide"
                title="Opens the code in eXide in new tab or existing tab if it is already open.">Try it</a>
        </div>
};

declare function templates:load-source($node as node(), $model as map(*)) as node()* {
    let $href := $node/@href/string()
    let $context := request:get-context-path()
    let $eXidePath := if (doc-available("/db/eXide/index.html")) then "apps/eXide" else "eXide"
    return
        <a href="{$context}/{$eXidePath}/index.html?open={$config:app-root}/{$href}" target="eXide">{$node/node()}</a>
};

(:~
    Processes input and select form controls, setting their value/selection to
    values found in the request - if present.
 :)
declare function templates:form-control($node as node(), $model as map(*)) as node()* {
    let $log := util:log-app("TRACE",$config:app-name,"templates:form-control $node := "||serialize($node)),
        $ret :=
    typeswitch ($node)
        case element(xhtml:input) return
            let $name := $node/@name,
                $value := request:get-parameter($name, ()),
(:                $log := util:log-app("TRACE",$config:app-name,"templates:form-control $value := "||string-join($value, '; ')),:)
                $retValueSet := 
                if ($value[1]) then
                    element { node-name($node) } {
                        $node/@* except $node/@value,
                        attribute value { $value[1] },
                        $node/node()
                    }
                else $node,
(:                $log := util:log-app("TRACE",$config:app-name,"templates:form-control $retValueSet "||serialize($retValueSet)),:)
                $ret := 
                if ($retValueSet/@type eq 'text') then
                    let $value := $model('config')//@OBJID
                    return element { node-name($retValueSet) } {
                        $retValueSet/@* except $retValueSet/@data-context,
                        attribute data-context { $value },
                        $retValueSet/node()
                    }
                 else $retValueSet(:,
                 $logRet := util:log-app("TRACE",$config:app-name,"templates:form-control return element(input) "||serialize($ret)):)
             return $ret
        case element(xhtml:select) return
            let $value := request:get-parameter($node/@name/string(), ())
            return
                element { node-name($node) } {
                    $node/@* except $node/@class,
                    for $option in $node/option
                    return
                        <option>
                        {
                            $option/@*,
                            if ($option/@value = $value) then
                                attribute selected { "selected" }
                            else
                                (),
                            $option/node()
                        }
                        </option>
                }
        default return
            $node,
     $logRet :=  util:log-app("TRACE",$config:app-name,"templates:form-control return "||substring(serialize($ret), 1, 240))
return $ret
};

declare function templates:error-description($node as node(), $model as map(*)) {
    let $input := request:get-attribute("org.exist.forward.error")
    return
        element { node-name($node) } {
            $node/@*,
            util:parse($input)//message/string()
        }
};

declare function templates:fix-links($node as node(), $model as map(*), $root as xs:string) {
    let $prefix :=
        if ($root eq "context") then
            request:get-context-path()
        else
            concat(request:get-context-path(), request:get-attribute("$exist:prefix"), request:get-attribute("$exist:controller"))
    let $temp := 
        element { node-name($node) } {
            $node/@* except $node/@class,
            attribute class { replace($node/@class, "\s*templates:fix-links[^\s]*", "")},
            for $child in $node/node() return templates:fix-links($child, $prefix)
        }
    return
        templates:process($temp, $model)
};

declare function templates:fix-links($node as node(), $prefix as xs:string) {
    typeswitch ($node)
        case element(a) return
            let $href := $node/@href
            return
                if (starts-with($href, "/")) then
                    <a href="{$prefix}{$href}">
                    { $node/@* except $href, $node/node() }
                    </a>
                else
                    $node
        case element() return
            element { node-name($node) } {
                $node/@*, for $child in $node/node() return templates:fix-links($child, $prefix)
            }
        default return
            $node
};
