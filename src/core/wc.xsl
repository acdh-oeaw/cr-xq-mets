<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:cr="http://aac.ac.at/content_repository" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl" exclude-result-prefixes="xs xd" version="2.0">
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>
                <xd:b>Created on:</xd:b> Oct 17, 2013</xd:p>
            <xd:p>
                <xd:b>Author:</xd:b> aac</xd:p>
            <xd:p>This stylesheets adds internal ids to all elements of a resource.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:param name="project-id"/>
    <xsl:param name="resource-pid"/>
    <xsl:template match="text() | comment() | @*">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="element()">
        <xsl:copy>
            <xsl:attribute name="cr:project-id" select="$project-id"/>
            <xsl:attribute name="cr:resource-pid" select="$resource-pid"/>
            <xsl:attribute name="cr:id" select="generate-id()"/>
            <xsl:apply-templates select="@*|node()"/>
        </xsl:copy>
    </xsl:template>
</xsl:stylesheet>