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

import module namespace smc  = "http://clarin.eu/smc" at "smc.xqm";
import module namespace crday  = "http://aac.ac.at/content_repository/data-ay" at "../aqay/crday.xqm";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at  "../../core/repo-utils.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "/db/apps/cr-xq/core/config.xqm";
import module namespace diag =  "http://www.loc.gov/zing/srw/diagnostic/" at  "modules/diagnostics/diagnostics.xqm";
 (:  import module namespace cmdcheck  = "http://clarin.eu/cmd/check" at "/db/cr/modules/cmd/cmd-check.xqm"; :)

declare namespace cmd = "http://www.clarin.eu/cmd/";

let $dcr-cmd-map := doc("/db/apps/cr-xq/modules/smc/data/dcr-cmd-map.xml")
let $xsl-smc-op := doc("/db/apps/cr-xq/modules/smc/xsl/smc_op.xsl")

let $format := request:get-parameter("x-format",'htmlpage'),
    $op := request:get-parameter("operation", ""),
    $mode := request:get-parameter("mode", "") (: refresh :)

let $x-context := "mdrepo",
    $config := config:config($x-context)


let $result := if (contains ($op, 'mappings-overview')) then                    
                    smc:mappings-overview($config, $format)
                else if ($op = 'gen-mappings') then                
                    smc:gen-mappings($config, $x-context, ($mode eq 'refresh'), 'raw') 
                else if (contains ($op, 'gen-graph')) then                    
                    smc:gen-graph($config, $x-context)                
                else 
                    diag:diagnostics("unsupported-operation", $op)


return $result