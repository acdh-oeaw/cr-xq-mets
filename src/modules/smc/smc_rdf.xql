xquery version "3.0";

(:
The MIT License (MIT)

Copyright (c) 2016 Austrian Centre for Digital Humanities at the Austrian Academy of Sciences

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE
:)

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
 