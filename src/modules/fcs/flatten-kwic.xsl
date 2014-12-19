<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:cr="http://aac.ac.at/content_repository" xmlns:tei="http://www.tei-c.org/ns/1.0" version="1.0">
    
<!--    <xsl:strip-space elements="*"/>-->
    
    <xsl:template match="/">
        <record>
            <xsl:apply-templates select="node() | @*"/>
        </record>
    </xsl:template>
        
    <xsl:template match=" * | @*">
       <!--<xsl:text> </xsl:text> -->
        <xsl:apply-templates select="node() | @*"/>
    
    </xsl:template>
        <xsl:template match="text()">
            <xsl:copy>
                
            </xsl:copy>
        </xsl:template>
        <xsl:template match="*[local-name()='match']">
            <xsl:param name="value"/>
            <xsl:copy>
                <xsl:apply-templates select="@*"/>
                <xsl:choose>
                    <xsl:when test="$value!=''">
                        <xsl:value-of select="$value"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:apply-templates select="node()"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:copy>
        </xsl:template>
    
    
    <xsl:template match="l|tei:l">
        <xsl:apply-templates select="node() | @*"/>
        <xsl:text> </xsl:text> 
    </xsl:template>
    
    <xsl:template match="tei:supplied | supplied | tei:corr | corr | tei:reg | reg"/>
    
    <!-- headers and footers are not part of running text -->
    <xsl:template match="fw | tei:fw | *[self::seg or self::tei:seg][@type='footer' or @type='header']"/>
    
    
    <!--<xsl:template match="*[self::tei:w|self::w][descendant::seg[@type='footer'] and not(following-sibling::*) or following-sibling::*[1]/self::seg[@type='footer']]">
        <xsl:choose>
            <xsl:when test="@cr:wf">
                <xsl:choose>
                    <xsl:when test="descendant::*[local-name()='match']">
                        <xsl:apply-templates select="@* | node()">
                            <xsl:with-param name="value" select="@cr:wf"/>
                        </xsl:apply-templates>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="@cr:wf"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates select="@*|node()"/>
                <xsl:text>...</xsl:text>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    -->
    
    
 </xsl:stylesheet>