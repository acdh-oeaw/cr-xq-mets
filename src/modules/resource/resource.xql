xquery version "3.0";
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

