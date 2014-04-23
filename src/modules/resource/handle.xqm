xquery version "3.0";
module namespace handle = "http://aac.ac.at/content_repository/handle";

import module namespace config="http://exist-db.org/xquery/apps/config" at "../../core/config.xqm";
import module namespace repo-utils="http://aac.ac.at/content_repository/utils" at "../../core/repo-utils.xqm";
import module namespace project="http://aac.ac.at/content_repository/project" at "../../core/project.xqm";
import module namespace resource="http://aac.ac.at/content_repository/resource" at "../../core/resource.xqm";

declare namespace cmd = "http://www.clarin.eu/cmd/";

declare function handle:credentials($project-pid) as map() {
    let $params : = config:config($project-pid)//module[@key='resource']/param,
        $service := $params[@key = 'pid-service'],
        $username := $params[@key = 'pid-username'],
        $password := $params[@key = 'pid-pwd']
    return 
        map{
            "service-url" := $service,
            "username" := $username,
            "password" := $password
        }
};

(:~
 : Registers a new handle for the given uri.
 : @param $uri the URI to register
 : @param $project-pid The PID of the current project 
 :)
declare function handle:create($url as xs:string, $project-pid as xs:string) as xs:string {
    let $data := concat('[{"type":"URL","parsed_data":"', $url , '"}]')
    return handle:send($data,"create",(),$project-pid)
};


(:~
 : Updates the target URI of a given handle.
 : @param $url the new URL
 : @param $handle-url the URL of the handle
 : @param $project-pid The PID of the current project 
 :)
declare function handle:update($url as xs:anyURI, $handle-url as xs:anyURI, $project-pid as xs:string) {
    let $data := concat('[{"type":"URL","parsed_data":"', $url , '"}]')
    return handle:send($data,"update",$handle-url,$project-pid)
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
    let $creds := handle:credentials($project-pid)
    let $auth := concat("Basic ", util:string-to-binary(concat($creds("username"), ':', $creds("password"))))
    let $headers := <headers>
                        <header name="Authorization" value="{$auth}"/>
                        <header name="Content-Type" value="application/json"/> 
                    </headers>
    return 
        switch ($action)
            case "update" return 
                  httpclient:put(xs:anyURI($handle-url),
                             $data,
                             true(),
                             $headers)
            case "create" return
                  httpclient:post(xs:anyURI($handle-url),
                             $data,
                             true(),
                             $headers)
            default return util:log-app("INFO",$config:app-name,"resource:register-handle(): method '"||$method||"' is not implemented.")
};


