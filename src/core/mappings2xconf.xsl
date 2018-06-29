<?xml version="1.0" encoding="UTF-8"?>

<!--
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
-->

<xsl:stylesheet xmlns="http://exist-db.org/collection-config/1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:index="http://aac.ac.at/content_repository/index" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl" exclude-result-prefixes="index xd xsl xs" version="2.0">
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>
                <xd:b>Created on:</xd:b> Nov 29, 2013</xd:p>
            <xd:p>
                <xd:b>Author:</xd:b> daniel</xd:p>
            <xd:p>Transforms cr_xq index definitions (mappings) to a eXist-collection-config
                (xconfig) file.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:output method="xml" indent="yes"/>
    <xsl:param name="scope"/>
    <xsl:param name="default-analyzer-class">org.apache.lucene.analysis.standard.StandardAnalyzer</xsl:param>
    <xsl:param name="default-data-type">xs:string</xsl:param>
    <xsl:variable name="all-range-indexes" select="//index[@type=('default','range') or not(@type)]"/>
    <xsl:variable name="range-indexes" as="item()*">
        <!-- we make sure that we do not create duplicate index entries for the same 
        element or attribute by calling 'distinct-values' on all range index definitions, thus returning a list of unique qnames; then we consider only the *first* index definition in the map that uses the element/attribute in question-->
        <xsl:for-each select="distinct-values($all-range-indexes/path/(if(@match) then @match else text())/index:qnamesFromPath(.))">
            <xsl:variable name="currentIndex" select="."/>
            <xsl:apply-templates select="$all-range-indexes[some $x in (if (path/@match) then path/@match else path/text()) satisfies index:qnamesFromPath($x)=$currentIndex][1]"/>
        </xsl:for-each>
    </xsl:variable>
    <xsl:variable name="all-fulltext-indexes" select="//index[@type='ft']"/>
    <xsl:variable name="fulltext-indexes" as="item()*">
        <xsl:apply-templates select="$all-fulltext-indexes"/>
    </xsl:variable>
    <xsl:variable name="fulltext-ignore" as="item()*">
        <xsl:sequence select="//ft/ignore[not(@index)]/index:mvToNs(.)"/>
    </xsl:variable>
    <xsl:variable name="fulltext-inline" as="item()*">
        <xsl:sequence select="//ft/inline[not(@index)]/index:mvToNs(.)"/>
    </xsl:variable>
    <xsl:template match="/map">
        <collection>
            <index xmlns:cr="http://aac.ac.at/content_repository" xmlns:fcs="http://clarin.eu/fcs/1.0">
                <xsl:namespace name="xs">http://www.w3.org/2001/XMLSchema</xsl:namespace>
                <xsl:apply-templates select="namespaces/ns"/>
                
                <!-- disable legacy fulltext index -->
                <xsl:comment>disable legacy fulltext index</xsl:comment>
                <xsl:comment>
                    <fulltext default="none" attributes="no"/>
                </xsl:comment>
                
                <!-- fulltext index definitions -->
                <xsl:if test="exists($fulltext-indexes)">
                    <lucene>
                        <analyzer class="{$default-analyzer-class}"/>
                        <xsl:copy-of select="$fulltext-indexes"/>
                        <xsl:copy-of select="$fulltext-ignore"/>
                        <xsl:copy-of select="$fulltext-inline"/>
                    </lucene>
                </xsl:if>
                
                <!-- generated range-index definitions -->
                <xsl:copy-of select="$range-indexes"/>
                <xsl:value-of select="'&#xA;&#xA;'"/>
                <!-- default index-defitions -->
                <xsl:comment>Default index-definitions for working copies and lookup tables</xsl:comment>
                <xsl:value-of select="'&#xA;'"/>
                <range>
                    <create qname="@cr:id" type="xs:string"/>
                    <create qname="@cr:project-id" type="xs:string"/>
                    <create qname="@cr:resource-pid" type="xs:string"/>
                    <create qname="@cr:w" type="xs:string"/>
<!--                <create qname="@cr:resourcefragment-pid" type="xs:string"/>-->
                </range>
            </index>
        </collection>
    </xsl:template>
    <xsl:template match="/map/namespaces/ns">
        <xsl:namespace name="{@prefix}" select="@uri"/>
    </xsl:template>
    <xsl:template match="*[some $x in $all-range-indexes satisfies $x is .]">
        <xsl:variable name="current" select="."/>
        <xsl:variable name="indexes-with-same-qname" select="$all-range-indexes[some $x in (if (path/@match) then path/@match else path/text()) satisfies index:qnamesFromPath($x)=$current/(if(path/@match) then path/@match else path/text())/index:qnamesFromPath(.)] except ."/>
        <xsl:comment>index key '<xsl:value-of select="@key"/>'</xsl:comment>
        <xsl:if test="$indexes-with-same-qname">
            <xsl:comment>indexes sharing the same element/attribute: <xsl:value-of select="string-join($indexes-with-same-qname/@key,',')"/>
            </xsl:comment>
        </xsl:if>
        <xsl:variable name="type" select="(@data-type,$default-data-type)[1]"/>
        <xsl:variable name="all-paths" as="item()*" select="distinct-values(path/index:qnamesFromPath((if (@match) then @match else text())))"/>
        <xsl:for-each select="$all-paths">
            <create qname="{index:qnamesFromPath(.)}" type="{$type}"/>
        </xsl:for-each>
    </xsl:template>
    <xsl:template match="*[some $x in $all-fulltext-indexes satisfies $x is .]">
        <xsl:variable name="key" select="@key"/>
        <xsl:comment>index '<xsl:value-of select="@key"/>'</xsl:comment>
        <xsl:value-of select="'&#xA;'"/>
        <xsl:for-each select="path/(if (@match) then @match else text())">
            <text qname="{index:qnamesFromPath(.)}">
                <xsl:if test="//ft/ignore[@index = $key]">
                    <xsl:for-each select="//ft/ignore[@index = $key]">
                        <xsl:element name="ignore" namespace="http://exist-db.org/collection-config/1.0">
                            <xsl:attribute name="qname">
                                <xsl:value-of select="."/>
                            </xsl:attribute>
                        </xsl:element>
                    </xsl:for-each>
                </xsl:if>
                <xsl:if test="//ft/inline[@index = $key]">
                    <xsl:for-each select="//ft/inline[@index = $key]">
                        <xsl:element name="inline" namespace="http://exist-db.org/collection-config/1.0">
                            <xsl:attribute name="qname">
                                <xsl:value-of select="."/>
                            </xsl:attribute>
                        </xsl:element>
                    </xsl:for-each>
                    <!--<xsl:copy-of select="//ft/inline[@index = $key]/index:mvToNs(.)"/>-->
                </xsl:if>
            </text>
        </xsl:for-each>
        <xsl:value-of select="'&#xA;'"/>
        <xsl:value-of select="'&#xA;'"/>
    </xsl:template>
    <xsl:function name="index:qnamesFromPath" as="xs:string">
        <xsl:param name="path" as="xs:string"/>
        <xsl:variable name="lastPart" select="tokenize(replace($path,'\[.+\]',''),'/')[last()]"/>
        <xsl:variable name="ret">
            <!-- Is this a function call? Then we need to fetch the parameter for the function. -->
            <xsl:analyze-string select="$lastPart" regex="^[:A-Z_a-z&#x00C0;-&#x00D6;&#x00D8;-&#x00F6;&#x00F8;-&#x02FF;&#x0370;-&#x037D;&#x037F;-&#x1FFF;&#x200C;-&#x200D;&#x2070;-&#x218F;&#x2C00;-&#x2FEF;&#x3001;-&#xD7FF;&#xF900;-&#xFDCF;&#xFDF0;-&#xFFFD;][-.:A-Z_a-z0-9&#x00C0;-&#x00D6;&#x00D8;-&#x00F6;&#x00F8;-&#x02FF;&#x0370;-&#x037D;&#x037F;-&#x1FFF;&#x200C;-&#x200D;&#x2070;-&#x218F;&#x2C00;-&#x2FEF;&#x3001;-&#xD7FF;&#xF900;-&#xFDCF;&#xFDF0;-&#xFFFD;]*\(([@:A-Z_a-z&#x00C0;-&#x00D6;&#x00D8;-&#x00F6;&#x00F8;-&#x02FF;&#x0370;-&#x037D;&#x037F;-&#x1FFF;&#x200C;-&#x200D;&#x2070;-&#x218F;&#x2C00;-&#x2FEF;&#x3001;-&#xD7FF;&#xF900;-&#xFDCF;&#xFDF0;-&#xFFFD;][-.:A-Z_a-z0-9&#x00C0;-&#x00D6;&#x00D8;-&#x00F6;&#x00F8;-&#x02FF;&#x0370;-&#x037D;&#x037F;-&#x1FFF;&#x200C;-&#x200D;&#x2070;-&#x218F;&#x2C00;-&#x2FEF;&#x3001;-&#xD7FF;&#xF900;-&#xFDCF;&#xFDF0;-&#xFFFD;]*).*$">
            <xsl:matching-substring>
                <xsl:value-of select="regex-group(1)"/>
            </xsl:matching-substring>
            <xsl:non-matching-substring>
                <xsl:value-of select="$lastPart"/>
            </xsl:non-matching-substring>
        </xsl:analyze-string>
        </xsl:variable>    
        <xsl:value-of select="$ret"/>
    </xsl:function>
    <xsl:function name="index:mvToNs">
        <xsl:param name="node" as="item()"/>
        <xsl:choose>
            <xsl:when test="$node instance of element()">
                <xsl:element name="{local-name($node)}" namespace="http://exist-db.org/collection-config/1.0">
                    <xsl:for-each select="($node/@* except $node/@index,$node/node())">
                        <xsl:sequence select="index:mvToNs(.)"/>
                    </xsl:for-each>
                </xsl:element>
            </xsl:when>
            <xsl:when test="$node instance of document-node()">
                <xsl:sequence select="index:mvToNs($node/*)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:sequence select="$node"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
</xsl:stylesheet>