xquery version "3.0";

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