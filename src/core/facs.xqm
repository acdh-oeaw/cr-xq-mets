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

module namespace facs="http://aac.ac.at/content_repository/facs";
import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace index = "http://aac.ac.at/content_repository/index" at "index.xqm";
import module namespace project="http://aac.ac.at/content_repository/project" at "project.xqm";
import module namespace rf="http://aac.ac.at/content_repository/resourcefragment" at "resourcefragment.xqm";
import module namespace resource="http://aac.ac.at/content_repository/resource" at "resource.xqm";
import module namespace repo-utils="http://aac.ac.at/content_repository/utils" at "repo-utils.xqm";
import module namespace wc="http://aac.ac.at/content_repository/workingcopy" at "wc.xqm";
declare namespace cr="http://aac.ac.at/content_repository";
declare namespace mets="http://www.loc.gov/METS/";
declare namespace xlink="http://www.w3.org/1999/xlink";

(: will be used, if there's not param @key = "facs.version" in project.xml :)
declare variable $facs:default-version := "default";

(:~
 : Getter and Setter for facsimiles of resources and resource fragments. 
 :)
 

(:~
 : Generates a facs-file for a single resource fragment, using the default 
 : version/quality as specified in the facs module config. 
 : @param $resourcefragment-pid
 : @param $resource-pid
 : @param $project-pid 
~:)
declare function facs:generate-file($resourcefragment-pid as xs:string, $resource-pid as xs:string, $project-pid as xs:string) as element(mets:file)* {
      facs:generate-file((),$resourcefragment-pid,$resource-pid,$project-pid)
};

(:~
 : Generates a facs-file for a single resource fragment in a given resource
 : @param $resourcefragment-pid
 : @param $resource-pid
 : @param $project-pid 
~:)
declare function facs:generate-file($version-param as xs:string?, $resourcefragment-pid as xs:string, $resource-pid as xs:string, $project-pid as xs:string) as element(mets:file)* {
    let $log := util:log-app("TRACE",$config:app-name,"facs:generate-file("||$version-param||", "||$resourcefragment-pid||", "||$resource-pid||", "||$project-pid||")")
    let $file-id := facs:id-by-resourcefragment($resourcefragment-pid,$resource-pid,$project-pid),
        $log := util:log-app("TRACE",$config:app-name,"$file-id := "||string-join($file-id, ', '))
    return if ($file-id != "") then
    let $version := ($version-param,config:param-value(project:get($project-pid),'facs.version'),$facs:default-version)[.!=''][1]
    let $url :=     facs:generate-url($file-id, $version, $resourcefragment-pid,$resource-pid,$project-pid)
    let $log := util:log-app("TRACE",$config:app-name,"$url := "||$url)
    let $file-elt:=
        switch(true())
            case $file-id ="" return util:log-app("ERROR",$config:app-name,"No value in index 'facs' for resource fragment "||$resourcefragment-pid)
            case $url = "" return 
                let $log := util:log-app("INFO",$config:app-name,"No url for this file ID")
                return ()
            default return         
                for $f at $pos in $file-id
                let $log := util:log-app("TRACE",$config:app-name,"$file-id["||$pos||"] := "||$f)
                return
                    <mets:file ID="{$resourcefragment-pid}_{$version}{$config:RESOURCE_FACS_SUFFIX}{$pos}">
                        <mets:FLocat LOCTYPE="URL" xlink:href="{$url}"/>
                    </mets:file>
    let $log := util:log-app("TRACE",$config:app-name,"facs:generate-file return "||serialize($file-elt))
    return $file-elt
    else ()  
};

(:~
 : Gets the global file group for facsmilies of the project.
 : @param $resourcefragment-pid the PID of the Resource Fragment
 : @param $resource-pid the PID of the Resource
 : @param $project-pid the PID of the Project
 : @return zero or one mets:fileGrp element containing one mets:fileGrp element for each resource that has facsimlies.
~:)
declare function facs:get-fileGrp($project-pid as xs:string) as element(mets:fileGrp)? {
    project:get($project-pid)//mets:fileGrp[@ID eq $config:PROJECT_FACS_FILEGRP_ID]
};

(:~
 : sets facs-files and fptrs for a single resource fragment in a given resource
 : @param $mets:file a mets:file element, generated by facs:generate-file()
 : @param $resourcefragment-pid the PID of the Resource Fragment
 : @param $resource-pid the PID of the Resource
 : @param $project-pid the PID of the Project 
~:)
declare function facs:set($version as xs:string, $mets:file as element(mets:file)+, $resourcefragment-pid as xs:string, $resource-pid as xs:string, $project-pid as xs:string) as empty-sequence() {
    let $log := util:log-app("TRACE",$config:app-name,"facs:set $version := "||$version||" $mets:file := "||substring(serialize($mets:file),1,240)||"... $resourcefragment-pid := "||$resourcefragment-pid||" $resource-pid := "||$resource-pid||" $project-pid := "||$project-pid)
    let $file := facs:get-file($version,$resourcefragment-pid, $resource-pid, $project-pid)
    let $mets:div := rf:record($resourcefragment-pid, $resource-pid, $project-pid)
    (: set the mets:fptr in mets:div :)
    let $set-fptr := 
        let $del := if (exists($file))
                    then update delete $mets:div//mets:fptr[@FILEID = $file/@ID]
                    else ()
        return 
            for $f in $mets:file
            return update insert <mets:fptr FILEID="{$f/@ID}"/> into $mets:div
    
    (: set mets:file element :)        
    let $set-file :=  
        if (exists($file))
        then
            (: a facsimilie of the same quality exists, so we just delete it and insert the new one(s) :)
            let $fileGrp := $file/parent::mets:fileGrp[1]
            let $rm-old-files := update delete $file
            return update insert $mets:file into $fileGrp
        else 
            (: we need the resource's main facsimile filegrp, parent of all 'version'-specific fileGrps :)
            let $fileGrp := root($mets:div)//mets:fileGrp[@ID = $config:PROJECT_FACS_FILEGRP_ID]/mets:fileGrp[@ID = $resource-pid||$config:RESOURCE_FACS_SUFFIX]
            return 
                if (exists($fileGrp))
                then  
                    if (exists($fileGrp/mets:fileGrp[@USE = $version]))
                    then update insert $mets:file into $fileGrp/mets:fileGrp[@USE = $version]
                    else update insert <mets:fileGrp USE="{$version}">{$mets:file}</mets:fileGrp> into $fileGrp 
                else
                    let $new_fileGrp := 
                        <mets:fileGrp ID="{$resource-pid}{$config:RESOURCE_FACS_SUFFIX}" USE="{$config:PROJECT_FACS_FILEGRP_USE}">
                            <mets:fileGrp USE="{$version}">{$mets:file}</mets:fileGrp>
                        </mets:fileGrp>
                    return 
                        if (exists(facs:get-fileGrp($project-pid)))
                        then update insert $new_fileGrp into facs:get-fileGrp($project-pid)
                        else update insert <mets:fileGrp ID="{$config:PROJECT_FACS_FILEGRP_ID}" USE="Visual representations of the project's data (Facsimile et. alt.)">{$new_fileGrp}</mets:fileGrp> into root($mets:div)//mets:fileSec

    return ()
};


(:~
 : Returns one or more URLs to the facsimile(s) of the given resource fragment 
 : in the default version/quality as set in the projects configuration. Returns the 
 : empty sequence, if the resource fragment does not exist.
~:)
declare function facs:get-url($resourcefragment-pid as xs:string, $resource-pid as xs:string, $project-pid as xs:string) as xs:anyURI* {
   facs:get-url((),$resourcefragment-pid,$resource-pid,$project-pid)
};

(:~
 : Returns one or more URLs to the facsimile(s) of the given resource fragment
 : in the version / quality specified in the first function parameter. 
~:)
declare function facs:get-url($version-param as xs:string?, $resourcefragment-pid as xs:string, $resource-pid as xs:string, $project-pid as xs:string) as xs:anyURI* {
    let $version := ($version-param,config:param-value(project:get($project-pid),'facs.version'),$facs:default-version)[.!=''][1]
    let $file := facs:get-file($resourcefragment-pid,$resource-pid,$project-pid),
        $global-imgFileGrp := facs:get-fileGrp($project-pid)
    return
        for $f in $file
        let $href := $f/mets:FLocat/@xlink:href
        let $admid := $file/ancestor-or-self::*[some $x in ancestor-or-self::*[@ADMID] satisfies $x is $global-imgFileGrp]/@ADMID
        let $credentials := root($file)//mets:amdSec[@ID=$admid]/mets:rightsMD/mets:mdWrap/mets:xmlData/credentials
        return
            if (exists($credentials))
            then    
                let $session:=
                    (session:set-attribute($href||"-username",$credentials/username),
                    session:set-attribute($href||"-password",$credentials/password))
                return xs:anyURI("proxy.xql?url="||$href)
            else $href
};


(:~
 : Gets the mets:file of the facsimile(s) of one resourcefragment 
~:)
declare function facs:get-file($resourcefragment-pid as xs:string, $resource-pid as xs:string, $project-pid as xs:string) as element(mets:file)* {
    facs:get-file((),$resourcefragment-pid,$resource-pid,$project-pid)
};

declare function facs:get-file($version-param as xs:string?, $resourcefragment-pid as xs:string, $resource-pid as xs:string, $project-pid as xs:string) as element(mets:file)* {
    let $version := ($version-param,config:param-value(project:get($project-pid),'facs.version'),$facs:default-version)[.!=''][1]
    let $mets:div := rf:record($resourcefragment-pid, $resource-pid, $project-pid),
        (: we assume that a fptr to a facs points to the 
        file as a whole, not to an area :)
        $fids:= $mets:div/mets:fptr/@FILEID
    return root($mets:div)//mets:file[@ID = $fids][ancestor-or-self::*/@USE = $version]
};

(: gest all facsimile file elements, regardless of the quality/version, of a resource :)
declare function facs:get-files($resource-pid as xs:string, $project-pid as xs:string) as element(mets:file)* {
    facs:get-files((),$resource-pid,$project-pid)
};

declare function facs:get-files($version-param as xs:string?, $resource-pid as xs:string, $project-pid as xs:string) as element(mets:file)* {
    let $version := ($version-param,config:param-value(project:get($project-pid),'facs.version'),$facs:default-version)[.!=''][1]
    let $entry := resource:get($resource-pid,$project-pid),
        $fileids := $entry//mets:fptr/@FILEID
    return root($entry)//mets:file[@ID = $fileids][ancestor-or-self::*/@USE = $version]
};

(:~
 : Generates (or replaces) the files and fptrs to a resource's facsimiles in the default version/quality.
 : @param $resourcefragment-pid the pid of the resourcefragment to get the file-id from
 : @param $resource-pid the pid of the resource
 : @param $project-pid the pid of the project
~:)
declare function facs:generate($resource-pid as xs:string, $project-pid as xs:string) as empty-sequence() {
    facs:generate((),$resource-pid,$project-pid)
};


(:~
 : Generates (or replaces) the files and fptrs to a resource's facsimiles in the version/quality indicated.
 : @param $version the quality of the facsimiles
 : @param $resourcefragment-pid the pid of the resourcefragment to get the file-id from
 : @param $resource-pid the pid of the resource
 : @param $project-pid the pid of the project
~:)
declare function facs:generate($version-param as xs:string?, $resource-pid as xs:string, $project-pid as xs:string) as empty-sequence() {
    let $log := util:log-app("DEBUG",$config:app-name,"facs:generate $version-param := "||$version-param||" $resource-pid := "||$resource-pid||" $project-pid := "||$project-pid)
    let $fragments := resource:get($resource-pid, $project-pid)/mets:div[@TYPE=$config:PROJECT_RESOURCEFRAGMENT_DIV_TYPE],
        $version := ($version-param,config:param-value(project:get($project-pid),'facs.version'),$facs:default-version)[.!=''][1]
    (: we generate the first fragment outside of the for-in expression in order to make 
       sure it is instantly written to the project.xml :)
    return 
        if (count($fragments) > 0)
        then
            let $log := util:log-app("INFO",$config:app-name,"Generating "||count($fragments)||" facs entries for "||$resource-pid||" (project "||$project-pid||")")
            let $first :=
                let $resourcefragment-pid := $fragments[1]/@ID
                let $file :=facs:generate-file($version,$resourcefragment-pid,$resource-pid,$project-pid)
                return 
                   if (exists($file)) then facs:set($version,$file,$resourcefragment-pid,$resource-pid,$project-pid)
                   else ()
            return  
                for $f in $fragments[position() gt 1]
                    let $resourcefragment-pid := $f/@ID
                    let $file := facs:generate-file($version,$resourcefragment-pid,$resource-pid,$project-pid)
                return 
                   if (exists($file)) then facs:set($version,$file,$resourcefragment-pid,$resource-pid,$project-pid)
                   else ()
        else 
            let $log := util:log-app("INFO",$config:app-name,"not generating any facs entries - no fragments found in "||$resource-pid||" (project "||$project-pid||").")
            return ()
};



(:~
 : Gets one or more file-ids (filename(s) of facsimile(s) of a given resourcefragment.
 : NB This function is set to private as it is only needed once, when the filepaths 
 : are written to the mets project.
 : @param $resourcefragment-pid the pid of the resourcefragment to get the file-id from
 : @param $resource-pid the pid of the resource
 : @param $project-pid the pid of the project
 : @result one or more file-ids (filenames) 
~:)
declare %private function facs:id-by-resourcefragment($resourcefragment-pid as xs:string, $resource-pid as xs:string, $project-pid as xs:string) as xs:string?{
    let $log := util:log-app("TRACE",$config:app-name,"facs:id-by-resourcefragment("||$resourcefragment-pid||", "||$resource-pid||", "||$project-pid||")")
    let $rf := rf:get($resourcefragment-pid, $resource-pid,$project-pid)
    let $log := util:log-app("TRACE",$config:app-name,"$rf := "||substring(serialize($rf),1,240)),
        $log := util:log-app("TRACE",$config:app-name,$rf)
     (: let's get the element that the "resourcefragment-pid" index refers to in the full data. 
        (in the variable $fragment-elt-in-wc). 
        This indirection is necessary, as our "facs" index does not have to point to 
        a descendant of the resourcefragment, so that an expression like $rf/preceding::pb 
        will easily lead to strange results. :)       
    let $fragment-pid-in-rf-candidates := index:apply-index($rf,"rf",$project-pid), 
        $fragment-pid-in-rf:= $fragment-pid-in-rf-candidates/ancestor-or-self::*[@cr:id][1],
        $log := util:log-app("TRACE",$config:app-name,"$fragment-pid-in-rf := "||serialize($fragment-pid-in-rf)),
        $log := util:log-app("TRACE",$config:app-name, "$fragment-pid-in-rf-candidates := "||serialize($fragment-pid-in-rf-candidates)),
        $fragment-in-wc := wc:lookup($fragment-pid-in-rf/xs:string(@cr:id),$resource-pid,$project-pid)    
    (: ... then apply the "facs" index to the fragment-element in the working copy :)
    let $log := util:log-app("TRACE",$config:app-name,"$fragment-in-wc := "||serialize($fragment-in-wc))
    let $facs:= index:apply-index($fragment-in-wc,"facs",$project-pid)
    let $return := xs:string($facs)
    let $log := util:log-app("TRACE",$config:app-name,"facs:id-by-resourcefragment return "||$return)
    return $return
};


(:~
 : Generates the URL(s) to a facsimile of a resourcefragment, to be   
 : stored into a mets:file/mets:FLocat/@xlink:href. 
 : NB: We can hold more than one version of a facsmilie (thumbnail, web, archive etc.).
 : This stores the default version specified in the facs modules configuration. 
 : To generate a specific version, use the four-parameter version of this function.
 : This function is set to private as it is only needed once, when the filepaths 
 : are written to the mets project.
 : @param $file-id the id (or filename) of the facs, e.g. the value of pb/@facs 
 : @param $resourcefragment-pid the pid of the resource
 : @param $resource-pid the pid of the resource 
 : @param $project-pid the pid of the project
 : @return zero or more URLs (a resourcefragment may be split or span over more than one page)
~:)
declare %private function facs:generate-url($file-id as xs:string, $resourcefragment-pid as xs:string, $resource-pid as xs:string, $project-pid as xs:string) as xs:string* {
    facs:generate-url($file-id,(),$resourcefragment-pid, $resource-pid, $project-pid)
};

(:~
 : Generates the URL to a facsimile of a resourcefragment, to be   
 : stored into a mets:file/mets:FLocat/@xlink:href.
 : NB: We can hold more than one version of a facsmilie (thumbnail, web, archive etc.).
 : This stores the version indicated by parameter number 2.
 : NB This function is set to private as it is only needed once, when the filepaths 
 : are written to the mets project.
 : @param $file-id the id (or filename) of the facs, e.g. the value of pb/@facs
 : @param $version the version / qualitiy of the facsimile the URL has to point to. 
 : @param $resourcefragment-pid the pid of the resource
 : @param $resource-pid the pid of the resource 
 : @param $project-pid the pid of the project
 : @return zero or more URLs (a resourcefragment may be split or span over more than one page)
~:)
declare function facs:generate-url($file-id as xs:string, $version as xs:string?, $resourcefragment-pid as xs:string, $resource-pid as xs:string, $project-pid as xs:string) as xs:string* {
    let $log := util:log-app("TRACE",$config:app-name,"facs:generate-url file-id := "||$file-id)
    let $config := project:get($project-pid)
    let $facs:pattern:= repo-utils:config-value($config,"facs.url-pattern")
    let $log2 := util:log-app("TRACE",$config:app-name,"$facs:pattern := "||$facs:pattern)
    let $config-ok := 
        switch(true())
            case repo-utils:config-value($config,"facs.url-pattern")="" return (util:log-app("ERROR",$config:app-name,"config parameter facs.url-pattern missing in project "||$project-pid),false())
            (:case repo-utils:config-value($config,"facs.default")="" return (util:log-app("ERROR",$config:app-name,"config parameter facs.default missing in project "||$project-pid),false()):)
            case repo-utils:config-value($config,"facs.base-uri")="" return (util:log-app("ERROR",$config:app-name,"config parameter facs.base-uri missing in project "||$project-pid),false())
            default return true()
    let $return :=
        if ($config-ok)
        then 
            let $substrings := fn:analyze-string($facs:pattern,"\{\$([-.:\w]+)\}"),
                $keys:= $substrings//fn:group/xs:string(.),   
                $maps := 
                    for $k in $keys 
                    let $val := try {
                                    (util:eval("$"||$k),repo-utils:config-value($config,"facs."||$k))[1]
                                } catch  * {
                                    repo-utils:config-value($config,"facs."||$k)
                                }
                    let $log := util:log-app("TRACE",$config:app-name,$k||" => "||$val)
                    return map:entry($k,$val)
            let $params := map:new($maps)
            let $pattern-expanded := facs:generate-url-expandParams($substrings,$params) 
            return string-join($pattern-expanded,'')
        else util:log-app("INFO",$config:app-name,"Can't generate facsimile because of missing config parameters.")
    let $log := util:log-app("TRACE",$config:app-name,"facs:generate-url return "||$return)
    return $return
};

(:~
 : Helper function that replaces variable names in the url-pattern of the 
 : facs module config (param key "facs.url-pattern") with their actual values.
~:)
declare %private function facs:generate-url-expandParams($node as node(), $params as map()) as item()* {
    typeswitch($node)
        case element(fn:analyze-string-result) return 
                                                    for $n in $node/node() 
                                                    return facs:generate-url-expandParams($n, $params)
        case element(fn:match)      return facs:generate-url-expandParams($node/fn:group[1],$params)
        case element(fn:group)      return map:get($params,xs:string($node))
        case element(fn:non-match)  return xs:string($node)
        default                     return $node 
}; 


