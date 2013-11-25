xquery version "3.0";

(:~
 : This is a proof-of-concept script which takes a cr-xq map
 : element and generates a xql module with getter-functions for 
 : the indexes declared in it.
 : could be used as a trigger target.
~:)

import module namespace config="http://exist-db.org/xquery/apps/config" at "../../core/config.xqm";

import module namespace fcs = "http://clarin.eu/fcs/1.0" at "../fcs/fcs.xqm";

declare variable $PARAMETER_MISSING := QName("http://exist-db.org/xquery/templates", "Parameter was not supplied.");

declare variable $config:app-root external;

declare variable $local:preamble:="xquery version '3.0';";

declare variable $local:prefix:=replace(request:get-parameter("project",""),'','');

declare function local:declare-index-function($index-name, $config) as xs:string?{
    
    "declare function "||$local:prefix||":get-"||$index-name||"($data) as item()* {&#10;"||
        "&#09;$data//"||fcs:index-as-xpath($index-name,$local:prefix, $config)||"&#10;"||
    "};&#10;&#10;"
};

 
if ($local:prefix!='')
then
    let $config:=   config:config($local:prefix),
        $mappings:= fcs:get-mapping('', $local:prefix,$config)
    let $defs:=     for $index in $mappings//index return local:declare-index-function($index/@key,$config),
        $path:=     $app:root||'/modules/index-functions/',
        $resource:= $local:prefix||".xqm"
    let $store:=    xmldb:store($path, $resource, string-join(($local:preamble,$defs),'&#10;&#10;'), 'application/xquery')
    let $exec:=     xmldb:set-resource-permissions($path, $resource, 'guest', 'guest', '755')
    return $exec!=''
else 
    error($PREFIX_MISSING,'parameter $project is empty')