<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:fcs="http://clarin.eu/fcs/1.0" xmlns:exist="http://exist.sourceforge.net/NS/exist" version="1.0">
    
    <!-- input takes the form:
        <fcs:query-result>
            <fcs:matches>
                <w xml:id="w1234"><exist:match>matching term</exist:match></w>
                ....
            </fcs:matches>
            <fcs:page-content>
                <pb fcs="Abraham_Mercks_Wien_n00015.jpg"/>
                <w xml:id="w1234">matching term</w>
                ...
            </fcs:page-content>
        </fcs:query-result>
    
    -->
    <xsl:key name="match-by-id" match="/fcs:query-result/fcs:matches/*" use="@xml:id"/>
    <xsl:variable name="match-ids" select="/fcs:query-result/fcs:matches/*/@xml:id"/>
    <xsl:template match="/fcs:query-result">
<!--        <xsl:message><xsl:value-of select="$match-ids"/></xsl:message>-->
        <xsl:apply-templates select="fcs:page-content"/>
    </xsl:template>
    <xsl:template match="/fcs:query-result/fcs:matches"/>
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