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

try{
    let $source  := request:get-parameter("source","/db/apps/cr-xq-mets")
    let $target-base := request:get-parameter("target-base","/opt/repo")
    let $cr-xq-mets-log :=  file:sync($source, $target-base||"/cr-xq-mets/src", ()) 
    let $cs-xsl-log :=  file:sync($source||"/modules/cs-xsl", $target-base||"/cs-xsl", ()) 
(:    return ($cr-xq-mets-log, $cs-xsl-log):)
    let $cr-projects :=  file:sync("/db/cr-projects/", $target-base||"/cr-projects-mets/", ()) 
    return ($cr-xq-mets-log, $cs-xsl-log, $cr-projects)
    
    
} catch * {
    let $log := util:log("ERROR", ($err:code, $err:description) )
    return <ERROR>{($err:code, $err:description)}</ERROR>
(:    let $col := "/db/apps/cr-xq-dev0913":)
(:    let $target := "/opt/repo/SADE/src":)
(:    return file:sync($col, $target, ())  :)
}   