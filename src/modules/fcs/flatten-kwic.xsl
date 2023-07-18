<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:exist="http://exist.sourceforge.net/NS/exist" xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:cr="http://aac.ac.at/content_repository" version="2.0">

    <!--    <xsl:strip-space elements="*"/>-->
    <!--    <xsl:preserve-space elements="tei:seg"/>-->
    <xsl:output indent="yes"/>
    <xsl:template match="/">
        <xsl:variable name="record" as="item()*">
            <record>
                <xsl:apply-templates select="node() | @*"/>
            </record>
        </xsl:variable>
        <xsl:apply-templates select="$record" mode="groupMatches"/>
    </xsl:template>
    <xsl:template match="* | @*" mode="#all">
        <!--<xsl:text> </xsl:text> -->
        <xsl:apply-templates select="node() | @*" mode="#current"/>
    </xsl:template>
    <xsl:template match="node() | @*" mode="groupMatches" priority="1">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="tei:seg[@type = 'whitespace']/text()">
        <!--        <xsl:value-of select="normalize-space(.)"/>-->
        <xsl:copy> </xsl:copy>
    </xsl:template>
    <xsl:template match="text()">
        <xsl:value-of select="normalize-space(.)"/>
        <!--<xsl:copy>
                
            </xsl:copy>-->
    </xsl:template>
    <xsl:template match="*[local-name() = 'match']">
        <xsl:param name="value"/>
        <xsl:copy>
            <xsl:apply-templates select="@*"/>
            <xsl:choose>
                <xsl:when test="$value != ''">
                    <xsl:value-of select="$value"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates select="node()"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:copy>
    </xsl:template>
    <xsl:template
        match="l | tei:l | p | tei:p | head | tei:head | titlePage | tei:titlePage | table | tei:table">
        <xsl:apply-templates select="node() | @*"/>
        <xsl:text> </xsl:text>
    </xsl:template>
    <xsl:template
        match="tei:supplied | supplied | tei:corr | corr | tei:reg | reg | tei:figure | figure | tei:note | note"/>

    <!-- headers and footers are not part of running text -->
    <xsl:template
        match="fw | tei:fw | *[self::seg or self::tei:seg][@type = 'footer' or @type = 'header']"/>


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
    <xsl:template match="*[exist:match]" mode="groupMatches" priority="2">
        <xsl:variable name="seq" select="node()[not(normalize-space(.) = (' ', ''))]" as="item()*"/>
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:for-each-group select="$seq" group-adjacent="name(.)">
                <xsl:choose>
                    <xsl:when test="current-grouping-key() = 'exist:match'">
                        <exist:match>
                            <xsl:apply-templates select="current-group()" mode="inMatchGroup"/>
                        </exist:match>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:apply-templates select="current-group()" mode="#current"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:for-each-group>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="exist:match" mode="inMatchGroup" priority="2">
        <xsl:variable name="this" select="."/>
        <xsl:apply-templates mode="#current"/>
        <!--        <xsl:text>X</xsl:text>-->
        <xsl:copy-of
            select="following-sibling::node()[normalize-space(.) = (' ', '')][preceding-sibling::exist:match[1] is $this]"
        />
    </xsl:template>
</xsl:stylesheet>
