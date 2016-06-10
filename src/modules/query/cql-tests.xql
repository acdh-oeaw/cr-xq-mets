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
import module namespace index = "http://aac.ac.at/content_repository/index" at "../../core/index.xqm";

import module namespace request="http://exist-db.org/xquery/request";

(:~ cql-tests :)

(:let $cql := request:get-parameter("cql", "title any Wien and date < 1950"):)
 let $map :=  <map xmlns="">
                        <namespaces>
                            <ns prefix="tei" uri="http://www.tei-c.org/ns/1.0"/>
                        </namespaces>
                        <map key="" path="" title="">
                            <index key="rf">
                                <path match="@xml:id" label="@n">pb</path>
                            </index>
                            <index key="fcs.rf" type="ft" >
                                <path match="@rf-pid" label="@rf-label">resourceFragment</path>
                            </index>
                            <index key="cql.serverChoice" type="ft">
                                <path>p</path>
                            </index>
                        </map>
                    </map>
 
 let $queries := <qs>
                <q cql="term1" expected-xpath='/descendant-or-self::p[ft:query(./.,&lt;query>&lt;phrase&gt;term1&lt;/phrase&gt;&lt;/query&gt;)]' />
                <q cql="rf = pb1" expected-xpath="/descendant-or-self::pb[./@xml:id='pb1']" />
                <q cql="fcs.rf = rf1" expected-xpath='/descendant-or-self::resourceFragment[ft:query(./@rf-pid,&lt;query&gt;&lt;phrase&gt;rf1&lt;/phrase>&lt;/query&gt;)]' />
                </qs>
 
 for $q at $pos in $queries/q
    let $cql := $q/xs:string(@cql)
    let $expected-xpath := $q/xs:string(@expected-xpath)
    let $xcql := cql:cql-to-xcql($cql)/*
    let $resolved-xpath := cql:process-xcql($xcql, $map)
    return if ($expected-xpath eq $resolved-xpath) then () else $expected-xpath||' != '||$resolved-xpath
(: return ( $resolved-xpath):)
    
    