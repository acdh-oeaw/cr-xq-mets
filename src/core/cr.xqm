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

module namespace cr="http://aac.ac.at/content_repository";

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace repo-utils="http://aac.ac.at/content_repository/utils" at "repo-utils.xqm";
import module namespace project="http://aac.ac.at/content_repository/project" at "project.xqm";
import module namespace resource="http://aac.ac.at/content_repository/resource" at "resource.xqm";

declare namespace xlink="http://www.w3.org/1999/xlink";
declare namespace mets = "http://www.loc.gov/METS/";
declare namespace fcs = "http://clarin.eu/fcs/1.0";
declare namespace mods="http://www.loc.gov/mods/v3";
declare namespace metsrights = "http://cosimo.stanford.edu/sdr/metsrights/";
declare namespace sm="http://exist-db.org/xquery/securitymanager";


declare function cr:project-pids(){
    let $projects:=collection(config:path("projects"))//mets:mets[@TYPE eq "cr-xq project"]
    return
        <cr:projects n="{count($projects)}">{
            for $p in $projects
            return <cr:project project-pid="{$p/@OBJID}">{$p//mets:dmdSec[@ID eq $config:PROJECT_DMDSEC_ID]}</cr:project>
        }</cr:projects>
};

(:~ This function returns a node set consisting of all available documents of the project as listed in mets:fileGrp[@USE="Project Data"]     
 : 
 : @param $x-context: a ,-separted sequence of identifiers
~:)

declare function cr:resolve-id-to-data($x-context as xs:string, $also-project as xs:boolean ) as item()* {
    let $projects:=config:path("projects"),
        $rf-coll := collection(config:path('resourcefragments')),
    	$contexts:=tokenize($x-context,",")
    	
    let $data :=  
        for $c in $contexts
    	let $id := normalize-space($c),
    		$entry:= cr:resolve-id-to-entry($id),
    		$is-project := ($entry instance of element(mets:mets))
    	return
    	    if ($is-project) then
    	       if ($also-project) then 
        	       let $project-pid := $entry/xs:string(@OBJID) 
        		   (: go file by file:
        		   let $files := $entry//mets:file[@USE = $config:RESOURCE_WORKINGCOPY_FILE_USE]
        	       return $files/mets:FLocat!concat("doc('",./@xlink:href,"')")
        	       VS. go for whole collection :)
                   return collection(project:path($project-pid,"workingcopies"))
                else ()
    	    else 
    	       let $project-pid := root($entry)/mets:mets/xs:string(@OBJID)
    	       return if ($entry/xs:string(@TYPE) ='resource') then resource:get-data($id, $project-pid,'workingcopy')
    	       else $rf-coll//fcs:resourceFragment[@resourcefragment-pid eq $id]                
    
(:    return util:eval("("||string-join($paths,',')||")"):)
    return $data
};


declare function cr:resolve-id-to-data($x-context as xs:string) as item()* {
        cr:resolve-id-to-data($x-context, true())
};


declare function cr:context-to-fragments($x-context as xs:string) as item()* {
    let $projects:=config:path("projects"),
    	$contexts:=tokenize($x-context,",")
    let $paths :=  
        for $c in $contexts
    	let $id := normalize-space($c),
    		$div:= collection($projects)//mets:div[@ID eq $id],
    		$project := if (exists($div)) then () else collection($projects)//mets:mets[@OBJID eq $id],
    		$fileid := ($div/mets:fptr/@FILEID,$div/mets:fptr/mets:area/@FILEID),
    		$data-file := root($div)//mets:file[@ID = $fileid][@USE = ($config:RESOURCE_WORKINGCOPY_FILE_USE,$config:RESOURCE_RESOURCEFRAGMENTS_FILE_USE)][ancestor::mets:fileGrp[@ID eq $config:PROJECT_DATA_FILEGRP_ID]],
    		$uri := $data-file/mets:FLocat/@xlink:href,
    		$fileptr := $fileid[. = $data-file/@ID]/parent::*
    	return
    	    if (exists($project))
    	    then 
    	       let $files := $project//mets:file[@USE = $config:RESOURCE_WORKINGCOPY_FILE_USE]
    	       return $files/mets:FLocat!concat("doc('",./@xlink:href,"')")
    	    else 
           	    if ($fileptr/self::mets:area)
           	    then "doc('"||$uri||"')//fcs:ResourceFragment[@resourcefragment-pid='"||$fileptr/@BEGIN||"']"
           	    else "doc('"||$uri||"')"
(:    return util:eval("("||string-join($paths,',')||")"):)
    return $paths
};

(:~ tries to resolve an id, irrespective if it identifies a project a resource or a resourcefragment
and return the appropriate mets:entry (mets:mets or mets:div)
:)

declare function cr:resolve-id-to-entry ($x-context as xs:string) as element()* {

    let $contexts:=tokenize($x-context,",")
    
    for $c in $contexts
        let $id := normalize-space($c),
            $project := project:get($id),	
            $mets := if (exists($project)) then $project
                        else collection(config:path("projects"))//mets:div[@ID eq $id]                     
            return $mets

};

(:~ delivers the project-config for any id (project, resource, resourcefragment) :)
declare function cr:resolve-id-to-project ($x-context as xs:string) as element(mets:mets)* {

    let $metss := cr:resolve-id-to-entry($x-context)
    
    for $mets in $metss        	
            let $project := if ($mets instance of element(mets:mets)) then $mets
                        else root($mets)/mets:mets                     
            return $project
};

(:~ delivers the project-config for any id (project, resource, resourcefragment) :)
declare function cr:resolve-id-to-project-pid ($x-context as xs:string) as xs:string* {
    let $project := cr:resolve-id-to-project($x-context)
    return distinct-values($project/xs:string(@OBJID))
};
(::)
(::)
(:declare function cr:resolve-id-to-data ($id as xs:string) as item()* {:)
(::)
(:let $entry := cr:resolve-id-to-entry($id):)
(:let $rf-path := config:path('resourcefragments'),:)
(:    $wc-path := config:path('workingcopies'),:)
(:    $rf-coll := collection($rf-path):)
(::)
(:let $data := switch (true()):)
(:              case ($entry instance of element(mets:mets)) return collection(project:path($project-pid,"workingcopies")):)
(:              case ($entry/xs:string(@TYPE) eq 'resource') return:)
(:                                                let $project-id := $entry//ancestor::mets:mets/xs:string(@OBJID):)
(:                                                return resource:get-data($id, $project-id, 'workingcopy'):)
(:              case ($entry/xs:string(@TYPE) eq 'resourcefragment') return $rf-coll//fcs:resourceFragment[ft:query(@resourcefragment-pid, $id)]:)
(:              default return ():)
(:  return $data         :)
(:};:)