Indexes
=======

The system relies on abstract indexes that are mapped to corresponding XPath.
These indexes are mainly used in the `fcs` module which is the currently the core module for searching in the data.

The index mappings are defined in
```
/mets:mets/mets:amdSec/mets:techMD[@ID="projectMappings"]
```

There is a schema for this map ([mappings.xsd](../blob/METS-crxq/schemas/mappings.xsd)), but it is outdated (#9).

A sample could look like:
```
<mdWrap MDTYPE="OTHER">
<xmlData>
  <map xmlns="">
      <namespaces>
          <ns prefix="tei" uri="http://www.tei-c.org/ns/1.0"/>
          <ns prefix="mets" uri="http://www.loc.gov/METS/"/>                            
          <ns prefix="fcs" uri="http://clarin.eu/fcs/1.0"/>
          <ns prefix="cr" uri="http://aac.ac.at/content_repository"/>
      </namespaces>
      <map key="" path="" title="">
          <index key="rf">
              <path match="@xml:id" label="@n">pb</path>
          </index>
       
   				<index key="fcs.toc" type="default">
              <path match="@cr:id">div[@type='chapter']</path>
              <path match="@cr:id">front</path>
              <path match="@cr:id">back</path>
          </index>
          
          <index key="cql.serverChoice" type="ft">
              <path>p</path>
              <path>l</path>
              <path>head</path>
              <path>table</path>
              <path>titlePage</path>
          </index>
          
          <index key="fcs.resource" type="ft" on-data="project">
              <path match="@ID" label="@LABEL">mets:div</path>
          </index>
          <index key="fcs.rf" type="ft">
              <path match="@resourcefragment-pid" label="@rf-label">fcs:resourceFragment</path>
          </index>
          <index key="w" label="Wortform" type="ft" scan="true">
              <path>tei:w</path>
          </index>
          <index key="lemma" label="Lemma" type="ft" scan="true">
              <path match="@lemma" label="@lemma">tei:w[@lemma]</path>
          </index>
   				
          <index key="persName" label="Personennamen" type="default" facet="persType" scan="true">              
              <path match="@key" label="./descendant::tei:w/@lemma">persName</path>
              <path match="@key" label="./descendant::tei:w/@lemma">tei:persName</path>
          </index>
          <index key="persType" type="default">
              <path match="@type">tei:persName</path>
          </index>
          
      </map>
   </map>
 </xmlData>
</mdWrap>
```

Some of the indexes have a special meaning:

**rf**
  defines the xpath delimiting the basic resource fragments (usually the pages, marked in TEI by empty element `<pb/>`
**fcs.toc**
  index defining the higher-level structures of the resource, meant for generating a table of contents. The paths should be adapted to match the structures in the resources
**fcs.resource** 
  internally used index to identify a resource. The xpath relates to the internal data and shouldn't be adapted
**fcs.rf** 
  internally used index to identify a resource fragment. The xpath relates to the internal data and shouldn't be adapted
**facs**
  defines the xpath to the filename/url of a facsimile/image pertaining to a given resource fragment

**cql.serverChoice**
  this represents the default index, i.e. where should the system search, if the user searches just with a term (unqualified by any specific index)
