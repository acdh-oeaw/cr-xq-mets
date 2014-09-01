xquery version '3.0';
module namespace ixfn = "http://aac.ac.at/content-repository/projects-index-functions/"; 

import module namespace ixfn-abacus='http://aac.ac.at/content-repository/projects-index-functions/abacus' at '/db/cr-projects/abacus/modules/index-functions.xqm';
 import module namespace ixfn-dict-gate='http://aac.ac.at/content-repository/projects-index-functions/dict-gate' at '/db/cr-projects/dict-gate/modules/index-functions.xqm';


declare function ixfn:apply-index($data as node()*, $index-name as xs:string, $x-context as xs:string, $type as xs:string?) as item()* {
switch ($x-context)
	case 'abacus' return ixfn-abacus:apply-index($data, $index-name, $x-context, $type)
	case 'dict-gate' return ixfn-dict-gate:apply-index($data, $index-name, $x-context, $type)
	default return ()
};

