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

<xsl:stylesheet xmlns:dcr="http://www.isocat.org/ns/dcr" xmlns="http://www.loc.gov/METS/" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:cmd="http://www.clarin.eu/cmd/" xmlns:rts="http://cosimo.stanford.edu/sdr/metsrights/" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:ann="http://www.clarin.eu" xmlns:mods="http://www.loc.gov/mods/v3" xmlns:mets="http://www.loc.gov/METS/" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.loc.gov/METS/ http://www.loc.gov/standards/mets/mets.xsd" exclude-result-prefixes="xs xd" version="2.0">
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