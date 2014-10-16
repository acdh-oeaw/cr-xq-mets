<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:tei="http://www.tei-c.org/ns/1.0" version="1.0">
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
            <xsl:copy>
                <xsl:apply-templates select="node() | @*"/>
            </xsl:copy>
        </xsl:template>
    
    <xsl:template match="l|tei:l">
        <xsl:apply-templates select="node() | @*"/>
        <xsl:text> </xsl:text> 
    </xsl:template>
    
    <xsl:template match="tei:supplied | supplied | tei:corr | corr | tei:reg | reg"/>
    
 </xsl:stylesheet>