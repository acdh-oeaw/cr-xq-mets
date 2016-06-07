cr-xq cqlparser-module
======================

a module for the cr-xq application
allowing to parse the CQL-query syntax 
and transform it to XPath

CQL = Context Query Language
more: http://www.loc.gov/standards/sru/specs/cql.html

Part of corpus_shell
https://github.com/vronk/corpus_shell/


Content of the module
----------------------

- cqlparser.xqm - wraps the functionality in the java-lib and provides functions to be used 
- XCQL2Xpath.xsl - translates XCQL (xml-representation of the parse-tree of the query) into Xpath
- java-extension/*.java - wrapper to bind the functionality of the library to xquery-functions


Requirements
------------

eXist 
  the way this module is linked into the application is specific to eXist.

cql-java.jar 
  get the library at: http://www.indexdata.com/cql-java
  (We are currently using version 1.10 from 2012-03-19)

config/mappings
  the functions in the module rely on configuration-information in the main application:
  /db/cr/etc/mappings.xml
  defining the mappings from abstract indexes available to the user/client 
  	to the xpaths that are used internally.
  if no configuration is given the indexes in the query are used as is (i.e. they are assumed to be xml-elements in the data)
  		
  
Installation
------------

1. put the two 2 ./java-extension/*.java-files 	
	 into: {eXist}/extensions/modules/src/org/exist/xquery/modules/cqlparser/*.java
  
2. put the cql-java.jar file 
	 into: {eXist}/extensions/modules/lib/cql-java.jar
	 
3. edit: {eXist}/extensions/build.properties, add (in the modules section):
	 
	 # CQL Parser module
	 include.module.cqlparser = true

4. run ant (in {eXist}/extensions/modules):
	{eXist}/extensions/modules>ant 

5. edit: {eXist}/conf.xml (in xquery/builtin-modules )
    
	 <module class="org.exist.xquery.modules.cqlparser.CQLParserModule" uri="http://exist-db.org/xquery/cqlparser" />

6. put cqlparser.xqm and XCQL2Xpath.xsl
	 into: xmldb:///db/cr/modules/cqlparser

7. restart exist

8. now you can try out:					 
	 http://{your-exist-address+port}/exist/rest/db/cr/modules/cqlparser/cql.xql
	 http://{your-exist-address+port}/exist/rest/db/cr/modules/cqlparser/cql.xql?cql=Haus
	 
	 or you can open the cql.xql in the eXide or sandbox and try to run it there.
	 
	 This actually only does the first step: translates CQL to XCQL.
	 But if it works, it means the java-lib-binding is working.
	 
	 
Note: In the current (2.x) version of eXist, cql is already integrated as a module, 
so you can skip steps 1. and 2.