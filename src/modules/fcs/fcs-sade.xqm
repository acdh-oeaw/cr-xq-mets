xquery version "3.0";

module namespace fcs="http://sade/fcs";

import module namespace templates="http://exist-db.org/xquery/templates" at "templates.xql";
import module namespace kwic="http://exist-db.org/xquery/kwic"
    at "resource:org/exist/xquery/lib/kwic.xql";
import module namespace config="http://exist-db.org/xquery/apps/config" at "../../core/config.xqm";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at  "../../core/repo-utils.xqm";
import module namespace fcsm = "http://clarin.eu/fcs/1.0" at "fcs.xqm";

declare namespace cmd = "http://www.clarin.eu/cmd/";

(:declare variable $app:SESSION := "shakespeare:results";:)
(:declare variable $fcs:config := repo-utils:config("/db/cr/conf/mdrepo/config.xml");:)

(:~ deliver a query-input "widget" (especially with a selector of fcs-resources
:)
(:%templates:default("x-dataview","kwic")
    %templates:default("x-format","html"):)
declare 
    %templates:wrap
    %templates:default("x-format","html")
    %templates:default("x-context","")    
function fcs:query-input($node as node()*, $model as map(*), $query as xs:string?, $x-context as xs:string*, $x-dataview as xs:string*, $x-format as xs:string?, $base-path as xs:string?) {
    
    let $template := <a href="query-input" class="template" /> 
    let $params := <parameters><param name="format" value="{$x-format}"/>
    config:param-value($model, 'project-static-dir')
                                    <param name="base_url" value="{config:param-value($model,'base-url')}"/>			         
                  			         <param name="q" value="{$query}"/>
              			            <param name="x-context" value="{$x-context}"/>              			            
              			            <param name="x-dataview" value="{$x-dataview}"/>
                  </parameters>
                  (:<param name="base_url" value="{$base-path}"/>
                  <param name="base_url" value="{repo-utils:base-url($model("config"))}"/>:)
                  
     return  repo-utils:serialise-as($template, $x-format, 'static', $model("config"), $params)
     
};



(:~ invokes the search-retrieve function of the fcs-module
tries to use x-context and x-dataview parameter from the configuration, if no explicit x-context was given
:)
declare 
    %templates:wrap
    %templates:default("x-context","")
    %templates:default("x-dataview","title,kwic")
    %templates:default("startRecord",1)
    %templates:default("maximumRecords",10)
    %templates:default("x-format","html")    
function fcs:query($node as node()*, $model as map(*), $query as xs:string?, $x-context as xs:string*, $x-dataview as xs:string*, $x-format as xs:string?, $startRecord as xs:integer, $maximumRecords as xs:integer, $base-path as xs:string?) {
    session:create(),
(:    let $hits := app:do-query($query, $mode):)       
(:    let $store := session:set-attribute($app:SESSION, $hits):)

    let $x-context-x := if ($x-context='') then config:param-value($node, $model,'fcs','','x-context') else $x-context
    let $x-dataview-x := if ($x-dataview='') then config:param-value($node, $model,'fcs','','x-dataview') else $x-dataview
    
    let $base-path-x := if ($base-path='') then config:param-value($model,'base-url') else $base-path
    
    (: hardcoded sorting - needs to be optional (currently only used in STB :)
    (:let $cql-query := if (contains($query, 'sortBy')) then $query else concat ($query, " sortBy sort"):)
    let $cql-query := $query 
    let $result := 
(:       fcs:search-retrieve($query, $x-context, xs:integer($start-item), xs:integer($max-items), $x-dataview, $config):)
       fcsm:search-retrieve($cql-query, $x-context-x, $startRecord , $maximumRecords, $x-dataview-x, $model("config"))
    let $params := <parameters><param name="format" value="{$x-format}"/>
                  			         <param name="base_url" value="{config:param-value($model,'base-url')}"/>
              			            <param name="x-context" value="{$x-context-x}"/>              			            
              			            <param name="x-dataview" value="{$x-dataview-x}"/>
                  </parameters>
                  (:<param name="base_url" value="{repo-utils:base-url($config)}"/>:)
                  
     return repo-utils:serialise-as($result, $x-format, 'searchRetrieve', $model("config"), $params)
     
};


(:~ invokes the scan-function of the fcs-module
tries to use x-context parameter from the configuration, if no explicit x-context was given
:)
(: DS 2015/02/13: removed default value for $sort
   in order to provide a default order on the index map definition
   while only request parameters to fcs:scan() should be used 
   to override this default order :)
declare 
    %templates:wrap
    %templates:default("x-context","")
    %templates:default("x-format","html")
    %templates:default("start-term",1)
    %templates:default("max-terms",50)
function fcs:scan($node as node()*, $model as map(*), $scanClause as xs:string, $start-term as xs:integer, $max-terms as xs:integer,  $sort as xs:string?, 
$x-context as xs:string*, $x-format as xs:string?, $base-path as xs:string?) {
    
    let $x-context-x := if ($x-context='') then config:param-value($node, $model,'fcs','','x-context') else $x-context
    let $base-path-x := if ($base-path='') then config:param-value($model,'base-url') else $base-path
    
    let $result :=
            fcsm:scan($scanClause, $x-context-x, $start-term, $max-terms, 1, 1, $sort, '', $model("config"))
    
    let $params := <parameters>
                        <param name="format" value="{$x-format}"/>
                  		<param name="base_url" value="{concat(config:param-value($model,'base-url'),'fcs')}"/>
                  		{if ($sort != '') then <param name="sort" value="{$sort}"/> else ()}	         
              			<param name="x-context" value="{$x-context-x}"/>             			            
                  </parameters>
     return  repo-utils:serialise-as($result, $x-format, 'scan', $model("config"), $params)
     
};



(:~ return number of documents in the data.path collection
:)
declare function fcs:count-records($node as node(), $model as map(*)) {

       let $data-path := repo-utils:config-value($model("config"),"data.path")
       return count(collection($data-path)/(cmd:CMD|CMD))
    
};


declare function fcs:status($node as node(), $model as map(*)) {

let $count-records := fcs:count-records($node, $model)
       
let $logs := collection("/db/mdrepo-data/logs")/log[translate(xs:string(@start-time),' ', 'T') castable as xs:dateTime]

let $dataset_status := for $dataset in  distinct-values ($logs/xs:string(@dataset))
    let $last-updated := max ($logs[xs:string(@dataset)=$dataset]/xs:dateTime(translate(@start-time,' ','T')))
    let $count-files := $logs[xs:string(@dataset)=$dataset][xs:dateTime(translate(@start-time,' ','T'))=$last-updated]/xs:string(@count-files)
   return <dataset key="{$dataset}" last-updated="{$last-updated}" count-files="{$count-files}" />
   
   return 
        <div>
            <h3>Status</h3>        
        <table class="bordered" >
        <thead><tr><th>dataset</th><th>count records</th><th>last updated</th></tr></thead>
        {        
        for $dataset in $dataset_status
            return <tr><td>{$dataset/xs:string(@key)}</td><td class="number">{$dataset/xs:string(@count-files)}</td><td>{$dataset/xs:string(@last-updated)}</td>
                    </tr>
                  }
        <tr><td>total records</td><td class="number"><b>{$count-records}</b></td><td></td></tr>
        </table>
        </div>
    
};
