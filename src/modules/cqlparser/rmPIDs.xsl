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

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl" exclude-result-prefixes="xs xd" version="2.0">
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>
                <xd:b>Created on:</xd:b> Oct 16, 2013</xd:p>
            <xd:p>
                <xd:b>Author:</xd:b> Daniel</xd:p>
            <xd:p>removes queries for indexes 'resource-pid' and 'resourcefragment-pid'</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:strip-space elements="*"/>
    <xsl:output method="xml" indent="yes" omit-xml-declaration="yes"/>
    <xsl:template match="/">
        <xsl:variable name="pids-removed">
            <xsl:apply-templates mode="remove-pids"/>
        </xsl:variable>
        <xsl:apply-templates select="$pids-removed" mode="sanitize"/>
    </xsl:template>
    <xsl:template match="node() | @*" mode="#all">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="searchClause[index = ('resourcefragment-pid','resource-pid')]" mode="remove-pids"/>
    <xsl:template match="triple[(rightOperand|leftOperand)[not(*)]]" mode="sanitize">
        <xsl:apply-templates select="leftOperand[*]|rightOperand[*]" mode="#current"/>
    </xsl:template>
    <xsl:template mode="sanitize" match="leftOperand[*]|rightOperand[*]">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>
</xsl:stylesheet>