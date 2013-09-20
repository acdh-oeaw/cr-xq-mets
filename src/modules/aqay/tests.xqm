xquery version "3.0";
module namespace fcs-tests  = "http://clarin.eu/fcs/1.0/tests";

import module namespace httpclient = "http://exist-db.org/xquery/httpclient";
import module namespace t="http://exist-db.org/xquery/testing";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at  "../../core/repo-utils.xqm";
import module namespace xqjson="http://xqilla.sourceforge.net/lib/xqjson";

declare namespace zr="http://explain.z3950.org/dtd/2.0/";
declare namespace sru = "http://www.loc.gov/zing/srw/";
declare namespace fcs = "http://clarin.eu/fcs/1.0";
declare namespace diag = "http://www.loc.gov/zing/srw/diagnostic/";
declare namespace ds = "http://aac.ac.at/corpus_shell/dataset";
declare namespace xhtml="http://www.w3.org/1999/xhtml";


(: sample input: 
 :)
(:declare variable $fcs-tests:config := doc("config.xml");
declare variable $fcs-tests:cr-config := repo-utils:config("/db/apps/cr-xq/modules/fcs/config.xml");:)
(:declare variable $fcs-tests:run-config := "run-config.xml";:)
(:declare variable $fcs-tests:testsets-coll := "/db/cr/modules/testing/testsets/";
declare variable $fcs-tests:results-coll := "/db/cr/modules/testing/results/";
:)
declare variable $fcs-tests:href-prefix := "tests.xql";

(:~ this function is accessed by the testing-code to get configuration-options from the run-config :)
declare function fcs-tests:config-value($config, $type, $key as xs:string?) as xs:string* {

(:    let $config := doc(concat($fcs-tests:testsets-coll, $fcs-tests:run-config))/config:)
(:                if ($type eq "queryset") then  xs:string($config//queryset[xs:string(@key)=$key]/
                        else :)
                        if ($type eq "action") then repo-utils:config-value($config, 'action')
                        else $config//target[xs:string(@key)=$key]/xs:string(@url)
};
(:
declare function fcs-tests:config-key($key as xs:string) as xs:string* {
            let $config := doc(concat($fcs-tests:testsets-coll, $fcs-tests:run-config))/config
                return if ($key eq "testset") then  xs:string($config//testset/@key)
                        else xs:string($config//target/@key)
};
:)

declare function fcs-tests:get-result-paths($target  as xs:string, $queryset as xs:string, $config) as xs:string* {
    let $store-path := repo-utils:config-value($config, "store.path") 
        return (concat($store-path, $target, "/"), concat($queryset, ".xml"))
};

declare function fcs-tests:get-result-path($target  as xs:string, $queryset as xs:string, $config) as xs:string* {
        string-join(fcs-tests:get-result-paths($target , $queryset, $config ), "" )
};

declare function fcs-tests:get-result($target  as xs:string, $queryset as xs:string, $config) as item() {
  let $result-path := fcs-tests:get-result-path($target, $queryset, $config)
   let $result := if ($target = '' or $queryset = '') then () 
                            else if (doc-available($result-path)) then
                            doc($result-path)                            
                        else <diagnostics><diagnostic key="result-unavailable">result unavailable: {$result-path}</diagnostic>
                                <diagnostic>{fcs-tests:get-queryset($queryset, $config)}</diagnostic>
                              </diagnostics>
 return $result
};

(:~ try to get the testset-file based on the testset-key
@returns testset-file if available, otherwise empty result
:)
declare function fcs-tests:get-queryset($queryset as xs:string, $config) as item()* {
    let $queryset-basepath := repo-utils:config-value($config, "queryset.path") 
    let $queryset-path := concat($queryset-basepath, $queryset, ".xml")
    return if (doc-available($queryset-path)) then                        
                    doc($queryset-path)
                  else 
                  <diagnostic>unknown testset: {$queryset}</diagnostic>
};


(:~ main function governing the execution of the tests

Generates a run-config out of the full config based on the parameters.
@param $target-key identifying key of the target  as set in the config, or 'all' for all targets in th config
@param $queryset-key identifying key of the testset as set in the config (that also has to be the name of the testset-file)
@param $action run or run-store; with `run-store` also the fetched individual results stored, the final result is stored anyway
:)
declare function fcs-tests:run-testset($target-key as xs:string, $queryset-key as xs:string, $action as xs:string, $config) as item()* {
    
    (: preparing a configuration for given run, based on the parameters :)
   (: let $run-config := <config>{($config//target[xs:string(@key) = $target],
                                $config//testset[xs:string(@key) = $queryset-key],
                                <property key="action">{$action}</property>)}</config>
    :)
    (: for now put the whole config plus the action-param
        perhaps this could be cleaned up :) 
    let $run-config := <config>{($config, <property key="action">{$action}</property>)}</config>
(:    let $run-config := ($config, <property key="operation">{$action}</property>):)
    
    
    (: TODO: eliminate the run-config  - but probably needed for t:run-testSet :)
(:    let $queryset-path := repo-utils:config-value($config, "queryset.path")    
    let $store := repo-utils:store($queryset-path, $fcs-tests:run-config, $run-config, true()) :)
    
(:    return $run-config:)

    let $targets := if ($target-key='all') then fcs-tests:get-target-keys($config) else $target-key 
    for $target in $targets 
        
        let $querysets := if ($queryset-key='all') then fcs-tests:get-querysets($config, $target) else fcs-tests:get-queryset($queryset-key, $config) 
    
        for $queryset in $querysets
(:            let $queryset := fcs-tests:get-queryset($queryset-key, $config):)
            let $start-time := util:system-dateTime()
            let $result := if (exists($queryset)) then                        
                                    let $tests := $queryset//TestSet
                                    (: distinguish the testset, that the testing-module can process
                                       and the home-made test-doc, that tests URLs :)
                                    return if (exists($tests)) then
                                                t:run-testSet($tests, ())
                                             else
                                                fcs-tests:test-rest($queryset, $target, $run-config)
                               else
                                   $queryset 
            let $end-time := util:system-dateTime()
            let $test-wrap := <testrun duration="{$end-time - $start-time}" on="{fn:current-dateTime()}" >{$result}</testrun>
            let $store-result := fcs-tests:store-result($target, $queryset-key, $test-wrap, $config)
            (:for $test in $tests/tests/test return fcs-tests:run-test($test):)
            return $store-result
        
};

(:~ process a test-doc (target is expected to be set in the config)
:)
declare function fcs-tests:test-rest($test-doc as node(), $target, $config) as item()* {

    let $result := local:dispatch($test-doc, $target, $config)
    
(:
let $targets := if (exists($test/target)) then $test/target else $test/preceding-sibling::target
let $requests := for $target in $targets return concat($target, $test/request/text())
let $data := for $request in $requests return
                <request href="{$request}" id
                httpclient:get(xs:anyURI($request), false(), () )

let $check := for $condition in $test/condition 
                        let $expr :=concat("($data/", $condition/text(), " eq ", xs:string($condition/@result), ")")
                         return <check expr="{$expr}" >{util:eval($expr)} </check>
return <test><id>{$test/id}</id><label>{$test/label}</label>
            <requests>{$requests}</requests>
            <results>{$check}</results>
        </test>
:)
return $result

};

(:~ This function takes the children of the node and passes them
   back into the typeswitch function. :)
declare function local:passthru($x as node(), $target, $config) as node()*
{
for $z in $x/node() return local:dispatch($z, $target, $config)
};

(:~ This is the recursive typeswitch function, to traverse the testset-document :)
declare function local:dispatch($x as node(), $target, $config) as node()*
{
typeswitch ($x)
  case text() return $x
  case element (test) return element div {$x/@*[not(name()=('username','password'))], attribute class {"test"}, fcs-tests:process-test($x, $target, $config)}  
  case element() return element {$x/name()} {$x/@*, local:passthru($x, $target, $config)}  
  default return local:passthru($x, $target, $config)
};

(:~ executes a rest-test. 

if the test references a list, iterate over the items of the list and run a request for each
(substituting the values from the list in the request)
the substituted request is passed to fcs-tests:process-request() for actual execution

expects:
   <div class="test" id="search-haus">
      <a class="request" href="?operation=searchRetrieve&amp;query=Haus">search: Haus</a>
      <span class="check xpath">//sru:numberOfRecords</span>
   </div>
   
@returns the (sequence of) requested-url as link, results of the xpath-evaluations as a div-list and any diagnostics
:)     
declare function fcs-tests:process-test($test as node(), $target-key, $config) as item()* {
    
    let $a := $test/a,
        $test-id := xs:string($test/@id),
        $test-list := xs:string($test/@list),
        $list-doc := if (doc-available($test-list)) then doc($test-list) else (),
        $target-uri := fcs-tests:config-value($config, "target", $target-key), 
(:        $target-key := fcs-tests:config-key("target"),:)
        $action := fcs-tests:config-value($config, "action", ())


    return if (empty($list-doc)) then 
                let $request := concat($target-uri, xs:string($a/@href))                
                return fcs-tests:process-request ($test, $request, $a/text(), $target-key, $test-id, $action, $config)
            else 
            (: if we have a list, iterate over the items of the list and run a request for each :)
            
                for $i at $c in $list-doc/*/*
                  let $request := concat($target-uri,  fcs-tests:subst(xs:string($a/@href), $i)),
                      $i-id := if ($i/@id) then xs:string($i/@id) else $c,
                      $request-id := concat($test-id, $i-id),
                      $a-text := fcs-tests:subst(xs:string($a/text()), $i)
                  return fcs-tests:process-request ($test, $request, $a-text, $target-key, $request-id, $action, $config)
};

(:~ executes one URL-request. 

Issues one http-call to the target-url in the a@href-attribute, stores the incoming result (only if $action='run-store') and evaluates the associated xpaths  

allows for simple authentication mechanism, via http-header.
also tried to send as params which the the new exist auth seemed to accept, 
but it did not work out, still got redirect to login

@param $test div[@class='test']-element
@param $request resolved (substituted) link
@param $a-text resolved (substituted) text for the link
@param $target-key identifier of the target (will be used as directory, when storing the result)
@param $request-id identifier of the request (will be used as the name of the file, when storing the result)

@returns the requested-url as link, results of the xpath-evaluations as a div-list and any diagnostics
:) 
declare function fcs-tests:process-request($test, $request as xs:string, $a-text as xs:string, $target-key as xs:string, $request-id as xs:string, $action as xs:string, $config) as item()* { 
            
(:    let $result-link := $config//property[xs:string(@key)='result-link']            :)
      let $result-link := repo-utils:config-value($config,'result-link')

    let $username := if ($test/@username) then $test/xs:string(@username)  else ""  
    let $password := if ($test/@password) then $test/xs:string(@password) else "" 
    
(:  not working   let $auth-param := if ($test/@auth-type) then concat('&amp;user=', $username, '&amp;password=', $password) else "" :)

    let $headers := if ($username='') then () else                            
                        let $auth := concat("Basic ", util:base64-encode(concat($username, ':', $password)))
                        return <headers><header name="Authorization" value="{$auth}"/></headers>


let $a-processed := (if (contains($result-link,'original')) then <a href="{$request}">{$a-text}</a> else (),
                         if (contains($result-link,'rewrite')) then
(:                                               let $cache-uri-prefix := $config//property[xs:string(@key)='result-uri-prefix']:)
                                               let $cache-uri-prefix :=  repo-utils:config-value($config,'result-uri-prefix')
                                               let $req-rwr := concat($cache-uri-prefix, $request-id, ".xml")                                               
                                               return <a href="{$req-rwr}">{$a-text}</a>
                                               else (),
                        if (contains($result-link,'cache')) then
                                        (:let $cache-uri := if (exists($store)):) 
                                            <a href="{concat('results/', $target-key, "/", $request-id, ".xml")}" > cache </a> 
                                          else ()
                       ) 
                            
    let $result-data-raw := httpclient:get(xs:anyURI($request), false(), $headers )
    
                           
(: if json data - convert to xml - and add the converted xml to the result  :)
    let $json := if ($result-data-raw//httpclient:body/xs:string(@encoding)="Base64Encoded") then
                        util:base64-decode($result-data-raw//httpclient:body/text())
                     else 
                        $result-data-raw//httpclient:body/text()
              
                    let $json-xml := if ($json) then
                            try {
                                    xqjson:parse-json($json) 
                           }
                       catch *         
                        {
                        diag:diagnostics('general-error', string-join(($err:code , $err:description, $err:value), '; '))
                        }
                            else ()
                    

    let $result-data := if ($result-data-raw//httpclient:headers/httpclient:header[xs:string(@name)="Content-Type"]
                                  /contains(xs:string(@value),"application/json")) then                                    
                (:              let $json := if ($result-data-raw//httpclient:body/xs:string(@encoding)="Base64Encoded") then
                                                util:base64-decode($result-data-raw//httpclient:body/text())
                                             else 
                                                $result-data-raw//httpclient:body/text()
                               let $json-xml := $json (\:xqjson:parse-json($json):\):)
   
                               <httpclient:response>
                                        {($result-data-raw/@statusCode,
                                          $result-data-raw/httpclient:headers,
                                          $result-data-raw/httpclient:body,
                                          <httpclient:body  mimetype="application/xml; charset=UTF-8">{$json-xml}</httpclient:body>
                                          )}</httpclient:response>
                        else if (repo-utils:config-value($config, 'store.flag') eq 'data-only') then                         
                            $result-data-raw//httpclient:body/*
                        else $result-data-raw                    
                            
(:        let $store := if ($action eq 'run-store') then fcs-tests:store-result($target-key, $request-id, $result-data//httpclient:body/*) else ()
rather store everything including the envelope: :)
let $store := if (contains($action,'run-store')) then fcs-tests:store-result($target-key, $request-id, $result-data, $config) else ()


(:    <a href="{fcs-tests:get-result-paths($target-key, $request-id) else ():)
(:    let $cache-uri := if (exists($store)) then <a href="{concat(repo-utils:base-url(()), document-uri($store))}" > cache </a> else ():)
    (: evaluate all xpaths defined for given request :) 
    let $check := for $xpath in $test/xpath 
                    let $evald := util:eval($xpath/text())
                    
                    return 
                    <div><span class="key">{if (exists($xpath/@key)) then xs:string($xpath/@key) else $xpath/text()}:</span> 
                          <span class="value {if ($evald instance of xs:boolean) then xs:string($evald) else '' }">{$evald}</span>
                    </div>
                    
     (: checking extra for diagnostics :)
     let $http-status := $result-data//xs:string(@statusCode)     
     let $diag := ($result-data//diag:diagnostic, $result-data//exception, 
                if ($http-status ne '200') then <http-status>{$http-status}</http-status> else ())      
      let $wrapped-diag := if (exists($diag)) then 
                <diagnostics type="{string-join($diag/name(),',')}" >{$diag}</diagnostics> else ()

return ($a-processed, $check, $wrapped-diag)
(:                , $cache-uri:)
};


declare function fcs-tests:store-result($target as xs:string, $queryset as xs:string, $result as node(), $config) as item()* { 
    fcs-tests:store-result ($target, $queryset, "", $result, $config)
};


(:~ stores the result of a testset 
@returns reference to the stored document (as the underlying function repo-utils:store())
:)
declare function fcs-tests:store-result($target as xs:string, $queryset as xs:string, $test as xs:string, $result as node(), $config) as item()* {
(: create collection for results for one target :)
    let $store-path := repo-utils:config-value($config, "store.path")
    
   let $create-coll := if (not(xmldb:collection-available(concat($store-path, $target)))) then
                            repo-utils:mkcol("",concat($store-path, $target)) else ()
(:                           xmldb:create-collection($store-path, $target) else ():)

  
  let $result-path := fcs-tests:get-result-paths($target, concat($queryset, $test), $config)
   
  let $store-result := repo-utils:store($result-path[1], $result-path[2], $result, true(),$config)

return $store-result
};

(:~ generates a html-view of the resulting testset
relies on repo-utils serialization function, expecting a stylesheet with the key: <b>test2view</b>
:)
declare function fcs-tests:format-result($result as node(), $config) as item()* {
    
    if ($result[self::element(diagnostics)]) then
            <div class="message">{$result/text()}</div>
       else if (exists($result/testrun)) then
          repo-utils:serialise-as ($result, "html", "test", $config)
       else repo-utils:serialise-as ($result, "html", "test", $config)
              (: return quite empty html ?? 
                t:format-testResult($result) :)
};

(:~ generates the html-page displaying either the overview, or the result of selected testset 
:)
declare function fcs-tests:display-page($target  as xs:string, $queryset as xs:string, $action, $config) as item()* {

    let $result := fcs-tests:get-result($target, $queryset, $config)        
     
    let $formatted-result := fcs-tests:format-result($result, $config)  
    let $opt := util:declare-option("exist:serialize", "media-type=text/html method=xhtml") 
         (:
    <html>
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
                <a href="?operation=overview">overview</a>
            </div>
            <!-- <div>{$config}</div> -->:)        
    return        <div id="content">
            {if (contains($action, 'overview')) then fcs-tests:display-overview($config) else () }
            <form>
                <label>targets</label><select name="target">
                    {
                    for $target-elem  in fcs-tests:get-targets($config)
                        let $target-key := xs:string($target-elem/@key)
                        let $option :=  if ($target = $target-key) then
                                            <option selected="selected" value="{$target-key}" >{$target-key}</option>
                                         else
                                            <option value="{$target-key}" >{$target-key } </option>
                        return $option
                    }
                </select>
                <label>query-set</label><select name="queryset">
                    {
                    for $queryset-key in fcs-tests:get-queryset-keys($config)
                        let $option :=  if ($queryset= $queryset-key) then
                                            <option selected="selected" value="{$queryset-key}" >{$queryset-key}</option>
                                         else
                                            <option value="{$queryset-key}" >{$queryset-key}</option>
                        return $option
                    }
                </select>
                <label>action</label>
                    <select name="action">
                       <option value="rest-queryset-run" >{if (contains($action, 'run') and not(contains($action, 'run-store'))) then attribute selected { "selected" } else ()} run</option>
                       <option value="rest-queryset-run-store" >{if (contains($action, 'run-store')) then attribute selected { "selected" } else ()} run-store</option>
                       <option value="rest-queryset-view" > {if (contains($action,'view')) then attribute selected { "selected" } else ()} view</option>                                          
                    </select>                
                <input type="submit" value="View/Run" />
                </form>
                
                <div id="result">{$formatted-result}</div>
                
            </div>            
        (:</body>
    </html>:)

};

declare function fcs-tests:display-overview($config) as item()* {

    <table><tr><th></th>{for $target in fcs-tests:get-targets($config) return <th>{xs:string($target/@key)}</th>}</tr>
            {for $queryset-key in fcs-tests:get-queryset-keys($config)
                  return  <tr>
                        <th>{$queryset-key}</th>
                        {for $target in fcs-tests:get-targets($config)
                           let $target-key := $target/xs:string(@key)
                           let $test-result := fcs-tests:get-result($target-key , $queryset-key, $config)                           
                           let $root-elem := $test-result/*/name()
                           let $op := if ($test-result//diagnostic["result-unavailable" = xs:string(@key)]) then 'run' else 'view'
                           (: display number of all and failed tests in the testset, operates on the HTML produced during the test-run :)
                           let $view:= if ($test-result//diagnostic["result-unavailable" = xs:string(@key)]) then ()
                                       else  
                                            let $show := if ($root-elem[1] eq 'testrun') then 
                                                            <span><span class="test-passed">{count($test-result//div[@class='test'][.//span[@class='value true']])}</span>{"/"}
                                                                   <span class="test-failed">{count($test-result//div[@class='test'][.//span[@class='value false']])}</span>{"/"}                                                                   
                                                                {count($test-result//div[@class='test'])}
                                                                {if (exists($test-result//diagnostics)) then <span class="test-failed">!!</span> else () }
                                                              </span>
                                                            else $root-elem 
                                            return <a href="?target={$target-key}&amp;queryset={$queryset-key}&amp;action=rest-queryset-view" >{$show}</a> 
                            let $run := if ($queryset-key = $target/queryset/xs:string(@key)) then 
                                                        ('[', <a href="?target={$target-key}&amp;queryset={$queryset-key}&amp;action=rest-queryset-run" >run</a>, ']')
                                                    else ()                 
                        return <td align="center">{($view, $run)} </td>
                        }
                    </tr>
            }</table>
};

(:~
old way of getting querysets =  explicitely stated in config: $config//queryset

@param $target - optionally only querysets for given target
:)
declare function fcs-tests:get-querysets($config, $target) as element()* {
    let $querysets := collection(repo-utils:config-value($config, "queryset.path"))//queryset
    return if ($target='') then $querysets 
                else  $querysets[xs:string(@id) = fcs-tests:get-targets($config, $target)/queryset/xs:string(@key)] 
};

declare function fcs-tests:get-querysets($config) as element()* {
    fcs-tests:get-querysets($config, '')
};

(:~ helper function to list the queryset-keys
 reading from queryset-dir :)
declare function fcs-tests:get-queryset-keys($config) as xs:string* {
    fcs-tests:get-querysets($config)/xs:string(@id)
};

declare function fcs-tests:get-target-keys($config) as xs:string* {
    fcs-tests:get-targets($config)/xs:string(@key)
};

declare function fcs-tests:get-targets($config) as element()* {
    fcs-tests:get-targets($config, '') 
};

declare function fcs-tests:get-targets($config, $target) as element()* {
    $config//target[$target='' or xs:string(@key)=$target]
};



(:~ helper function for substituting a string with values from a substitution-element
? should be probably moved to repo-utils

@param $string string with %-keys in it (eg: "My name is %name") 
@param $substset an element with attributes and subelements that will be used for substitution (their name being use for matching the %-keys in the string
                 (eg <subst name="Homer" />)
@return the original string, with %-keys replaced by values from the substitution element (if found,  otherwise the %-key stays unchanged)
          (eg "My name is Homer")      
:)
declare function fcs-tests:subst($string as xs:string, $substset)
    {
        let $substkeys := for $substi in $substset/(*|@*) return
                                if (ends-with($substi/name(),'url')) then concat('%', $substi/name()) 
                                      else (concat('%', $substi/name()),concat('%_', $substi/name(), '_url'))  
                                    
        
        let $substvalues := for $substi in $substset/(*|@*) return 
                            if (ends-with($substi/name(),'url')) then xmldb:encode(xs:string($substi)) 
                                    else 
                                        (xs:string($substi), xmldb:encode(xs:string($substi)))
        
        (: let $temp := replace($string, concat('%', $substkey), $substvalue) 
        return if count($substset local:subst($temp, $substset/*[position() > 1]) :)
        return repo-utils:replace-multi ($string, $substkeys, $substvalues)
        
    };
