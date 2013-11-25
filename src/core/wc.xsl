<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:cr="http://aac.ac.at/content_repository" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl" exclude-result-prefixes="xs xd" version="2.0">
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
    <xsl:param name="guess-namespaces">true</xsl:param>
    <xsl:variable name="doctype">
        <xsl:choose>
            <xsl:when test="local-name(/*) eq 'TEI'">tei</xsl:when>
            <!-- ADD other namespaces here -->
            <xsl:otherwise/>
        </xsl:choose>
    </xsl:variable>
    <xsl:function name="cr:namespace-by-root-elt" as="xs:anyURI?">
        <xsl:param name="root-elt-name"/>
        <xsl:variable name="namespace-uri">
            <xsl:choose>
                <xsl:when test="$root-elt-name eq 'TEI'">http://www.tei-c.org/ns/1.0</xsl:when>
                <xsl:otherwise/>
            </xsl:choose>
        </xsl:variable>
        <xsl:value-of select="$namespace-uri"/>
    </xsl:function>
    <xsl:template match="text() | comment() | processing-instruction() | @*">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="element()">
        <xsl:choose>
            <!-- try to put non-namespaced data into the default namespace determined by the root element -->
            <xsl:when test="namespace-uri() eq '' and $guess-namespaces eq 'true'">
                <xsl:element name="{local-name()}" namespace="{cr:namespace-by-root-elt(.)}">
                    <!-- for convenience we put the project and resource-id on top -->
                    <!--<xsl:if test="not(parent::*)">-->
                    <xsl:attribute name="cr:project-id" select="$project-id"/>
                    <xsl:attribute name="cr:resource-pid" select="$resource-pid"/>
<!--                    </xsl:if>-->
                    <xsl:attribute name="cr:id" select="generate-id()"/>
                    <xsl:apply-templates select="@*|node()"/>
                </xsl:element>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy>
                    <!-- for convenience we put the project and resource-id on top -->
                    <xsl:if test="not(parent::*)">
                        <xsl:attribute name="cr:project-id" select="$project-id"/>
                        <xsl:attribute name="cr:resource-pid" select="$resource-pid"/>
                    </xsl:if>
                    <xsl:attribute name="cr:id" select="generate-id()"/>
                    <xsl:apply-templates select="@*|node()"/>
                </xsl:copy>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
</xsl:stylesheet>