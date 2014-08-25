xquery version '3.0';
module namespace ixfn = "http://aac.ac.at/content-repository/projects-index-functions/"; 

import module namespace ixfn-abacus='http://aac.ac.at/content-repository/projects-index-functions/abacus' at '/db/cr-projects/abacus/modules/index-functions.xqm';
 import module namespace ixfn-dict-gate='http://aac.ac.at/content-repository/projects-index-functions/dict-gate' at '/db/cr-projects/dict-gate/modules/index-functions.xqm';

(: default empty index function
 you need to call gen:generate-index-functions($x-context) to activate the project-specific index functions :)
 
declare function ixfn:apply-index($data as node()*, $index-name as xs:string, $x-context as xs:string, $type as xs:string?) as item()* {
    ()
};

