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

module namespace crxq-rest="http://aac.ac.at/content_repository/REST";

import  module namespace cr="http://aac.ac.at/content_repository" at "core/cr.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "core/config.xqm";
import module namespace repo-utils="http://aac.ac.at/content_repository/utils" at "repo-utils.xqm";

(:~ delivers a sequence of resources or resourcefragments based on the ids requested
 : does not return full project collection, if project-id is requested, the response is empty 
 :)
(:declare
    %rest:GET
    %rest:path("/cr-xq/get-data/{$ids}")
function crxq-rest:get-data($ids as xs:string){
    let $data := cr:resolve-id-to-data($ids,false())
    return <cr:response count="{count($data)}">{$data}</cr:response>
};    

declare
    %rest:GET
    %rest:path("/cr-xq/get-entry/{$ids}")
function crxq-rest:get-entry($ids as xs:string){
    let $data := cr:resolve-id-to-entry($ids)
    return <cr:response count="{count($data)}">{$data}</cr:response>
};
    :)
    
    
    
