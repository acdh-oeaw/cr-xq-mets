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
declare namespace cmd = "http://www.clarin.eu/cmd/";
declare namespace cr="http://aac.ac.at/content_repository";
declare namespace fcs = "http://clarin.eu/fcs/1.0";
declare namespace mets="http://www.loc.gov/METS/";


(:~ resolves query to xpath in the context of a project (applying custom mappings)
currently only passed further to the cql-module
but could in future also switch to other parsers/transformers
@param $q the query string (currently only CQL-syntax is supported)
@param 
:) 
declare function query:query-to-xpath($q as xs:string, $project) as xs:string? {
    
    let $xpath := cql:cql-to-xpath(replace($q,'&amp;','&amp;amp;'), $project)
    return $xpath
    
};

declare function query:query-to-xpath-map($q as xs:string, $map) as xs:string? {
    
    let $xpath := cql:cql-to-xpath(replace($q,'&amp;','&amp;amp;'), '', $map)
    return $xpath
    
};

(:~ lets the query translate into xpath in the context of a project (applying custom mappings)
and evaluates the xpath against the data passed as the second parameter
@param $q the query string (currently only CQL-syntax is supported)
:) 
declare function query:execute-query($q as xs:string, $data as node()*, $project) as node()* {
    
    let $xpath := query:query-to-xpath($q, $project)
    return util:eval("$data/"||$xpath)
(:  return $xpath:)
    
};

declare function query:execute-query-map($q as xs:string, $data as node()*, $map) as node()* {
    let $xpath := query:query-to-xpath-map($q, $map)
        return util:eval("$data/"||$xpath)
};