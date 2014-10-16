xquery version "3.0";
module namespace qix-tests = "http://aac.ac.at/content_repository/qix/tests";

(:~ tests for index and query translation :)


import module namespace cql = "http://exist-db.org/xquery/cql" at "cql.xqm";
import module namespace query = "http://aac.ac.at/content_repository/query" at "query.xqm";
import module namespace index = "http://aac.ac.at/content_repository/index" at "../../core/index.xqm";

(:import module namespace test="http://exist-db.org/xquery/xqsuite" at "resource:org/exist/xquery/lib/xqsuite/xqsuite.xql";:)
import module namespace test="http://exist-db.org/xquery/xqsuite" at "/db/apps/cr-xq-mets/modules/test/xqsuite.xql";


declare namespace cr="http://aac.ac.at/content_repository";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace mets = "http://www.loc.gov/METS/";
declare namespace xlink = "http://www.w3.org/1999/xlink";
declare namespace sru = "http://www.loc.gov/zing/srw/";


declare variable $qix-tests:map :=  <map xmlns="">
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
                                <index key="persName" label="Personennamen" type="default" facet="persType" scan="true">
                                <path match="@key" label="(descendant::tei:w/@lemma|descendant::tei:seg[@type='whitespace'])">persName[@key]</path>
                                <!--<path match="./descendant::tei:w/@lemma">persName</path>
                                <path match="./descendant::tei:w/@lemma">tei:persName</path>-->
                            </index>
                            <index key="persType" type="default">
                                <path match="@type">persName</path>
                                <path match="@type">tei:persName</path>
                            </index>
                            
                        </map>
                    </map>
                    ;
                    
declare variable $qix-tests:test-data := <p rend="indent">
                    <tei:w lemma="Kaiser" type="NN" xml:id="d1e1773">Käyser</tei:w>
                    <tei:seg type="whitespace"> </tei:seg>
                    <persName key="ferdinandus" type="hist">
                        <seg rend="antiqua">
                            <tei:w lemma="Ferdinandus" type="NE" xml:id="d1e1779">Ferdinandus</tei:w>
                        </seg>
                    </persName>
                    <tei:seg type="whitespace"> </tei:seg>
                    <tei:w lemma="seelig" type="ADJA" xml:id="d1e1783">seeligister</tei:w>
                    <tei:seg type="whitespace"> </tei:seg>                    
                    </p>;


 (:
 let $queries := <qs>
                <q cql="term1" expected-xpath='/descendant-or-self::p[ft:query(./.,&lt;query>&lt;phrase&gt;term1&lt;/phrase&gt;&lt;/query&gt;)]' />
                <q cql="rf = pb1" expected-xpath="/descendant-or-self::pb[./@xml:id='pb1']" />
                <q cql="fcs.rf = rf1" expected-xpath='/descendant-or-self::resourceFragment[ft:query(./@rf-pid,&lt;query&gt;&lt;phrase&gt;rf1&lt;/phrase>&lt;/query&gt;)]' />
                <q cql="persType='bibl'" expected-xpath='' />
                <q cql="persType='bibl' and persName='aman'" expected-xpath='' />
                
                </qs>
 
 for $q at $pos in $queries/q
    let $cql := $q/xs:string(@cql)
    let $expected-xpath := $q/xs:string(@expected-xpath)
    let $xcql := cql:cql-to-xcql($cql)/*
    let $resolved-xpath := cql:process-xcql($xcql, $map)
    return if ($expected-xpath eq $resolved-xpath) then () else $expected-xpath||' != '||$resolved-xpath
(\: return ( $resolved-xpath):\)
    
    :)
    
 (:   
 declare 
    %test:name("transform index to xpath")
    %test:arg("key", "persName")
    %test:arg("type", "")
    %test:assertEquals("descendant-or-self::persName[@key]")    
    %test:arg("key", "persName")
    %test:arg("type", "match")
    %test:assertEquals("descendant-or-self::persName[@key]/@key")
    %test:arg("key", "persName")        
    %test:arg("type", "match-only")
    %test:assertEquals("@key")
    %test:arg("key", "persName")        
    %test:arg("type", "label")
    %test:assertEquals("descendant-or-self::persName[@key]/(descendant::tei:w/@lemma|descendant::tei:seg[@type='whitespace'])")
    %test:arg("key", "persName") %test:arg("type", "label-only") %test:assertEquals("(descendant::tei:w/@lemma|descendant::tei:seg[@type='whitespace'])")
 function qix-tests:test-index-as-xpath($key,$type) as xs:string {
    index:index-as-xpath-from-map($key, $qix-tests:map, $type)
 };
 
:)
(:
 declare
    %test:name("execute query on test data")
    %test:arg("q", "persName=ferdinandus")    
    %test:assertEquals("?")  
 function qix-tests:execute-query($q) as item()* {
    query:execute-query-map($q, $qix-tests:test-data, $qix-tests:map)
(\:    query:execute-query($q, $qix-tests:test-data, 'abacus'):\)
 };
 :)
 
 declare
    %test:name("transform query to xpath")
    %test:arg("q", "persName=ferdinandus")
    %test:assertXPath("/searchClause/index[.='persName']")    
    %test:assertXPath("/searchClause/term[.='ferdinandus']")
 function qix-tests:query-to-xcql($q) as item()* {
(:    query:query-to-xpath($q, '',$qix-tests:map) :)
        let $xcql :=  cql:cql-to-xcql($q)
        return cql:xcql-to-xpath($xcql, 'abacus')
(:return $xcql:)
 };
 
 
 
