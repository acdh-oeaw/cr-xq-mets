xquery version "3.0";
(:~ This module provides methods to transform process (CQL) query
: @see http://clarin.eu/fcs 
: @author Matej Durco
: @since 2014-02-06
: @version 1.1 
:)
module namespace query  = "http://aac.ac.at/content_repository/query";

import module namespace cql = "http://exist-db.org/xquery/cql" at "cql.xqm";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at  "../../core/repo-utils.xqm";
import module namespace diag =  "http://www.loc.gov/zing/srw/diagnostic/" at  "../diagnostics/diagnostics.xqm";
import module namespace index = "http://aac.ac.at/content_repository/index" at "../../core/index.xqm";
declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare  namespace cr="http://aac.ac.at/content_repository";
declare namespace fcs = "http://clarin.eu/fcs/1.0";



declare function query:execute-query($cql as xs:string, $data as node()*, $project) as node()* {
    
    let $xpath := cql:cql-to-xpath($cql, $project)
    return util:eval("($data)//"||$xpath)
(:  return $xpath:)
    
};