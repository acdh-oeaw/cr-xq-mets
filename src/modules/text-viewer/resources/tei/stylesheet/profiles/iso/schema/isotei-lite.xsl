<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xj="http://xml.apache.org/xalan/java" xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:saxon="http://icl.com/saxon" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:loc="http://www.thaiopensource.com/ns/location"
    xmlns:err="http://www.thaiopensource.com/ns/error"
    xmlns:sch="http://www.ascc.net/xml/schematron" version="2.0">
    <doc xmlns="http://www.oxygenxml.com/ns/doc/xsl" scope="stylesheet" type="stylesheet">
        <desc>
            <p>This software is dual-licensed: 1. Distributed under a Creative Commons
                Attribution-ShareAlike 3.0 Unported License
                http://creativecommons.org/licenses/by-sa/3.0/ 2.
                http://www.opensource.org/licenses/BSD-2-Clause All rights reserved. Redistribution
                and use in source and binary forms, with or without modification, are permitted
                provided that the following conditions are met: * Redistributions of source code
                must retain the above copyright notice, this list of conditions and the following
                disclaimer. * Redistributions in binary form must reproduce the above copyright
                notice, this list of conditions and the following disclaimer in the documentation
                and/or other materials provided with the distribution. This software is provided by
                the copyright holders and contributors "as is" and any express or implied
                warranties, including, but not limited to, the implied warranties of merchantability
                and fitness for a particular purpose are disclaimed. In no event shall the copyright
                holder or contributors be liable for any direct, indirect, incidental, special,
                exemplary, or consequential damages (including, but not limited to, procurement of
                substitute goods or services; loss of use, data, or profits; or business
                interruption) however caused and on any theory of liability, whether in contract,
                strict liability, or tort (including negligence or otherwise) arising in any way out
                of the use of this software, even if advised of the possibility of such damage. </p>
            <p>Author: See AUTHORS</p>
            <p>Id: $Id: isotei-lite.xsl 9646 2011-11-05 23:39:08Z rahtz $</p>
            <p>Copyright: 2008, TEI Consortium</p>
        </desc>
    </doc>
    <xsl:output method="text"/>
    <xsl:template match="/">
        <xsl:apply-templates select="/" mode="all"/>
    </xsl:template>
    <xsl:template match="* | /" mode="all">
        <xsl:apply-templates select="*" mode="all"/>
    </xsl:template>
    <xsl:template name="location"/>
    <xsl:template match="node() | @*" mode="schematron-get-full-path-2">
        <xsl:text>

* section </xsl:text>
        <xsl:for-each select="ancestor-or-self::tei:div">/<xsl:number level="multiple"/>
            <xsl:text> - </xsl:text>
            <xsl:value-of select="translate(substring(tei:head, 1, 20), '&#160;', ' ')"/>
        </xsl:for-each>
        <xsl:text> (element </xsl:text>
        <xsl:value-of select="local-name()"/>
        <xsl:text>)

</xsl:text>
    </xsl:template>
</xsl:stylesheet>
