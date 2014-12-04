<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="http://www.loc.gov/METS/" xmlns:ann="http://www.clarin.eu" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:rts="http://cosimo.stanford.edu/sdr/metsrights/" xmlns:mods="http://www.loc.gov/mods/v3" xmlns:dcr="http://www.isocat.org/ns/dcr" xmlns:mets="http://www.loc.gov/METS/" xmlns:cmd="http://www.clarin.eu/cmd/" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xlink="http://www.w3.org/1999/xlink" xsi:schemaLocation="http://www.loc.gov/METS/ http://www.loc.gov/standards/mets/mets.xsd" exclude-result-prefixes="xs xd" version="2.0">
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>
                <xd:b>Created on:</xd:b> Nov 28, 2013</xd:p>
            <xd:p>
                <xd:b>Author:</xd:b> daniel</xd:p>
            <xd:p/>
            <xd:p>Initializes the initials CMDI record for a cr_xq object by placing appropriate
                values into the template which is passed as the input document.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:param name="project-pid" required="yes"/>
    <xsl:param name="MdCreator" required="yes"/>
    <xsl:param name="MdCreationDate" required="yes"/>
    <xsl:param name="MdCollectionDisplayName" required="yes"/>
    <xsl:param name="project-LandingPage" required="yes"/>
    <xsl:param name="project-Website" required="yes"/>
    <xsl:template match="node() | @*">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="/">
        <xsl:apply-templates/>
    </xsl:template>
    <xsl:template match="cmd:MdCreator">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:value-of select="$MdCreator"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="cmd:MdCreationDate">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:value-of select="$MdCreationDate"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="cmd:MdCollectionDisplayName">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:value-of select="$MdCollectionDisplayName"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="cmd:ResourceProxy[cmd:ResourceType='LandingPage']/@id">
        <xsl:attribute name="id">
            <xsl:value-of select="$project-pid"/>
        </xsl:attribute>
    </xsl:template>
    <xsl:template match="cmd:ResourceProxy[cmd:ResourceType='LandingPage']/cmd:ResourceRef">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:value-of select="$project-LandingPage"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="cmd:WebReference/cmd:Website">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:value-of select="$project-Website"/>
        </xsl:copy>
    </xsl:template>
</xsl:stylesheet>