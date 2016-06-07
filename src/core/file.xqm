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

module namespace f="http://aac.ac.at/content_repository/file";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at "repo-utils.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
(:import module namespace master = "http://aac.ac.at/content_repository/master" at "master.xqm";:)
import module namespace project = "http://aac.ac.at/content_repository/project" at "project.xqm";

declare namespace mets="http://www.loc.gov/METS/";
declare namespace xlink="http://www.w3.org/1999/xlink";


declare function f:get-file-entry($file-id, $project) as element(mets:file)? {
    project:get($project)//mets:file[@ID eq $file-id]
};

declare function f:set-file-entry($file-id, $filepath, $use-type as xs:string, $filegrp-id as xs:string, $project) as element(mets:file)? {
    f:set-file-entry($file-id, $filepath, $use-type, 'application/xml', $filegrp-id, $project)
};

(:~ 
 : insert or replace an entry for a mets:file
 : also creates corresponding mets:fileGrp if necessary
~:)
declare function f:set-file-entry($file-id, $filepath as xs:string, $use-type as xs:string, $mime-type as xs:string, $filegrp-id as xs:string, $project) as element(mets:file)? {
    let $mets:file-entry := f:get-file-entry($file-id, $project)

    let $file-entry-new := <mets:file ID="{$file-id}" MIMETYPE="{$mime-type}" USE="{$use-type}">
                        <mets:FLocat LOCTYPE="URL" xlink:href="{$filepath}"/>
                    </mets:file>
    
  
  let $log := util:log("DEBUG", "set-file-entry: "||$file-id||" count: "||count($file-entry-new))
  
  
    let $mets:filegrp:=f:set-filegrp-entry($filegrp-id, $project)
  let $log := util:log("DEBUG", "set-file-entry filegrp: "||$filegrp-id||" count: "||count($mets:filegrp))  
    let $update := 
        if (exists($mets:file-entry))
        then (update delete $mets:file-entry, update insert $file-entry-new into $mets:filegrp)
        else update insert $file-entry-new into $mets:filegrp
   let $log := util:log("DEBUG", "set-file-entry file set: "||$file-id||" count: "||count($mets:filegrp/mets:file))
    return $mets:filegrp/mets:file[@ID eq $file-id]
};

(:~ 
 : insert an entry for a mets:fileGrp
 : don't do anything if fileGrp with given id already exists
 : @returns matching fileGrp
~:)
declare function f:set-filegrp-entry($filegrp-id as xs:string, $project) as element(mets:fileGrp)? {
let $mets:filegrp := f:get-filegrp-entry($filegrp-id, $project) 

return if (exists($mets:filegrp)) then 
            $mets:filegrp
        else
            let $filesec := project:get($project)//mets:fileSec
            let $filegrp-new := <mets:fileGrp ID="{$filegrp-id}" />        
            let $update := update insert $filegrp-new into $filesec
            return $filesec/mets:fileGrp[@ID=$filegrp-id]
      
};

(:~  retrieve a mets:fileGrp entry from a project mets-file 
:)
declare function f:get-filegrp-entry($filegrp-id as xs:string, $project) as element(mets:fileGrp)? { 
 project:get($project)//mets:fileGrp[@ID=$filegrp-id]
};
