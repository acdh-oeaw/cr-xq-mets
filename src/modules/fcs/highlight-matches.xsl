<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:facs="http://www.oeaw.ac.at/icltt/cr-xq/facsviewer" xmlns:exist="http://exist.sourceforge.net/NS/exist" version="1.0">
    
    <!-- input takes the form:
        <facs:query-result>
            <facs:matches>
                <w xml:id="w1234"><exist:match>matching term</exist:match></w>
                ....
            </facs:matches>
            <facs:page-content>
                <pb facs="Abraham_Mercks_Wien_n00015.jpg"/>
                <w xml:id="w1234">matching term</w>
                ...
            </facs:page-content>
        </facs:query-result>
    
    -->
    <xsl:key name="match-by-id" match="/facs:query-result/facs:matches/*" use="@xml:id"/>
    <xsl:variable name="match-ids" select="/facs:query-result/facs:matches/*/@xml:id"/>
    <xsl:template match="/facs:query-result">
<!--        <xsl:message><xsl:value-of select="$match-ids"/></xsl:message>-->
        <xsl:apply-templates select="facs:page-content"/>
    </xsl:template>
    <xsl:template match="/facs:query-result/facs:matches"/>
    <xsl:template name="copyMe">
        <xsl:param name="elt"/>
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="node() | @*">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="*[@xml:id]">
        <xsl:choose>
            <xsl:when test="@xml:id = $match-ids">
                <xsl:copy-of select="key('match-by-id',@xml:id)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:call-template name="copyMe">
                    <xsl:with-param name="elt" select="."/>
                </xsl:call-template>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
</xsl:stylesheet>