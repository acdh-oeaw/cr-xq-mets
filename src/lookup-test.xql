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

declare namespace fcs="http://clarin.eu/fcs/1.0";
declare namespace cr="http://aac.ac.at/content_repository";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace mets = "http://www.loc.gov/METS/";

import module namespace config="http://exist-db.org/xquery/apps/config" at "core/config.xqm"; 
import module namespace project = "http://aac.ac.at/content_repository/project" at "core/project.xqm";
import module namespace wc = "http://aac.ac.at/content_repository/workingcopy" at "core/wc.xqm";
import module namespace master = "http://aac.ac.at/content_repository/master" at "core/master.xqm";
import module namespace rf = "http://aac.ac.at/content_repository/resourcefragment" at "core/resourcefragment.xqm";

(: declaration of helper namespaces for better code structuring :)
declare namespace param="userinput.parameters";
declare namespace this="current.object";

declare function cr:get-resourcefragment-pids($project-pid as xs:string, $resource-pid as xs:string, $elt-id as xs:string)  as xs:string* {
    (: lookup via table -> faster, but needs own index file + processing :)
    let $lts:="/db/cr-data/_lookup_tables"||"/"||$project-pid
    let $table:=collection($lts)//fcs:lookup-table[@pid eq $resource-pid]
    return $table//fcs:ResourceFragment[cr:id/@cr:id eq $elt-id]/xs:string(@resourcefragment-pid)
    
    (: lookup via rescourcefragments-cache, slower, but needs less space + processing at ingest :)
(:    let $rfc:="/db/cr-data/_resourcefragments"||"/"||$project-pid,:)
(:        $rf:=collection($rfc)//*[@cr:id eq $elt-id and @cr:resource-pid eq $resource-pid]/ancestor::fcs:ResourceFragment:)
(:    return $rf/@resourcefragment-pid:)
};
    


declare function cr:get-pids($param:elt as item()) as map() {
    let $elt:=
        typeswitch ($param:elt)
            case element()  return $param:elt
            default         return $param:elt/parent::*
    let $elt-id:= $elt/@cr:id,
        $elt-ns:=namespace-uri($param:elt),
        $elt-name:=name($param:elt)
        
    let $project-pid:=$elt/@cr:project-id,
        $resource-pid:=$elt/@cr:resource-pid,
        $resourcefragment-pids:=cr:get-resourcefragment-pids($project-pid,$resource-pid,$elt-id)

    let $maps:=(
            map:entry("elt-id",$elt/@cr:id),
            map:entry("elt-ns",$elt-ns),
            map:entry("elt-name",$elt-name),
            map:entry("project-pid",$project-pid),
            map:entry("resource-pid",$resource-pid),
            for $f at $pos in $resourcefragment-pids return map:entry('resourcefragment-pid-'||$pos, $f),
            map:entry("data",util:serialize($elt,'method=xml'))
        )
    return map:new($maps)
};

let $project:="abacus"

(:let $cr-data-path:="/db/cr-data",
    $rf-path:=$cr-data-path||"/_resourcefragments",
    $wc-path:=$cr-data-path||"/_working_copies"

let $project-rf:=collection($rf-path||"/"||$project),
    $project-wc:=$wc-path||"/"||$project

let $searchpath:=$project-wc
let $base:=collection($searchpath)

let $match:=$base//@lemma[.='Haus']
let $pids:=for $m in $match return cr:get-pids($m)
let $number-of-matches:=count($match)
return 
    ("number of matches: "||$number-of-matches,
    for $p in $pids 
    return 
        ("*****",for $key in map:keys($p) return $key||": "||map:get($p, $key))
    )
(\:return $match:\)
:)
(:let $rf-pid:="res21b4ce57ff094ba79b55_frag00000017",
    $r-pid:="res21b4ce57ff094ba79b55"
return wc:generate($r-pid,$project):)
let $data:=<sm:permission xmlns:sm="http://exist-db.org/xquery/securitymanager" owner="admin" group="dba" mode="rwxr-xr-x">
    <sm:acl entries="0"/>
</sm:permission>
return project:acl("someProject",())