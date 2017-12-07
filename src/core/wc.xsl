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
<xsl:stylesheet xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl" xmlns:cr="http://aac.ac.at/content_repository" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:xs="http://www.w3.org/2001/XMLSchema" exclude-result-prefixes="xs xd tei" version="2.0">
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
        <xsl:call-template name="makeElt"/>
    </xsl:template>
    <xsl:template match="tei:w[@type]|w[@type]|tei:pc[@type]|pc[@type]">
        <xsl:variable name="number">
            <xsl:number level="any" count="*[self::tei:w[@type]|self::w[@type]|self::tei:pc[@type]|self::pc[@type]]"/>
        </xsl:variable>
        <xsl:call-template name="makeElt">
            <xsl:with-param name="number" select="$number"/>
        </xsl:call-template>
    </xsl:template>
    <xsl:template name="makeElt">
        <xsl:param name="number"/>
        <xsl:copy>
            <xsl:attribute name="cr:id" select="concat($resource-pid,'.',generate-id())"/>
            <xsl:if test="$number">
                <xsl:attribute name="cr:w" select="$number"/>
            </xsl:if>
            <xsl:apply-templates select="@*|node()"/>
        </xsl:copy>
    </xsl:template>
</xsl:stylesheet>