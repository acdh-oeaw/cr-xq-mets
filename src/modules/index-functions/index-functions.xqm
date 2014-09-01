xquery version '3.0';
module namespace ixfn = "http://aac.ac.at/content-repository/projects-index-functions/"; 

(: default empty index function
 you need to call gen:generate-index-functions($x-context) to activate the project-specific index functions :)
 
declare function ixfn:apply-index($data as node()*, $index-name as xs:string, $x-context as xs:string, $type as xs:string?) as item()* {

    ()
};

