<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:exist="http://exist.sourceforge.net/NS/exist" xmlns:fcs="http://clarin.eu/fcs/1.0" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl" xmlns:cr="http://aac.ac.at/content_repository" version="2.0" exclude-result-prefixes="#all">
    
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
    
    <xd:doc scope="component">a list of comma seperated ids, either full @cr:id values or @cr:id + offsets of a substring:
        
    </xd:doc>
    <xsl:preserve-space elements="*"/>
    <xsl:param as="xs:string*" name="cr-ids"/>
    <xsl:param as="xs:string" name="rfpid" select="''"/>
    <xsl:variable name="ids-parsed" as="element()*">
        <xsl:for-each select="tokenize($cr-ids,'\s*,\s*')">
            <id-parsed>
                <xsl:analyze-string regex=":(\d+):(\d+):?(.*)$" select=".">
                    <xsl:matching-substring>
                        <offset>
                            <xsl:value-of select="regex-group(1)"/>
                        </offset>
                        <length>
                            <xsl:value-of select="regex-group(2)"/>
                        </length>
                        <rfpid>
                            <xsl:value-of select="regex-group(3)"/> 
                        </rfpid>
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
    <xsl:variable name="all-ids" select="$ids-parsed//id[(not(exists(../offset))) or (../rfpid = '') or (../rfpid=$rfpid)]/text()" as="text()*"/>
    
    <xsl:template match="node() | @*">
        <xsl:if test="not(empty($all-ids))">
            <xsl:copy copy-namespaces="no">
                <xsl:apply-templates select="node() | @*"/>
            </xsl:copy>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="*[@cr:id = $all-ids]" priority="1">
        <xsl:variable name="elt" as="element()" select="."/>
        <xsl:variable name="cr:id" select="data(@cr:id)"/>
        <xsl:variable name="id-parsed" select="$ids-parsed[id = $cr:id]"/>
        <xsl:variable name="offsets" select="for $o in $id-parsed[(rfpid = '') or (rfpid=$rfpid)]/offset return xs:integer($o) " as="xs:integer*"/>
        <xsl:variable name="lengths" select="for $l in $id-parsed[(rfpid = '') or (rfpid=$rfpid)]/length return xs:integer($l)" as="xs:integer*"/>
        <xsl:copy copy-namespaces="no">
            <xsl:copy-of select="@*"/>
            <xsl:choose>
                <!-- we want to be sure that we do not highlight whole resourcefragments -->
                <xsl:when test="exists(parent::element())">
                    <xsl:choose>
                        <xsl:when test="exists($offsets) and exists($lengths)">
                            <xsl:copy>
                                <xsl:copy-of select="@*"/>
                                <xsl:call-template name="injectMatchTags">
                                    <xsl:with-param name="listOfOffsets" select="$offsets"/>
                                    <xsl:with-param name="listOflengths" select="$lengths"/>
                                    <xsl:with-param name="previousMatches">
                                        <!-- TODO change me I'm a hack
                                             If lucene search is implemented/set up like it is now
                                             the structure beneath the ft matched entries is destroyed
                                             That means: we have to destroy it here as well or recalculate
                                             the offsets. How do we go about that?
                                             This needs to be kept in sync with fcs.xqm: fcs:get-string-for-offset-length-search!
                                        -->
                                        <xsl:value-of select="string-join((for $n in $elt/(*|text()) return if ($n[@orig]) then concat(' ', data($n/@orig)) else data($n)), '')"/>
                                    </xsl:with-param>
                                </xsl:call-template>
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
    
    <xsl:template name="injectMatchTags">
        <xsl:param name="listOfOffsets" as="xs:integer*"/>
        <xsl:param name="listOflengths" as="xs:integer*"/>
        <xsl:param name="previousMatches" as="node()*" select="()"/>
        <xsl:choose>
            <xsl:when test="count($listOflengths) = 0">
                <xsl:sequence select="$previousMatches"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:call-template name="injectMatchTags">
                    <xsl:with-param name="previousMatches">
                        <xsl:if test="$listOfOffsets[last()] &gt; 0">
                            <xsl:value-of select="substring($previousMatches/text()[1],0,$listOfOffsets[last()])"/>
                        </xsl:if>
                        <exist:match>
                            <xsl:value-of select="substring($previousMatches/text()[1],$listOfOffsets[last()],$listOflengths[last()])"/>
                        </exist:match>
                        <xsl:if test="string-length($previousMatches/text()[1]) &gt; ($listOflengths[last()]+$listOfOffsets[last()])">
                            <xsl:value-of select="substring($previousMatches/text()[1],$listOflengths[last()]+$listOfOffsets[last()])"/>
                        </xsl:if>
                        <xsl:sequence select="$previousMatches/*|$previousMatches/text() except $previousMatches/text()[1]"/>
                    </xsl:with-param>
                    <xsl:with-param name="listOflengths" select="subsequence($listOflengths, 1, count($listOflengths) - 1)"/>
                    <xsl:with-param name="listOfOffsets" select="subsequence($listOfOffsets, 1, count($listOfOffsets) - 1)"/>
                </xsl:call-template>             
            </xsl:otherwise>
        </xsl:choose>             
    </xsl:template>
    
    <xsl:template match="*[@orig]">
        <xsl:value-of select="data(@orig)"/>
    </xsl:template>
    
</xsl:stylesheet>