xquery version "3.0";

declare namespace cr="http://aac.ac.at/content_repository";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace mets = "http://www.loc.gov/METS/";


(:import module namespace repo-utils="http://aac.ac.at/content_repository/utils" at "core/repo-utils.xqm";:)
import module namespace fcs="http://clarin.eu/fcs/1.0" at "modules/fcs/fcs.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "core/config.xqm"; 
import module namespace toc = "http://aac.ac.at/content_repository/toc" at "core/toc.xqm";

let $resource-pid := "abacus2.5",   
    $project-pid := "abacus2",
    $indexes := "chapter"
    
return toc:generate($indexes,$resource-pid,$project-pid)