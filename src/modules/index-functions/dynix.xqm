
xquery version '3.0';
module namespace dynix = "http://cr-xq/dynix"; 

declare namespace tei = 'http://www.tei-c.org/ns/1.0';
 declare namespace mets = 'http://www.loc.gov/METS/';
 declare namespace fcs = 'http://clarin.eu/fcs/1.0';
 declare namespace cr = 'http://aac.ac.at/content_repository';


(:~ this is a default version of the dynix-module. it should be replaced by a version generated out of the project configurations
    rendered as xquery where for every index appropriate xpath is applied on the $data parameter.
    this is to circumvent excessive use of util:eval() - which blows the memory usage.    
  @seeAlso generate-mappings-functions
 :)
declare function dynix:apply-index($data as node()*, $index-name as xs:string, $x-context as xs:string, $type as xs:string?) as item()* {
   
   util:eval('$data//'||$index-name)  
};

