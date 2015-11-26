xquery version "1.0";
declare namespace request="http://exist-db.org/xquery/request";
declare namespace util="http://exist-db.org/xquery/util";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare option exist:serialize "method=xml media-type=text/xml indent=yes"; 

(: this gets the data from the HTTP POST;  only on request:get-data() call possible:)
let $data := request:get-data()
let $post-data := $data//file
let $projectName := $data//projectName
let $fileName := data($data//file/@filename)
let $mediaType := data($data//file/@mediaType)
(: this converts the base-64 binary to a plaintext string that holds the unparsed XML content :)
let $xml := util:parse(util:base64-decode($post-data))
let $collection := concat("/db/cr-data/", $projectName, "/")
let $login := xmldb:login($collection, 'admin', '')
let $store := xmldb:store($collection, $fileName, $xml)
let $status := if($store!='') then
    "Resource was successfully saved"
    else
    "Ooops, something went wrong"

   return
   <data>
   <projectName>{$projectName}</projectName>
   <status>{$status}</status>
   <file>{$fileName}</file>
   <mediatype>{$mediaType}</mediatype>
   </data>