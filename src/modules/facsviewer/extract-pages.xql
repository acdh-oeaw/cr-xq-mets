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

import module namespace facs="http://www.oeaw.ac.at/icltt/cr-xq/facsviewer" at "facsviewer.xqm";
(:import module namespace jobs="http://www.oeaw.ac.at/icltt/cr-xq/jobs" at "../jobs/jobs.xqm";:)
import module namespace diag  = "http://www.loc.gov/zing/srw/diagnostic/" at "../diagnostics/diagnostics.xqm";

(: extracts pages from a TEI doc (ie. chunks between tei:pb tags) and saves them into a new TEI file :)


let $doc-uri := request:get-parameter('doc-uri',''),
    $page-elt := request:get-parameter('page-element',''),
    $page-elt-ns := request:get-parameter('page-element-namespace',''),
    $page-elt-attr := request:get-parameter('page-element-attributes','')

(:let $pid:= request:get-parameter('pid',''),
    $pid-file:= jobs:pid-file-by-doc-uri($doc-uri):)
    

return 
    if ($doc-uri eq '')
    then diag:diagnostics('param-missing','doc-uri')
    else
(:        if ($pid-file/pid eq $pid):)
(:        then :)
        if ($page-elt != '')
        then facs:create-scratchfile($doc-uri)
        else facs:create-scratchfile($doc-uri,$page-elt,$page-elt-ns,$page-elt-attr) 
(:        else ():)