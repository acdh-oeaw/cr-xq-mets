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

import module namespace config="http://exist-db.org/xquery/apps/config" at "../../core/config.xqm";
import module namespace fcs-tests = "http://clarin.eu/fcs/1.0/tests" at  "tests.xqm"; 
(:import module namespace httpclient = "http://exist-db.org/xquery/httpclient";:)

declare namespace sru = "http://www.loc.gov/zing/srw/";
declare namespace fcs = "http://clarin.eu/fcs/1.0";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

(:let $target := "http://localhost:8681/exist/cr/"
let $testset-name := "test_connect"

let $tests := doc(concat("testsets/", $testset-name, ".xml"))//TestSet
:)
(:let $data := httpclient:get(xs:anyURI("http://localhost:8680/exist/rest/db/content_repository/scripts/cr.xql"), false(), () ) :)
(:let $store := xmldb:store("results", concat($testset-name, '.xml'), t:run-testSet($tests)) :)

 
(: t:run-testSet($tests)
t:format-testResult($store):)

(:  ?? :)
let $project := request:get-parameter("project","")
let $config := config:config($project) 
 
let $target := request:get-parameter("target", "0")
let $queryset := request:get-parameter("queryset", "0")
let $operation := request:get-parameter("operation", "overview")
let $messages := ""
return
    if ($operation eq "run" or $operation eq "run-store") then        
        let $run := fcs-tests:run-testset($target, $queryset, $operation, $config)
(:        return $run:)
        return fcs-tests:display-page($target, $queryset, $operation, $config)
    else
        fcs-tests:display-page($target, $queryset,$operation, $config)