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

declare namespace mets = "http://www.loc.gov/METS/";
declare namespace xlink = "http://www.w3.org/1999/xlink";

import module namespace config="http://exist-db.org/xquery/apps/config" at "../../core/config.xqm";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at "../../core/repo-utils.xqm";
import module namespace f = "http://aac.ac.at/content_repository/file" at "../../core/file.xqm";
import module namespace project = "http://aac.ac.at/content_repository/project" at "../../core/project.xqm";
import module namespace viewer = "http://sade/viewer" at "viewer.xqm" ;
import module namespace get = "http://aac.ac.at/content_repository/get" at "get.xqm";

let $project := request:get-parameter("project","")

let $mets := project:get($project)
let $config-map := if ($project!='' and exists($mets)) then config:config-map($project) else () 

(:~ process the relative path; expecting one or two components:
first component $id, second optional: $type :)
let $path := request:get-parameter("rel-path",""),
    $log := util:log-app("DEBUG", $config:app-name, '$path = '||$path),
    $path-parsed := get:parse-relPath($path, $project)

let $id := $path-parsed("id"),
    $type := $path-parsed("type"),
    $subtype := $path-parsed("subtype"),
    $path-components := $path-parsed("path-components")
    
let $parse-id := if (exists($config-map)) then repo-utils:parse-x-context($id,$config-map) else ()
    

(: content negotiation
text/html -> human readable 
application/x-cmdi+xml -> machine processable 
@seeAlso http://www.clarin.eu/sites/default/files/CE-2013-0106-pid-task-force.pdf
:)
let $header-accept := request:get-header("Accept")
let $accept-format := if (contains($header-accept,'text/html')) then "htmlpage" else "xml" 
let $format := (request:get-parameter("x-format",if ($type = "data") then "xml" else $accept-format))[1]
(:return <debug>{$header-accept||" -- format: "||$format}</debug>:)
let $debug := <a>
        <path-components>{
            for $c at $pos in $path-components 
            return <path-component n="{$pos}">{$path-components[$pos]}</path-component>
        }</path-components>
        <project>{$project}</project>
        <id>{$id}</id>
        <type>{$type}</type>
        <subtype>{$subtype}</subtype>
        <format>{$format}</format>
        <context-parsed>{for $i in $parse-id return for $k in map:keys($i) return $k||":"||map:get($i,$k)}</context-parsed> 
       </a>
let $log := util:log-app("DEBUG",$config:app-name,$debug)
return
    (: TODO replace responses with proper diagnostics :)
    switch(true())
        case ($project = '') return <response status="">unspecified project</response>
        case (not($mets instance of element(mets:mets))) return <response status="">unknown project {$project}</response>
        (:case (not($parse-id[1] instance of map())) return <response status="">unknown project, resource, resource fragment or file ID (unresolvable context "{$id}")</response>:)
        case ($id = '') return <response status="">no id specified</response>
        case ($type = 'download') return     
            let $entry := f:get-file-entry($id, $project),
                $downloadable := some $f in $entry/ancestor::mets:fileGrp satisfies $f/@ID = 'downloads'
            let $filepath := $entry/mets:FLocat/xs:string(@xlink:href)
            return 
                switch (true())
                    case (not($entry)) return <response status="400">unknown item with id {$id}</response>
                    case (not($downloadable)) return <response status="400">item with id {$id} cannot be downloaded</response>
                    case ($filepath='') return <response status="400">unknown location of item with id {$id}</response>
                    default return 
                if (util:is-binary-doc($filepath))
                then 
                    if (util:binary-doc-available($filepath))
                    then
                        let $filename := util:document-name($filepath)
                        let $header := response:set-header( "Content-Disposition", concat ("attachment; filename=", $filename))
                        let $data := util:binary-doc($filepath)
                        return response:stream-binary(xs:base64Binary($data),xmldb:get-mime-type(xs:anyURI($filepath)),$filename)
                    else 
                        (: replace with diagnostics :)
                        <response status="400">data for item {$id} could not be located</response>
                else 
                    if (doc-available($filepath))
                    then 
                        let $filename := util:document-name($filepath)
                        let $header := response:set-header( "Content-Disposition", concat ("attachment; filename=", $filename))
                        let $data := doc($filepath)
                        return response:stream($data,"method=xml")
                    else 
                        (: replace with diagnostics :)
                        <response status="400">data for item {$id} could not be located</response>
        default return viewer:display($config-map, $id, map:get($parse-id[1],"project-pid"), $type, $subtype, $format)