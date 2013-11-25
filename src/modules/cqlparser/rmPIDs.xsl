<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl"
    exclude-result-prefixes="xs xd" version="2.0">
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p><xd:b>Created on:</xd:b> Oct 16, 2013</xd:p>
            <xd:p><xd:b>Author:</xd:b> Daniel</xd:p>
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


    <xsl:template match="searchClause[index = ('resourcefragment-pid','resource-pid')]"
        mode="remove-pids"/>

    <xsl:template match="triple[(rightOperand|leftOperand)[not(*)]]" mode="sanitize">
        <xsl:apply-templates select="leftOperand[*]|rightOperand[*]" mode="#current"/>
    </xsl:template>
    
    <xsl:template mode="sanitize" match="leftOperand[*]|rightOperand[*]">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>

</xsl:stylesheet>
