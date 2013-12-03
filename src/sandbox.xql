xquery version "3.0";

declare namespace cr="http://aac.ac.at/content_repository";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace mets = "http://www.loc.gov/METS/";


(:import module namespace repo-utils="http://aac.ac.at/content_repository/utils" at "core/repo-utils.xqm";:)
import module namespace fcs="http://clarin.eu/fcs/1.0" at "modules/fcs/fcs.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "core/config.xqm"; 
import module namespace project = "http://aac.ac.at/content_repository/project" at "core/project.xqm";
import module namespace index = "http://aac.ac.at/content_repository/index" at "core/index.xqm";
import module namespace resource = "http://aac.ac.at/content_repository/resource" at "core/resource.xqm";
(:import module namespace wc = "http://aac.ac.at/content_repository/workingcopy" at "core/wc.xqm";:)
import module namespace lt = "http://aac.ac.at/content_repository/lookuptable" at "core/lookuptable.xqm";
(:import module namespace master = "http://aac.ac.at/content_repository/master" at "core/master.xqm";:)
import module namespace rf = "http://aac.ac.at/content_repository/resourcefragment" at "core/resourcefragment.xqm";

(: declaration of helper namespaces for better code structuring :)
declare namespace param="userinput.parameters";
declare namespace this="current.object";

declare function cr:get-resourcefragment-pids($project-pid as xs:string, $resource-pid as xs:string, $elt-id as xs:string) as xs:string* {
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



declare function local:cat($a, $b){
    $a||$b
};

declare function local:cat($a, $b, $c, $d){
    $a||$b||$c||$d
};



let $project:="abacus"

(:let $cr-data-path:="/db/cr-data",
    $rf-path:=$cr-data-path||"/_resourcefragments",
    $wc-path:=$cr-data-path||"/_working_copies"

let $project-rf:=collection($rf-path||"/"||$project),
    $project-wc:=$wc-path||"/"||$projecta

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
let $node := <TEI xmlns="http://www.tei-c.org/ns/1.0"><text><body><p xml:id="p1">This is my first resourcefragment!</p><p xml:id="p2">This is another resourcefragment!</p></body></text></TEI>
(:return project:purge(xs:ID("crroot"),true()):)
(:return resource:new(document{$node},xs:ID("crroot")):)
(:return resource:get("testProject.32af5d6cc1cf381b852bc391c66ca3dc","testProject"):)
(:return project:purge(xs:ID("someProject"),true()):)
(:return fn:translate("ab:cd e"," :","_"):)
(:return project:resources(xs:ID("crroot")):)
(:return project:get(xs:ID("crroot"))//id("crroot.80b746c8af203cb4a9e7e7a5d14709b3"):)
(:return xs:ID("crroot.80b746c8af203cb4a9e7e7a5d14709b3"):)
(:project:new("someTestProject"):)
(:return proje ct:get(xs:ID("someProject")):)
(:let $doc:=project:get(xs:ID("someProject")):)
(:return $project:default-template:)
(:return config:path('mets.template'):)
(:return project:default-acl(xs:ID("someProject")):)
let $project-pid:="newProj",
    $resource-pid := "newProj.d41d8cd98f003204a9800998ecf8427e"
return lt:create($resource-pid,$project-pid)
(:return fcs:index-as-xpath("resourcefragment-pid",$project-pid, config:config($project-pid)):)