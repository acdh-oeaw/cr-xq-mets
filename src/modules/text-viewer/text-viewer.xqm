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

module namespace text-viewer = "http://sade/text-viewer" ;
declare namespace templates="http://exist-db.org/xquery/templates";
declare namespace sade = "http://sade" ;
declare namespace tei = "http://www.tei-c.org/ns/1.0" ;

declare %templates:default("position", 1) 
    function text-viewer:showText($node as node(), $model as map(*), $position as xs:integer) as element() {    
    
    let $divID := $node/xs:string(@id)
    let $config := local:readConfig()("config")//*[@name="text-viewer"][@container=$divID]
    
    (: Projektkonfiguration auslesen :)
    let $collection_path := $config/param[@name="collection_path"]/xs:string(@value)
    let $xpath := $config/param[@name="xpath"]/xs:string(@value)
    let $xslt_path := $config/param[@name="xslt_path"]/xs:string(@value)
    
    (: Geamtanzahl der referenzierten Elemente feststellen :)
    let $totalNr := util:eval(concat("count(collection('",$collection_path,"')",$xpath,")"))
    
    (: XML-Fragment aus DB holen und transformieren :)
    let $xsl := if ($xslt_path = () or $xslt_path = "" or $xslt_path = "tei") then doc("resources/tei/stylesheet/xhtml2/tei.xsl")
                else doc($xslt_path)
    let $fragment := util:eval(concat("collection('",$collection_path,"')",$xpath,"[",$position,"]"))    
    let $html := transform:transform($fragment, $xsl, ())    
    
    (: Navigation bauen :)
    let $navbar := text-viewer:getNavBar($position, "", $totalNr)
    
    return <div>Brieftext: {$navbar, $html}</div>
};


declare function text-viewer:getNavBar($position as xs:string, $script_url as xs:string, $last as xs:string){
    let $next := if ($position = "last()" or $position = $last) then $position else xs:integer($position)+1
    let $prev := if ($position = "1") then $position else if ($position = "last()") then "last()-1" else xs:integer($position)-1

    return
    <div class="btn-toolbar">
        <div class="btn-group">         
           <a class="btn" href="{$script_url}?position=1"><i class="icon-fast-backward">|-</i></a>
           <a class="btn" href="{$script_url}?position={$prev}"><i class="icon-chevron-left">-</i></a>
           <a class="btn" href="{$script_url}?position={$next}"><i class="icon-chevron-right">+</i></a>
           <a class="btn" href="{$script_url}?position={$last}"><i class="icon-fast-forward">+|</i></a>
        </div>
    </div>
};


declare function local:readConfig() as map(*) {

    let $config := doc("/db/apps/sade/projects/neu1/config.xml")
    
    return map { "config" := $config }

};