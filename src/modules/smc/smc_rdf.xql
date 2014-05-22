xquery version "3.0";

declare namespace cmd = "http://www.clarin.eu/cmd/";

(:collection("/db/mdrepo-data")//cmd:Components[not(*)]:)
(:config:param-value($config,'base-url'):)
(: xmldb:get-current-user():)
 
(: http://clarin.oeaw.ac.at/lrp/get/dict-gate.2/metadata/CMDI:)
 let $md-record-pid := request:get-parameter("pid","http://clarin.oeaw.ac.at/lrp/get/dict-gate.2/metadata/CMDI")
(: let $md-record := (collection("/db/mdrepo-data")/cmd:CMD)[1]:)
 let $md-record := collection("/db/mdrepo-data")//cmd:MdSelfLink[. eq 'oai:ehu-upv:aholab:ahopolar' ]/ancestor::cmd:CMD
  
(: (collection("/db/mdrepo-data")/cmd:CMD)[1]:)
 let $xslt := doc ("/db/apps/cr-xq/modules/smc/rdf/CMDRecord2RDF.xsl")
(: doc("):)
 return  doc-available('oai:ehu-upv:aholab:ahopolar')
 
(: return if (not($md-record-pid="")) then transform:transform(doc($md-record-pid), $xslt, ()):)
(:                else <html><body>no record pid</body></html>:)
(: :)
 