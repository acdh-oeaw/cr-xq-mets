
(:curl -o post-result.html -v -u '1013-01:Bew4Eicu' -H "Accept:application/json" -H "Content-Type:application/json" -X POST --data '[{"type":"URL","parsed_data":"http://clarin.aac.ac.at/cr/get/at.icltt.cr.dict-gate.1"}]' "http://pid.gwdg.de/handles/11022/"xquery version "3.0";:)

import module namespace httpclient="http://exist-db.org/xquery/httpclient";
import module namespace util="http://exist-db.org/xquery/util"; 

(:~ updateing existing  PIDs 
 : sample:
 : 
curl -o update-output.html -v -u '1013-01:xieS5ohg' -H "Accept:application/json" -H "Content-Type:application/json" -X PUT --data '[{"type":"URL","parsed_data":"http://clarin.aac.ac.at/cr/get/at.icltt.cr.dict-gate.3"}]' http://pid-test.gwdg.de/handles/11022/0000-0000-0029-2

 :  :)

(: credentials :)
declare variable $username := '1013-01';
declare variable $password := '';
 
declare variable $update  := true();
declare variable $baseurl  := 'http://clarin.aac.ac.at/cr/get/';
declare variable $id  := 'ccv';
(:declare variable $url  := concat($baseurl, $id);:)
declare variable $url  := "http://clarin.arz.oeaw.ac.at/acdh-repo/objects/acdh:7/datastreams/TEI_SOURCE/content";
declare variable $oldPID := "http://pid.gwdg.de/handles/11022/0000-0000-001D-0";
 
(: URI of the REST interface of eXist instance :)
declare variable $rest := 'http://pid-test.gwdg.de/handles/11022/';

(:   let $auth := concat("Basic ", util:base64-encode(concat($username, ':', $password))) :)
let $auth := concat("Basic ", util:string-to-binary(concat($username, ':', $password)))
let $headers := <headers><header name="Authorization" value="{$auth}"/>
                <header name="Content-Type" value="application/json"/> 
                        </headers>

let $data         := concat('[{"type":"URL","parsed_data":"', $url , '"}]')
  return if ($update) then 
                  httpclient:put(xs:anyURI($oldPID),
                             $data,
                             true(),
                             $headers)
          else
                  httpclient:post(xs:anyURI($rest),
                             $data,
                             true(),
                             $headers)