<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="http://www.loc.gov/METS/" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:rts="http://cosimo.stanford.edu/sdr/metsrights/" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:mods="http://www.loc.gov/mods/v3" xmlns:mets="http://www.loc.gov/METS/" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.loc.gov/METS/ http://www.loc.gov/standards/mets/mets.xsd" exclude-result-prefixes="xs xd" version="2.0">
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>
                <xd:b>Created on:</xd:b> Nov 28, 2013</xd:p>
            <xd:p>
                <xd:b>Author:</xd:b> daniel</xd:p>
            <xd:p/>
            <xd:p>Initializes a new cr_xq object by placing appropriate values into the template
                which is passed as the input document.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:param name="OBJID" required="yes"/>
    <xsl:param name="CREATEDATE" required="yes"/>
    <xsl:param name="RECORDSTATUS" required="yes"/>
    <xsl:param name="CREATOR.SOFTWARE.NOTE" required="no"/>
    <xsl:param name="CREATOR.SOFTWARE.NAME" required="no"/>
    <xsl:param name="CREATOR.INDIVIDUAL.NAME" required="no"/>
    <xsl:template match="node() | @*">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="/">
        <xsl:apply-templates/>
    </xsl:template>
    <xsl:template match="@OBJID">
        <xsl:attribute name="{name(.)}" namespace="{namespace-uri(.)}">
            <xsl:value-of select="$OBJID"/>
        </xsl:attribute>
    </xsl:template>
    <xsl:template match="mets:metsHdr/@CREATEDATE">
        <xsl:attribute name="{name(.)}" namespace="{namespace-uri(.)}">
            <xsl:value-of select="xs:dateTime($CREATEDATE)"/>
        </xsl:attribute>
    </xsl:template>
    <xsl:template match="mets:metsHdr/@RECORDSTATUS">
        <xsl:attribute name="{name(.)}" namespace="{namespace-uri(.)}">
            <xsl:value-of select="$RECORDSTATUS"/>
        </xsl:attribute>
    </xsl:template>
    <xsl:template match="mets:metsHdr/mets:agent[@ROLE='CREATOR' and @OTHERTYPE='software']/*[name() = ('name','note')]">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:choose>
                <xsl:when test="name() = 'name'">
                    <xsl:value-of select="$CREATOR.SOFTWARE.NAME"/>
                </xsl:when>
                <xsl:when test="name() = 'note'">
                    <xsl:value-of select="$CREATOR.SOFTWARE.NOTE"/>
                </xsl:when>
            </xsl:choose>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="mets:metsHdr/mets:agent[@ROLE='CREATOR' and @TYPE='INDIVIDUAL']/mets:name">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:value-of select="$CREATOR.INDIVIDUAL.NAME"/>
        </xsl:copy>
    </xsl:template>
</xsl:stylesheet>