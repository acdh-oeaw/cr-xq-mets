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

module namespace handle = "http://aac.ac.at/content_repository/handle";

import module namespace config="http://exist-db.org/xquery/apps/config" at "../../core/config.xqm";
import module namespace repo-utils="http://aac.ac.at/content_repository/utils" at "../../core/repo-utils.xqm";
import module namespace project="http://aac.ac.at/content_repository/project" at "../../core/project.xqm";
import module namespace resource="http://aac.ac.at/content_repository/resource" at "../../core/resource.xqm";

declare namespace httpclient="http://exist-db.org/xquery/httpclient";
declare namespace cmd = "http://www.clarin.eu/cmd/";
declare namespace xhtml = "http://www.w3.org/1999/xhtml";

declare function handle:credentials($project-pid) as map() {
    let $params : = config:config($project-pid)//module[@key='resource']/param,
        $service := $params[@key = 'pid-service'],
        $username := $params[@key = 'pid-username'],
        $password := $params[@key = 'pid-pwd']
    return 
        map{
            "service-url" := xs:string($service),
            "username" := xs:string($username),
            "password" := xs:string($password)
        }
};

(:~
 : Registers a new handle for the given uri.
 : @param $uri the URI to register
 : @param $project-pid The PID of the current project 
 :)
declare function handle:create($url as xs:string, $project-pid as xs:string) as xs:string? {
    let $data := concat('[{"type":"URL","parsed_data":"', $url , '"}]')
    let $response := handle:send($data,"create",(),$project-pid),
        $config := config:config($project-pid)
    return 
        if ($response/@statusCode="201")
        then 
            let $PID:=$response//xhtml:dl[@class='rackful-object'][xhtml:dt='location']/xhtml:dd/xhtml:a/text()
            return replace(config:param-value($config,"pid-resolver"),'/$','')||"/"||$PID
        else util:log-app("ERROR",$config:app-name,("There was an error creating a handle. Details below: ",$response))
};


(:~
 : Updates the target URI of a given handle.
 : @param $url the new URL
 : @param $handle-url the URL of the handle
 : @param $project-pid The PID of the current project 
 :)
declare function handle:update($url as xs:anyURI, $handle-url as xs:anyURI, $project-pid as xs:string) {
    let $config:= config:config($project-pid)
    let $data := concat('[{"type":"URL","parsed_data":"', $url , '"}]')
        (: extract the ID from the whole handle, 
           e.g. "0000-0000-2086-4" from "http://hdl.handle.net/11022/0000-0000-2086-4"  :)
    let $pid-local-part := replace(substring-after($handle-url,config:param-value($config,"pid-resolver")),'(^/|/$)',''),
        $rest-url:= replace(config:param-value($config,"pid-service"),'/$','')||"/"||$pid-local-part
    let $response := handle:send($data,"update",$rest-url,$project-pid)
    return 
        if ($response/@statusCode="204")
        then ()
        else util:log-app("ERROR",$config:app-name,("There was an error updating a handle. Details below: ",$response))
};

(:~
 : Removes a given handle.
 : @param $handle-url the URL of the handle
 : @param $project-pid The PID of the current project 
 :)
declare function handle:remove($handle-url as xs:anyURI, $project-pid as xs:string) {
    let $data := concat('[{"type":"URL","parsed_data":"', $url , '"}]')
    return handle:send((),"remove",$handle-url,$project-pid)
};


declare %private function handle:send($data as xs:string?, $action as xs:string, $handle-url as xs:string?, $project-pid as xs:string) {
(:    let $creds := handle:credentials($project-pid):)
    let $config := config:module-config()
    let $username := config:param-value($config,"pid-username")
    let $pwd := config:param-value($config,"pid-pwd")
    let $auth := concat("Basic ", util:string-to-binary(concat($username, ':', $pwd)))
    let $headers := <headers>
                        <header name="Authorization" value="{$auth}"/>
                        <header name="Content-Type" value="application/json"/>
                        <header name="Accept" value="application/xhtml+xml"/>
                    </headers>
    return 
        switch ($action)
            case "update" return 
                  httpclient:put(xs:anyURI($handle-url),
                             $data,
                             true(),
                             $headers)
            case "create" return
                  httpclient:post(xs:anyURI(config:param-value(config:module-config(),'pid-service')),
                             $data,
                             true(),
                             $headers)
            default return util:log-app("INFO",$config:app-name,"resource:register-handle(): method '"||$action||"' is not implemented.")
};


