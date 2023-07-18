xquery version "3.0";
(:~ This module provides methods to transform CQL query to XPath   
: @see http://clarin.eu/fcs 
: @author Matej Durco
: @since 2012-03-01
: @version 1.1 
:)
module namespace cql = "http://exist-db.org/xquery/cql";

import module namespace cqlparser = "http://exist-db.org/xquery/cqlparser";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at "../../core/repo-utils.xqm";
import module namespace diag =  "http://www.loc.gov/zing/srw/diagnostic/" at "../diagnostics/diagnostics.xqm";
import module namespace index = "http://aac.ac.at/content_repository/index" at "../../core/index.xqm";

(:declare variable $cql:transform-doc := doc("XCQL2Xpath.xsl");:)
declare variable $cql:transform-doc := doc(concat(system:get-module-load-path(),"/XCQL2Xpath.xsl"));
declare variable $cql:log := util:log("INFO",$cql:transform-doc);

(:~ use the extension module CQLParser (using cql-java library)
to parse the expression and return the xml version  of the parse-tree
or a diagnostic, on parsing error
: @param $cql-expression a query string in CQL-syntax
: @return XCQL - a XML version of the parse-tree (or diagnostics) 
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
This happens in two steps: 
: <ol>
: <li>1. parsing into XCQL (XML-representation of the parsed query</li>
: <li>2. and process the XCQL recursively with xquery (as opposed to old solution, with the XCQL2Xpath.xsl-stylesheet)</li>
: </ol>
: @param $cql-expression a query string in CQL-syntax
: @param $context identifies the context-project (providing the custom index-mappings, needed in the second step) 
: @returns xpath-string, or if not a string, whatever came from the parsing (if not a string, it must be a diagnostic) 
:)
declare function cql:cql-to-xpath($cql-expression as xs:string, $context)  as item()* {
    let $xcql := cql:cql-to-xcql($cql-expression)
(:    return transform:transform ($xcql, $cql:transform-doc, <parameters><param name="mappings-file" value="{repo-utils:config-value('mappings')}" /></parameters>):)
    return 
        if (not($xcql instance of element(diagnostics))) 
            then cql:xcql-to-xpath($xcql, $context)            
            else $xcql
};

(:~ translate a query in CQL-syntax to a corresponding XPath 
a variant expecting map already as parameter  ($context parameter is ignored)
:)
declare function cql:cql-to-xpath($cql-expression as xs:string, $context, $map)  as item()* {
    let $xcql := cql:cql-to-xcql($cql-expression)
(:    return transform:transform ($xcql, $cql:transform-doc, <parameters><param name="mappings-file" value="{repo-utils:config-value('mappings')}" /></parameters>):)
    return  
        if (not($xcql instance of element(diagnostics))) 
            then cql:xcql-to-xpath($xcql, $context,$map)            
            else $xcql
};

(:~ starting point of the processing of the parsing tree into an xpath string
requires $context to be able to translate the abstract indexes into xpaths
: @param $xcql the parsed query as XCQL
: @param $context string that identifies the context-project (providing the custom index-mappings) 
: @returns xpath corresponding to the abstract cql query as string
:)
declare function cql:xcql-to-xpath ($xcql as node(), $context as xs:string)  as xs:string {
    let $map := index:map($context)
    return cql:xcql-to-xpath($xcql,$context,$map)    
};

declare function cql:xcql-to-xpath ($xcql as node(), $context as xs:string, $map )  as xs:string {
        
    let $xpath := 
        if ($xcql instance of document-node())
        then cql:process-xcql($xcql/*, $map)
        else cql:process-xcql($xcql, $map)
    return string-join($xpath,'') 
};

(:~ the default recursive processor of the parsed query expects map with indexes defined
: @param $xcql the parsed query as XCQL
: @param $map map element as defined in the project-configuration 
: @returns xpath corresponding to the abstract cql query as string
:)

declare function cql:process-xcql($xcql as element(),$map) as xs:string {
    let $return := 
        typeswitch ($xcql)
            case text() return normalize-space($xcql)
            case element(triple) return cql:boolean($xcql/boolean/value, $xcql/boolean/modifiers, $xcql/leftOperand, $xcql/rightOperand, $map)
            case element(searchClause) return cql:searchClause($xcql, $map)
            case element(boolean) return cql:boolean($xcql/value, $xcql/modifiers, $xcql/following-sibling::leftOperand, $xcql/following-sibling::rightOperand, $map)
            default return cql:process-xcql($xcql/*, $map)
    return $return
};
(:
declare function cql:process-xcql-default($node as node(), $map) as item()* {
  cql:process-xcql($node/node(), $map))
  
 };:) 
 
declare function cql:boolean($value as element(value), $leftOperand as element(leftOperand), $rightOperand as element(rightOperand),$map) as xs:string {
    cql:boolean($value,(),$leftOperand,$rightOperand,$map) 
};

declare function cql:boolean($value as element(value), $modifiers as element(modifiers)?, $leftOperand as element(leftOperand), $rightOperand as element(rightOperand),$map) as xs:string {
    let $parts :=
        switch($value)
            case "OR" return cql:union($leftOperand, $rightOperand, $map)   
            case "NOT" return cql:except($leftOperand, $rightOperand, $map)
            case "prox" return cql:prox($leftOperand, $rightOperand, $modifiers, $map)
            (: default operator AND :)
            default return cql:intersect($leftOperand, $rightOperand, $map) 
                (:"("||string-join(
                        for $i in $boolean/following-sibling::*/searchClause
                        return cql:searchClause($i,$map),
                        ' intersect '
                    )||")":)    return concat('/',string-join($parts,""))
 };

declare function cql:searchClause($clause as element(searchClause), $map) {
    let $index-key := $clause//index/text(),        
        $index := index:index-from-map($index-key ,$map),
        $index-type := ($index/xs:string(@type),'')[1],
        $index-case := ($index/xs:string(@case),'')[1],
        $index-xpath := index:index-as-xpath-from-map($index-key,$map,''),        
        $match-on := index:index-as-xpath-from-map($index-key,$map,'match-only'),         
        $relation := $clause/relation/value/text(),
        (: exact, starts-with, contains, ends-with :)
        $term := if ($index-case='yes') then $clause/term else lower-case($clause/term), 
        $sanitized-term := cql:sanitize-term($term),
(:$predicate := ''        :)
        $predicate := switch (true())
                        case ($sanitized-term eq 'false') return 'not('||$match-on||')'
                        case ($sanitized-term eq 'true') return $match-on
                        case ($index-type eq $index:INDEX_TYPE_FT) return
                                if (contains($term,'*')) then 
                                            'ft:query('||$match-on||',<query><wildcard>'||$term||'</wildcard></query>)'
                                        else
                                            'ft:query('||$match-on||',<query><phrase>'||$term||'</phrase></query>)'
(:                                    case ('exact') return 'ft:query('||$match-on||',"'||$sanitized-term||'")':)
(:                                    case ('starts-with') return 'ft:query('||$match-on||',"'||$sanitized-term||'*")':)
                                    (:case ('starts-with') return 'ft:query('||$match-on||',<query><wildcard>'||$sanitized-term||'*</wildcard></query>)'
                                    case ('ends-with') return 'ft:query('||$match-on||',<query><wildcard>*'||$sanitized-term||'</wildcard></query>)'
                                    case ('contains') return 'ft:query('||$match-on||',<query><wildcard>*'||$sanitized-term||'*</wildcard></query>)'
                                    case ('starts-ends-with') return 'ft:query('||$match-on||',<query><wildcard>'||$sanitized-term||'</wildcard></query>)'
                                    default return 'ft:query('||$match-on||',<query><phrase>'||$sanitized-term||'</phrase></query>)':)
(:                                    default return 'ft:query('||$match-on||',"'||$sanitized-term||'")':)
                        default return
                                let $match-mode := if (ends-with($term,'*')) then     
                                                        if (starts-with($term,'*')) then 'contains'
                                                        else 'starts-with'
                                                    else if (starts-with($term,'*')) then 'ends-with'
                                                    else if (contains($term,'*')) then 'starts-ends-with'
                                                        else 'exact'
                               return switch ($match-mode) 
                                    case ('exact') return $match-on||"='"||$sanitized-term||"'"
                                    case ('starts-with') return 'starts-with('||$match-on||",'"||$sanitized-term||"')"
                                    case ('ends-with') return 'ends-with('||$match-on||",'"||$sanitized-term||"')"
                                    case ('contains') return 'contains('||$match-on||",'"||$sanitized-term||"')"
                                    case ('starts-ends-with') return 
                                            let $starts-with := substring-before($sanitized-term,'*')
                                            let $ends-with := substring-after($sanitized-term,'*')
                                            return 'starts-with('||$match-on||",'"||$starts-with||"') and ends-with("||$match-on||",'"||$ends-with||"')"
                                    default return $match-on||"='"||$sanitized-term||"'"                        
                        
    return $index-xpath||'['||$predicate||']'

};
(:
declare function cql:predicate($index-type as xs:string?, $relation as xs:string, $term as xs:string) {
    
};:)


declare function cql:predicate($clause,$map) as xs:string {
    let $clause := cql:searchClause($clause,$map)
    return 
        if (starts-with($clause,'('))
        then "["||$clause||"]"
        else "[self::"||$clause||"]"
};

declare function cql:intersect($leftOperand as element(leftOperand), $rightOperand as element(rightOperand), $map) as xs:string {
    let $operands := (cql:process-xcql($leftOperand, $map), cql:process-xcql($rightOperand, $map))
    let $return := "("||string-join($operands,' intersect ')||")"
    return $return
};

declare function cql:except($leftOperand as element(leftOperand), $rightOperand as element(rightOperand), $map) as xs:string {
    let $operands := (cql:process-xcql($leftOperand,$map),cql:process-xcql($rightOperand,$map))
    return "("||string-join($operands,' except ')||")"
};

declare function cql:union($leftOperand as element(leftOperand), $rightOperand as element(rightOperand), $map) as xs:string {
    let $operands := (cql:process-xcql($leftOperand,$map),cql:process-xcql($rightOperand,$map))
    return "("||string-join($operands,' union ')||")"
};

declare function cql:prox($leftOperand as element(leftOperand), $rightOperand as element(rightOperand), $modifiers as element(modifiers)?, $map) as xs:string {
    let $operands := (cql:process-xcql($leftOperand,$map),cql:process-xcql($rightOperand,$map)),
        $distance := ($modifiers/modifier[type='distance']/value),
        $comparison := ($modifiers/modifier[type='distance']/comparison),
        $proximityExpPrev := 
            (:if ($comparison = "=") 
            then :)"@cr:w = (xs:integer($hit/@cr:w)+1 to xs:integer($hit/@cr:w)+"||$distance||")"
            (:else "@cr:w "||$comparison||" $hit/@cr:w":),
        $proximityExpFoll := 
            (:if ($comparison = "=") 
            then :)"@cr:w = (xs:integer($hit/@cr:w)-"||$distance||" to xs:integer($hit/@cr:w)-1)"
            (:else "@cr:w "||$comparison||" $hit/@cr:w":)
    return 
        "for $hit in $data//("||$operands[1]||")
            let $prev := root($hit)//*["||$proximityExpPrev||"],
                $foll := root($hit)//*["||$proximityExpFoll||"],
                $window := ($prev,$foll)
            return 
                if ($window/self::"||$operands[2]||")
                then ($prev,$hit,$foll)
                else ()" (: " :)
};
        

(:~ remove quotes :)
declare function cql:sanitize-term($term) {
 (: remove leading and/or trailing stars :)
 replace($term,'(\*$|^\*)','')
             (:switch (true())
                case (starts-with($term, '''')) return translate($term,'''','')
                case (starts-with($term, '%22')) return translate($term,'%22','')
                default return $term:)
};


(:~ DEPRECATED
translate a query in CQL-syntax to a corresponding XPath 
: <ol>
: <li>1. parsing into XCQL (XML-representation of the parsed query</li>
: <li>2. and transform via XCQL2Xpath.xsl-stylesheet</li>
: </ol>
: @param $cql-expression a query string in CQL-syntax
: @param $context identifies the context-project (providing the custom index-mappings) 
: @returns xpath-string, or if not a string, whatever came from the parsing (if not a string, it must be a diagnostic) 
:)
declare function cql:cql2xpath_old($cql-expression as xs:string, $context as xs:string)  as item() {
    let $xcql := cql:cql-to-xcql($cql-expression)
(:    return transform:transform ($xcql, $cql:transform-doc, <parameters><param name="mappings-file" value="{repo-utils:config-value('mappings')}" /></parameters>):)
    return 
        if (not($xcql instance of element(diagnostics))) 
        then
            let $parameters:=<parameters><param name="x-context" value="{$x-context}" /></parameters>
            return transform:transform ($xcql, $cql:transform-doc, $parameters)
        else $xcql
};


(:~ DEPRECATED - works with XSL transformation 
a version that accepts mappings-element(s) as param
: @param $cql-expression a query string in CQL-syntax
: @param $context identifies the context-project (providing the custom index-mappings, needed in the second step) 
: @returns xpath corresponding to the abstract cql query as string, or if not a string, whatever came from the parsing (if not a string, it must be a diagnostic) 
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
