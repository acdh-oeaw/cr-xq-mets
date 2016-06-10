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
import module namespace crday  = "http://aac.ac.at/content_repository/data-ay" at "crday.xqm";
import module namespace fcs-tests = "http://clarin.eu/fcs/1.0/tests" at  "tests.xqm";

(:~ action-list:
! resources-overview -> moved to resource.xqm
! ay-xml-run
! ay-xml-view

queryset-overview - default
rest-queryset-run
rest-queryset-run-store
rest-queryset-view
! xpath-queryset-* ! TODO (internal query)
:)
let $action := request:get-parameter("action", ""),
(:    $config := doc($config-path),
    $config := repo-utils:config($config-path), :) 
    $project := request:get-parameter("project",""),
    $config := config:config($project),
    $format := request:get-parameter("x-format",'htmlpage'),
    $x-context := request:get-parameter("x-context", $project),

    $result := (: if ($action eq '' or  $action eq 'resources-overview' ) then 
                        crday:display-overview($config, $x-context, $format)
               
               else if (contains ($action, 'ay-xml')) then
                    let $init-path := request:get-parameter("init-path", ""),              
                        $max-depth := request:get-parameter("x-maximumDepth", $crday:defaultMaxDepth)
                     return crday:get-ay-xml($config, $x-context, $init-path, $max-depth, (contains($action, 'run')), 'terms2htmldetail')
               
               else :) 
               if ($action eq '' or contains ($action, 'queryset-overview') or contains ($action, 'rest-queryset')) then
                    let $target := request:get-parameter("target", "0"),
                        $queryset := request:get-parameter("queryset", "0")
                    let $run := if (contains($action,"run")) then fcs-tests:run-testset($target, $queryset, $action, $config) else ()
                    
                    return fcs-tests:display-page($target, $queryset,$action, $config)               
               
               else if (contains ($action, 'xpath-queryset')) then
                    crday:get-query-internal($config, $x-context, (contains($action, 'run')), $format)                    
               (:else if (contains ($op, 'scan-fcs-resource')) then
                    crday:get-fcs-resource-scan($config-path, (contains($op, 'run')), $format)                    
               :)                    
                else 
                    diag:diagnostics("unsupported-operation", $action)
                    
let $opt := util:declare-option("exist:serialize", "media-type=text/html method=xhtml")                    
return <html>
        <head>
            <title>cr-xq/aqay - autoquery/testing suite</title>
            <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
             <link rel="stylesheet" type="text/css" href="modules/aqay/scripts/tests.css" />            
            <link rel="stylesheet" type="text/css" href="modules/shared/scripts/style/cmds-ui.css" />
        </head>
        <body>            
            <div id="header">
             <!--  <ul id="menu">                    
                    <li><a href="collectresults.xql">Results</a></li>
                </ul>--> 
                <h1>cr-xq/aqay - autoquery/testing suite</h1>
                <a href="resource?action=resources-overview">resources </a> <a href="aqay?action=queryset-overview"> querysets</a>
                <span> user: {request:get-attribute("org.exist.demo.login.user")}</span>
            </div>
       <div id="content-wrapper"> {$result }</div>
      </body>
    </html>      

