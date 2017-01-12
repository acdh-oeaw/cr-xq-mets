xquery version "3.0";

import module namespace test="http://exist-db.org/xquery/xqsuite" at "/db/apps/cr-xq-mets/modules/test/xqsuite.xqm";
import module namespace qix-tests = "http://aac.ac.at/content_repository/qix/tests" at "query-index-tests.xqm";

let $modules := ( 
    xs:anyURI("/db/apps/cr-xq-mets/modules/query/query-index-tests.xqm")), 
    $functions := $modules ! inspect:module-functions(.) 
return 
    test:suite($functions) 