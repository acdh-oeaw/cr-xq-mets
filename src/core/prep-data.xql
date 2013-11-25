xquery version "3.0";
import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace fcs = "http://clarin.eu/fcs/1.0" at "../modules/fcs/fcs.xqm";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at "repo-utils.xqm";
import module namespace resource = "http://aac.ac.at/content_repository/resource" at "resource.xqm";
import module namespace resourcefragment = "http://aac.ac.at/content_repository/resourcefragment" at "resourcefragment.xqm";

declare namespace cr="http://aac.ac.at/content_repository";

declare variable $local:resourcefragment-pid-name:="resourcefragment-pid";

let $flags:=tokenize(request:get-parameter("flags",""),',')
let $path:=request:get-parameter("path","")
let $project:=request:get-parameter("project",""),
    $resource-pid:=resource:new($path, $project),
    $config:=config:config($project)
let $resource-fragment-index:=config:config($project)//index[@key=$local:resourcefragment-pid-name],
    $resource-fragment-path:="("||string-join($resource-fragment-index/path,'|')||")",
    $resource-fragment-use:="("||string-join($resource-fragment-index/@use,'|')||")"

let $doc := doc($path),
    $filename := tokenize($path,'/')[last()],
    $collection := replace($path,$filename,'')

(:let $wc-path:=replace($config//param[@key='working-copies.path']/xs:string(.),'/$',''),
    $wc-filename := "wc-"||$filename
    
    
let $working-copy:=
        switch(true())
            case $wc-path eq '' 
                return util:log("INFO","$wc-path empty!")
            case ($flags='keepwc' and doc-available($wc-path||"/"||$wc-filename))
                return doc($wc-path||"/"||$wc-filename)
            default 
                return  
                    let $xsl-path:="/db/apps/cr-xq-dev0913/core/add-cr-ids.xsl",
                        $xsl-params:=
                                <parameters>
                                    <param name="resource-pid" value="{$resource-pid}"/>
                                    <param name="project-id" value="{$project}"/>
                                </parameters>,
                        $doc-ids-added:=transform:transform($doc,doc($xsl-path),$xsl-params),
                        $store-wc := repo-utils:store-in-cache($wc-filename,$wc-path,$doc-ids-added,$config)
                    let $update-mets:= if ($store-wc) then resource:add-workingcopy($wc-path||"/"||$wc-filename,$resource-pid,$project) else ()
                    return $store-wc :)

return
    switch (true())
        case not(doc-available($path)) return <error>document at {$path} not available.</error>
        case not(exists($working-copy)) return <error>could not store {$wc-path||"/"||$wc-filename}.</error>
        case empty($working-copy) return <error>working copy was not generated.</error>
        default return
            let $define-ns:=
                let $mappings:=config:mappings($config),
                    $namespaces:=$mappings//namespaces
                return 
                    for $ns in $namespaces/ns
                    let $prefix:=$ns/@prefix,
                        $namespace-uri:=$ns/@uri
                    let $log:=util:log("INFO", "declaring namespace "||$prefix||"='"||$namespace-uri||"'")
                    return util:declare-namespace(xs:string($prefix), xs:anyURI($namespace-uri))
            let $all-fragments:=util:eval("$working-copy//"||$resource-fragment-path)
            let $fragment-element-has-content:=some $x in $all-fragments satisfies exists($x/*)
            let $fragments-extracted:=
                for $pb1 at $pos in $all-fragments 
                    let $id:=$resource-pid||"_frag"||format-number($pos, '00000000')
                    let $fragment:=
                        if ($fragment-element-has-content)
                        then $pb1
                        else 
                            let $pb2:=util:eval("(for $x in $all-fragments where $x >> $pb1 return $x)[1]")
                            return util:parse(util:get-fragment-between($pb1, $pb2, true(), true()))
                    let $log:=util:log("INFO","processing resourcefragment w/ pid="||xs:string($id))
                    return
                        <fcs:ResourceFragment context="{$project}" resource-pid="{$resource-pid}" resourcefragment-pid="{$id}">{$fragment}</fcs:ResourceFragment>
            let $table-path:=replace($config//param[@key='lookup-tables.path'],'/$',''),
                $table-filename:="lt-"||$filename,
                $table-doc:=
                    <fcs:lookup-table context="{$project}" pid="{$resource-pid}" created="{current-dateTime()}" filepath="{$path}" filemodified="{xmldb:last-modified($collection,$filename)}">{
                        for $fragment in $fragments-extracted
                        return 
                            <fcs:ResourceFragment context="{$project}" resource-pid="{$resource-pid}" resourcefragment-pid="{$fragment/@resourcefragment-pid}">{
                                for $cr:id in $fragment//@cr:id 
                                return <cr:id>{$cr:id}</cr:id>
                            }</fcs:ResourceFragment>
                    }</fcs:lookup-table>,
                $store-table:=repo-utils:store-in-cache($table-filename,$table-path,$table-doc,$config)
            
            let $fragments-path :=replace($config//param[@key='resourcefragments.path'],'/$',''),
                $fragments-filename:="frg-"||$filename,
                $fragments-doc:=<fcs:Resource context="{$project}" pid="{$resource-pid}" created="{current-dateTime()}" filepath="{$path}" filemodified="{xmldb:last-modified($collection,$filename)}">{$fragments-extracted}</fcs:Resource>
            let $store-fragments:=repo-utils:store-in-cache($fragments-filename,$fragments-path,$fragments-doc,$config)
            (: add extracted fragments to mets fileGrp + structMap :)
            let $update-mets:=resourcefragment:new($resource-pid,$fragments-path||"/"||$fragments-filename,$project) 
            return 
                <result>{
                    if ($store-table)
                    then <success>stored {$table-path||"/"||$table-filename}</success>
                    else <error>could not store {$table-path||"/"||$table-filename}</error>,

                    if ($store-fragments)
                    then <success>stored {$fragments-path||"/"||$fragments-filename}</success>
                    else <error>could not store {$fragments-path||"/"||$fragments-filename}</error>
                }</result>
                