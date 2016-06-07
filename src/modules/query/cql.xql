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

import module namespace cql = "http://exist-db.org/xquery/cql" at "cql.xqm";
import module namespace query  = "http://aac.ac.at/content_repository/query" at "query.xqm";
import module namespace index = "http://aac.ac.at/content_repository/index" at "../../core/index.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "../../core/config.xqm"; 
import module namespace repo-utils="http://aac.ac.at/content_repository/utils" at "../../core/repo-utils.xqm";

import module namespace request="http://exist-db.org/xquery/request";

(:let $cql := request:get-parameter("cql", "title any Wien and date < 1950"):)
 
 let $cql := 'term1'
 let $xcql := cql:cql-to-xcql($cql)
 let $project-pid := 'abacus2'
 let $config :=  config:config($project-pid) 
let $model := map { "config" := $config, "project" := $project-pid }
 let $map := index:map($project-pid)
 let $xpath := cql:cql-to-xpath($xcql, $project-pid)
(:return $xcql:)
let $index-key := $xcql//index/text(),        
        $index := index:index-from-map($index-key ,$map),
        $index-type := ($index/xs:string(@type),'')[1]
(:    return $index-key:)

let $data-collection := repo-utils:context-to-collection($project-pid, $config)

(:return query:execute-query($xpath,$data-collection, $project-pid ):)
 return util:eval(concat("($data)//", $xpath))


  
