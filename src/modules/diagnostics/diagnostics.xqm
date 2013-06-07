xquery version "3.0";
module namespace diag  = "http://www.loc.gov/zing/srw/diagnostic/";

declare namespace sru = "http://www.loc.gov/zing/srw/";

declare variable $diag:msgs := doc('diagnostics.xml');

declare function diag:diagnostics($key as xs:string, $param as xs:string) as item()? {
    
    let $diag := 
	       if (exists($diag:msgs//diag:diagnostic[@key=$key])) then
	               $diag:msgs//diag:diagnostic[@key=$key]
	           else $diag:msgs//diag:diagnostic[@key='general-error']
	   return
	       <sru:diagnostics>
	           { util:eval(util:serialize($diag,())) }
	       </sru:diagnostics>	   
};