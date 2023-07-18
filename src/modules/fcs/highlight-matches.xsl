<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:exist="http://exist.sourceforge.net/NS/exist" xmlns:fcs="http://clarin.eu/fcs/1.0"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl"
    xmlns:cr="http://aac.ac.at/content_repository" version="2.0">
    <xd:doc scope="component">a list of comma seperated ids, either full @cr:id values or @cr:id +
        offsets of a substring: </xd:doc>
    <xsl:param as="xs:string*" name="cr-ids"/>
    <xsl:variable name="ids-parsed" as="element()*">
        <xsl:for-each select="tokenize($cr-ids, '\s*,\s*')">
            <id-parsed>
                <xsl:analyze-string regex=":(\d+):(\d+)$" select=".">
                    <xsl:matching-substring>
                        <offset>
                            <xsl:value-of select="regex-group(1)"/>
                        </offset>
                        <length>
                            <xsl:value-of select="regex-group(2)"/>
                        </length>
                    </xsl:matching-substring>
                    <xsl:non-matching-substring>
                        <id>
                            <xsl:value-of select="."/>
                        </id>
                    </xsl:non-matching-substring>
                </xsl:analyze-string>
            </id-parsed>
        </xsl:for-each>
    </xsl:variable>
    <xsl:variable name="all-ids" select="$ids-parsed//id/text()" as="text()*"/>
    <xsl:template match="node() | @*">
        <xsl:copy copy-namespaces="no">
            <xsl:apply-templates select="node() | @*"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="*[@cr:id = $all-ids]" priority="1">
        <xsl:variable name="elt" as="element()" select="."/>
        <xsl:variable name="cr:id" select="@cr:id"/>
        <xsl:variable name="id-parsed" select="$all-ids[. = $cr:id]/ancestor::id-parsed"/>
        <xsl:variable name="offset" select="$id-parsed/offset"/>
        <xsl:variable name="length" select="$id-parsed/length"/>
        <xsl:copy copy-namespaces="no">
            <xsl:copy-of select="@*"/>
            <xsl:choose>
                <!-- we want to be sure that we do not highlight whole resourcefragments -->
                <xsl:when test="exists(parent::element())">
                    <xsl:choose>
                        <xsl:when test="$offset != '' and $length != ''">
                            <xsl:message select="count($id-parsed)"/>
                            <xsl:copy>
                                <xsl:copy-of select="@*"/>
                                <xsl:for-each select="$id-parsed">
                                    <xsl:if test="offset &gt; 0">
                                        <xsl:value-of
                                            select="substring($elt, 0, xs:integer(offset) - 1)"/>
                                    </xsl:if>
                                    <exist:match>
                                        <xsl:value-of select="substring($elt, offset, length)"/>
                                    </exist:match>
                                    <xsl:if
                                        test="string-length($elt) &gt; (xs:integer(length) + xs:integer(offset))">
                                        <xsl:value-of
                                            select="substring($elt, xs:integer(length) + xs:integer(offset))"
                                        />
                                    </xsl:if>
                                </xsl:for-each>
                            </xsl:copy>
                        </xsl:when>
                        <xsl:otherwise>
                            <exist:match>
                                <xsl:apply-templates/>
                            </exist:match>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:copy>
    </xsl:template>
</xsl:stylesheet>
