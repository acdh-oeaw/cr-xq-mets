xquery version "3.0";

import module namespace http="http://expath.org/ns/http-client";
declare namespace xlink="http://www.w3.org/1999/xlink";
declare namespace mets="http://www.loc.gov/METS/";

(:~
 : This XQuery Script acts as a simple proxy which requests 
 : a given img resource via http (remote or local), giving the possibility  
 : to add complex authorization setups etc. not to be visible from 
 : within the eXist-context.
 :
 : @param resource the resource to be fetched from remote server in the form "ob"
 : @param debug return http response as content or just header information (default='no')  
~:)

let $url:=request:get-parameter('url',''),
    $token:=request:get-parameter($url||'-token',''),
    $client-ip:=request:get-remote-addr(),
(:  :    $user:=session:get-attribute($url||"-username"),
    $pw:=session:get-attribute($url||"-password"), :)
    $user:='',
    $pw:='',
    $auth-type:=request:get-parameter('auth-method','basic'),
    $send-authorization:=request:get-parameter('send-authorization','false')
let $debug:=request:get-parameter('debug','no')

let $request:=  <http:request 
                    href="{$url}" 
                    method="get"
                >{
                    if ($user!='' and $pw!='')
                    then 
                        (attribute username {$user},
                        attribute password {$pw},
                        attribute auth-method {$auth-type},
                        attribute send-authorization {$send-authorization})
                    else ()
                    
                }</http:request>
let $response:= 
    if ($token = xs:string(session:get-attribute($url||"-token"))) 
    then http:send-request($request) 
    else <error>Proxying only allowed for localhost.</error>
let $response-header:=$response[1][self::http:response]
let $response-content:=$response[2]
let $clean-session := (
    session:remove-attribute($url||"-username"),
    session:remove-attribute($url||"-password"),
    session:remove-attribute($url||"-token")
)
return
    if ($debug = 'yes')
    then 
        <debug>
            
            {($url,$request,$response-header)}
            <client-ip>{$client-ip}</client-ip>
            {for $p in request:get-parameter-names()
            return <param name="{$p}" value="{request:get-parameter($p,'')}"/>}
        </debug>
    else
        if ($response-header/@status = '200')
        then 
            if ($response-content instance of xs:base64Binary)
            then response:stream-binary(
                    $response-content,
                    xs:string($response-header/http:body/@media-type)
                  )
             else $response-content
        else
            let $set-status:=
                if(exists($response-header))
                then response:set-status-code($response-header/@status)
                else ()
            return
                <html xmlns="http://www.w3.org/1999/xhtml">
                    <head>
                        <title>srrrry ... </title>
                    </head>
                    <body>
                        <p>There was a problem:</p>
                        <p>msg: <i>{data(($response-header/@message,$response))}</i></p>
                    </body>
                </html>
                