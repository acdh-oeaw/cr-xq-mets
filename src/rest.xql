xquery version "3.0";
module namespace crxq-rest="http://aac.ac.at/content_repository/REST";

import  module namespace cr="http://aac.ac.at/content_repository" at "core/cr.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "core/config.xqm";
import module namespace repo-utils="http://aac.ac.at/content_repository/utils" at "repo-utils.xqm";

(:~ delivers a sequence of resources or resourcefragments based on the ids requested
 : does not return full project collection, if project-id is requested, the response is empty 
 :)
declare
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
    
    
    
    
