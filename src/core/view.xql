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

(:~
 : This is the main XQuery which will (by default) be called by controller.xql
 : to process any URI ending with ".html". It receives the HTML from
 : the controller and passes it to the templating system.
 :
 : It also passes the dynamic resolver to the templating system, 
 : that allows it to resolve the module functions
 :)

(:import module namespace resolver="http://exist-db.org/xquery/resolver" at "resolver.xql";:)
import module namespace templates="http://exist-db.org/xquery/templates" at "templates.xql";
import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
   import module namespace app="http://sade/app" at "app.xql";  
   import module namespace fcs="http://sade/fcs" at "../modules/fcs/fcs-sade.xqm";
import module namespace projectAdmin="http://aac.ac.at/content_repository/projectAdmin" at "../modules/projectAdmin/projectAdmin.xqm";

declare option exist:serialize "method=html5 media-type=text/html";

let $lookup :=function($functionName as xs:string, $arity as xs:int) {
    try {
        function-lookup(xs:QName($functionName), $arity)
    } catch * {
        ()  
    }
} 
(: 
 : The HTML is passed in the request from the controller. 
 : (the controller cares for fetching the correct template-file based on project context)
 : Run it through the templating system and return the result.
 :)
 
let $template := request:get-data(),
    $project := session:set-attribute("project-pid", request:get-parameter("project", ""))
    
return templates:apply($template, $lookup, ())