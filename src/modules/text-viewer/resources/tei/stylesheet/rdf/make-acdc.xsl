<?xml version="1.0" encoding="UTF-8"?>
<XSL:stylesheet xmlns:XSL="http://www.w3.org/1999/XSL/Transform" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:xsl="http://www.w3.org/1999/XSL/TransformAlias" xpath-default-namespace="http://www.tei-c.org/ns/1.0" exclude-result-prefixes="rdf" version="2.0">
    <XSL:import href="../common2/odds.xsl"/>
    <XSL:import href="../common2/i18n.xsl"/>
    <XSL:key name="EQUIVFILES" match="equiv" use="@filter"/>
    <XSL:key name="MEMBERS" match="elementSpec" use="classes/memberOf/@key"/>
    <XSL:output method="xml" indent="yes" encoding="utf-8"/>
    <XSL:key name="NS" match="elementSpec|attDef" use="@ns"/>
    <XSL:param name="useFixedDate">false</XSL:param>
    <XSL:namespace-alias stylesheet-prefix="xsl" result-prefix="XSL"/>
    <XSL:template name="generateDoc">
        <XSL:choose>
            <XSL:when test="string-length($doclang)&gt;0">
                <XSL:value-of select="$doclang"/>
            </XSL:when>
            <XSL:otherwise>
                <XSL:text>en</XSL:text>
            </XSL:otherwise>
        </XSL:choose>
    </XSL:template>
    <XSL:template name="bitOut">
        <XSL:param name="grammar">true</XSL:param>
        <XSL:param name="content"/>
        <XSL:copy-of select="$content"/>
    </XSL:template>
    <XSL:template match="/">
        <xsl:stylesheet version="2.0" xpath-default-namespace="http://www.tei-c.org/ns/1.0">
            <xsl:import href="../tools/getfiles.xsl"/>
            <XSL:for-each select="distinct-values(//equiv/@filter)">
                <xsl:import href="{.}"/>
            </XSL:for-each>
            <xsl:param name="corpus">./</xsl:param>
            <xsl:template match="*">
                <xsl:apply-templates select="*|@*|processing-instruction()|comment()|text()"/>
            </xsl:template>
            <xsl:template match="text()|comment()|@*|processing-instruction()"/>
            <XSL:for-each select="//equiv[@filter]">
                <xsl:template>
                    <XSL:variable name="f" select="@filter"/>
                    <XSL:attribute name="match">
                        <XSL:value-of select="ancestor::elementSpec/@ident"/>
                    </XSL:attribute>
                    <xsl:call-template name="{@name}"/>
                </xsl:template>
            </XSL:for-each>
            <xsl:template name="typology">
                <E55_Type xmlns="http://purl.org/NET/crm-owl#" rdf:about="http://www.tei-c.org/type/place">
                    <label xmlns="http://www.w3.org/2000/01/rdf-schema#">place</label>
                </E55_Type>
                <XSL:for-each select="key('MEMBERS','model.placeNamePart')">
                    <E55_Type xmlns="http://purl.org/NET/crm-owl#" rdf:about="http://www.tei-c.org/type/place/{@ident}">
                        <label xmlns="http://www.w3.org/2000/01/rdf-schema#">
                            <XSL:call-template name="makeDescription"/>
                        </label>
                        <P127_has_broader_term rdf:resource="http://www.tei-c.org/type/place"/>
                    </E55_Type>
                </XSL:for-each>
            </xsl:template>
        </xsl:stylesheet>
    </XSL:template>
</XSL:stylesheet>