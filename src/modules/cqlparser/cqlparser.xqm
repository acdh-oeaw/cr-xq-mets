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

(:~ This module provides methods to transform CQL query to XPath   
: @see http://clarin.eu/fcs 
: @author Matej Durco
: @since 2012-03-01
: @version 1.1 
:)
module namespace cql = "http://exist-db.org/xquery/cql";

import module namespace cqlparser = "http://exist-db.org/xquery/cqlparser";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at  "../../core/repo-utils.xqm";
import module namespace diag =  "http://www.loc.gov/zing/srw/diagnostic/" at  "../../modules/diagnostics/diagnostics.xqm";

(:declare variable $cql:transform-doc := doc("XCQL2Xpath.xsl");:)
declare variable $cql:transform-doc := doc(concat(system:get-module-load-path(),"/XCQL2Xpath.xsl"));
declare variable $cql:log := util:log("INFO",$cql:transform-doc);
(:~ use the extension module CQLParser (using cql-java library)
to parse the expression and return the xml version  of the parse-tree
or a diagnostic, on parsing error
:)
declare function cql:cql-to-xcql($cql-expression as xs:string) {
    try {
         (: util:parse(cqlparser:parse-cql($cql-expression, "XCQL")) :)
         cqlparser:parse-cql($cql-expression, "XCQL")
    }
       catch err:XPTY0004 
    {
      diag:diagnostics("query-syntax-error", ($err:code , $err:description, $err:value))
    } 
    catch *
    { 
      diag:diagnostics("query-syntax-error", $cql-expression)
    }
};

(:~ translate a query in CQL-syntax to a corresponding XPath 
: <ol>
: <li>1. parsing into XCQL (XML-representation of the parsed query</li>
: <li>2. and transform via XCQL2Xpath.xsl-stylesheet</li>
: </ol>
: @returns xpath-string, or if not a string, whatever came from the parsing (if not a string, it must be a diagnostic) 
:)
declare function cql:cql2xpath($cql-expression as xs:string, $x-context as xs:string)  as item() {
    let $xcql := cql:cql-to-xcql($cql-expression)
(:    return transform:transform ($xcql, $cql:transform-doc, <parameters><param name="mappings-file" value="{repo-utils:config-value('mappings')}" /></parameters>):)
    return 
        if (not($xcql instance of element(diagnostics))) 
        then
            let $parameters:=<parameters><param name="x-context" value="{$x-context}" /></parameters>
            return transform:transform ($xcql, $cql:transform-doc, $parameters)
        else $xcql
};

(:~ a version that accepts mappings-element(s) as param
:)
declare function cql:cql2xpath($cql-expression as xs:string, $x-context as xs:string, $mappings as element(map)*)  as item() {
    let $xcql :=    if (exists($mappings)) 
                    then cql:cql-to-xcql($cql-expression)
                    else diag:diagnostics("mappings-missing", $mappings)
    return 
        if ($xcql[1] instance of element(diagnostics))
        then $xcql
        else 
            let $input:=        <wrapper>
                                    <query>{$xcql}</query>
                                    <mappings>{$mappings}</mappings>
                                </wrapper> 
            let $parameters:=   <parameters>
                                    <param name="x-context" value="{$x-context}"/>
                                </parameters> 
            return transform:transform($input, $cql:transform-doc,$parameters)
};

declare function cql:xcql2xpath ($xcql as node(), $x-context as xs:string)  as xs:string {
    
(:    return transform:transform ($xcql, $cql:transform-doc, <parameters><param name="mappings-file" value="{repo-utils:config-value('mappings')}" /></parameters>):)    
transform:transform ($xcql, $cql:transform-doc, <parameters><param name="x-context" value="{$x-context}" /></parameters> )
    
};

