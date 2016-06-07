xquery version "1.0";

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

import module namespace request="http://exist-db.org/xquery/request";
import module namespace config="http://exist-db.org/xquery/apps/config" at "../../core/config.xqm";
import module namespace crday  = "http://aac.ac.at/content_repository/data-ay" at "crday.xqm";
import module namespace diag =  "http://www.loc.gov/zing/srw/diagnostic/" at  "modules/diagnostics/diagnostics.xqm";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at  "../../core/repo-utils.xqm";

let $config-path := request:get-parameter("config", "/db/cr/conf/cr/config.xml"),
    $op := request:get-parameter("operation", ""),
(:    $config := doc($config-path),
    $config := repo-utils:config($config-path), :) 
    $project := request:get-parameter("project",""),
    $config := config:config($project),
    $format := request:get-parameter("x-format",'htmlpage'),
    $x-context := request:get-parameter("x-context", "") (: "univie.at:cpas"  "clarin.at:icltt:cr:stb" :),

    $result := if ($op eq '') then 
                        crday:display-overview($config)
               else if (contains ($op, 'query')) then
                    crday:get-query-internal($config, $x-context, (contains($op, 'run')), $format)                    
               else if (contains ($op, 'scan-fcs-resource')) then
                    crday:get-fcs-resource-scan($config-path, (contains($op, 'run')), $format)                    
               else if (contains ($op, 'struct')) then
                    let $init-path := request:get-parameter("init-path", ""),              
                        $max-depth := request:get-parameter("x-maximumDepth", $crday:defaultMaxDepth)
                     return crday:get-ay-xml($config, $x-context, $init-path, $max-depth, (contains($op, 'run')), $format)                    
                else 
                    diag:diagnostics("unsupported-operation", $op)
return $result

