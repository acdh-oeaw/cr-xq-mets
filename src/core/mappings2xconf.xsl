<?xml version="1.0" encoding="UTF-8"?>
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
    <xsl:template match="/map">
        <xsl:variable name="range-indexes" as="item()+">
            <xsl:apply-templates select="//index[@index-type!='ft' or not(@index-type)]"/>
        </xsl:variable>
        <xsl:variable name="fulltext-indexes" as="item()+">
            <xsl:apply-templates select="//index[@index-type='ft'][path/node()]"/>
        </xsl:variable>
        <collection>
            <index xmlns:cr="http://aac.ac.at/content_repository" xmlns:fcs="http://clarin.eu/fcs/1.0">
                <xsl:namespace name="xs">http://www.w3.org/2001/XMLSchema</xsl:namespace>
                <xsl:apply-templates select="namespaces/ns"/>
                <!-- disable legacy fulltext index -->
                <fulltext default="none" attributes="false"/>
                
                <!-- fulltext index definitions -->
                <xsl:if test="exists($fulltext-indexes)">
                    <lucene>
                        <analyzer class="{$default-analyzer-class}"/>
                        <xsl:copy-of select="$fulltext-indexes"/>
                    </lucene>
                </xsl:if>
                
                <!-- generated range-index definitions -->
                <xsl:copy-of select="$range-indexes"/>
                
                <!-- default index-defitions -->
                <xsl:comment>Default index-definitions for working copies and lookup tables</xsl:comment>
                <create qname="@cr:id" type="xs:string"/>
                <create qname="@cr:project-id" type="xs:ID"/>
                <create qname="@cr:resource-pid" type="xs:ID"/>
                <create qname="@cr:resourcefragment-pid" type="xs:ID"/>
            </index>
        </collection>
    </xsl:template>
    <xsl:template match="/map/namespaces/ns">
        <xsl:namespace name="{@prefix}" select="@uri"/>
    </xsl:template>
    <xsl:template match="index[@index-type='ft']">
        <xsl:for-each select="@use">
            <text qname="{index:qnamesFromPath(.)}"/>
        </xsl:for-each>
        <xsl:for-each select="path[node()]">
            <text qname="{index:qnamesFromPath(.)}"/>
        </xsl:for-each>
    </xsl:template>
    <xsl:template match="index[@index-type='ngram' or not(@index-type)]">
        <xsl:variable name="type" select="(@type,'xs:string')[1]"/>
        <xsl:for-each select="@use">
            <create qname="{index:qnamesFromPath(.)}" type="{$type}"/>
        </xsl:for-each>
        <xsl:for-each select="path[node()]">
            <create qname="{index:qnamesFromPath(.)}" type="{$type}"/>
        </xsl:for-each>
    </xsl:template>
    <xsl:function name="index:qnamesFromPath">
        <xsl:param name="path" as="xs:string"/>
        <xsl:analyze-string select="$path" regex="^@?([a-zA-Z]([a-zA-Z0-9\.\-_]+)?:)?[a-zA-Z]([a-zA-Z0-9\.\-_]+)?">
            <xsl:matching-substring>
                <xsl:value-of select="."/>
            </xsl:matching-substring>
            <xsl:non-matching-substring/>
        </xsl:analyze-string>
    </xsl:function>
</xsl:stylesheet>