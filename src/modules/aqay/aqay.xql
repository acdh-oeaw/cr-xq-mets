xquery version "3.0";
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
             <link rel="stylesheet" type="text/css" href="/exist/apps/cr-xq/modules/aqay/scripts/tests.css" />            
            <link rel="stylesheet" type="text/css" href="/exist/apps/cr-xq/modules/shared/scripts/style/cmds-ui.css" />
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

