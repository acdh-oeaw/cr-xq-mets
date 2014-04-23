<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:cr="http://aac.ac.at/content_repository" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:fcs="http://clarin.eu/fcs/1.0" xmlns:exist="http://exist.sourceforge.net/NS/exist" version="2.0">
    <xsl:param name="cr-ids" as="xs:string*"/>
    <xsl:variable name="ids" select="tokenize($cr-ids,',')"/>
    <xsl:template match="node() | @*">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="*[@cr:id = $ids]">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:choose>
                <!-- we want to be sure that we do not highlight whole resourcefragments -->
                <xsl:when test="exists(parent::element())">
                    <exist:match>
                        <xsl:value-of select="."/>
                    </exist:match>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:copy>
    </xsl:template>
</xsl:stylesheet>