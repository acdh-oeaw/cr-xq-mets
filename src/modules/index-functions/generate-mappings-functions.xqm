xquery version '3.0';

module namespace gen =  "http://cr-xq/gen";

import module namespace config="http://exist-db.org/xquery/apps/config" at "../../core/config.xqm";
import module namespace index="http://aac.ac.at/content_repository/index" at "../../core/index.xqm";

declare namespace sade = "http://sade";

declare variable $gen:cr := "&#10;";
declare variable $gen:modulename := "dynix";
declare variable $gen:modulens:= "http://cr-xq/"||$gen:modulename;

declare variable $gen:module-collection := "xmldb:exist:///apps/sade/modules/";
 
declare function gen:generate-index-functions($mappings, $config) as item()* {

(: import module namespace sade = "{$gen:modulename}" at "/apps/sade/core/main.xqm";:)
let $indexes := $mappings//index
let $result :=
    <processor-code>
xquery version '3.0';
module namespace {$gen:modulename} = "{$gen:modulens}"; 

{
       for $ns in $mappings//namespaces/ns
        return "declare namespace "||$ns/@prefix||" = '"||$ns/@uri||"';"||$gen:cr
       }

(: dynamic processing of templates generated from the list of modules :)

declare {"function dynix:apply-index" (: this is just to fool the script analyzing the dependencies :) }($data as node()*, $index-name as xs:string, $x-context as xs:string, $type as xs:string?) as item()* {{ {$gen:cr}
     
       
      switch ($type) 
      {
      for $xtype in ($index:xpath-type,'default')
       let $case :=  if ($xtype='default') then 'default' else "case '"||$xtype||"'"         
       return ($case||" return switch ($index-name) ", $gen:cr, 
        for $ix in $indexes
        let $ix-name := $ix/data(@key)         
(:        let $ix-path := $ix/path/text():)
        let $ix-path := index:index-as-xpath($ix-name,$config, $xtype)
        
        return 
        
           "&#09;case '"||$ix-name||"' return $data//"||$ix-path||$gen:cr ,
           "&#09;default return util:eval('$data//'||$index-name) ", $gen:cr
    ) }
  }};

</processor-code>

return $result/text()
};
 
 
declare function gen:store-index-functions($code as xs:string) {

    let $path:=     $config:app-root||'/modules/index-functions/',
        $resource:= $gen:modulename||'.xqm'
        
    let $store:=    xmldb:store($path, $resource, $code, 'application/xquery')
    let $exec:=     xmldb:set-resource-permissions($path, $resource, 'guest', 'guest', 755)
    return $exec!=''
};