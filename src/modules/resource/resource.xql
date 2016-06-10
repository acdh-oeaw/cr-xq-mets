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

import module namespace request="http://exist-db.org/xquery/request";
import module namespace config="http://exist-db.org/xquery/apps/config" at "../../core/config.xqm";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at  "../../core/repo-utils.xqm";
import module namespace diag =  "http://www.loc.gov/zing/srw/diagnostic/" at  "../diagnostics/diagnostics.xqm";
import module namespace crday  = "http://aac.ac.at/content_repository/data-ay" at "../aqay/crday.xqm";
import module namespace resource = "http://cr-xq/resource" at "resource.xqm";
(:import module namespace fcs-tests = "http://clarin.eu/fcs/1.0/tests" at  "tests.xqm";:)

(:~ action-list:
resources-overview - default
ay-xml-run
ay-xml-view
:)

let $action := request:get-parameter("action", ""),
(:    $config := doc($config-path),
    $config := repo-utils:config($config-path), :) 
    $project := request:get-parameter("project",""),
    $config := config:config($project),
    $x-context := request:get-parameter("x-context", $project),

    $result := if ($action eq '' or  $action eq 'resources-overview' ) then
                    let     $format := request:get-parameter("x-format",'htmlpage')
                        return resource:display-overview($config, $x-context, $format)
               
               else if (contains ($action, 'ay-xml')) then
                    let $format := request:get-parameter("x-format",'terms2htmldetail'),
                        $init-path := request:get-parameter("init-path", ""),              
                        $max-depth := request:get-parameter("x-maximumDepth", $crday:defaultMaxDepth)
                     return crday:get-ay-xml($config, $x-context, $init-path, $max-depth, (contains($action, 'run')), $format)
                             
                else 
                    diag:diagnostics("unsupported-operation", $action)
                    
let $opt := util:declare-option("exist:serialize", "media-type=text/html method=xhtml")                    
return <html>
        <head>
            <title>Project overview</title>
            <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
            <link rel="stylesheet" type="text/css" href="/exist/apps/cr-xq/modules/shared/scripts/style/cmds-ui.css" />
        </head>
        <body>            
            <div id="header">
             <!--  <ul id="menu">                    
                    <li><a href="collectresults.xql">Results</a></li>
                </ul>--> 
                <h1>Project data overview</h1>
                <a href="resource?action=resources-overview">resources </a> <a href="aqay?action=queryset-overview"> querysets</a>
            </div>
       <div id="content-wrapper"> {$result }</div>
      </body>
    </html>      

