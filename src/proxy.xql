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
    $user:=session:get-attribute($url||"-username"),
    $pw:=session:get-attribute($url||"-password"),
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
            {$response-header}
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
                