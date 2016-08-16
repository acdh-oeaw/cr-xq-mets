<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:exist="http://exist.sourceforge.net/NS/exist" xmlns:fcs="http://clarin.eu/fcs/1.0" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl" xmlns:cr="http://aac.ac.at/content_repository" xmlns:tei="http://www.tei-c.org/ns/1.0" version="2.0" exclude-result-prefixes="#all">
    
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
    <xsl:output method="xml" indent="yes"/>
    <xsl:preserve-space elements="*"/>
    <xd:doc>
        <xd:desc>A list of cr:ids with possibly a start and a length and a resource fragment id
        <xd:p></xd:p>
        </xd:desc>
    </xd:doc>
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
    
    <xsl:template match="node() | @*" mode="#all">
        <xsl:if test="not(empty($all-ids))">
            <xsl:copy copy-namespaces="no">
                <xsl:apply-templates select="node() | @*" mode="#current"/>                
            </xsl:copy>
        </xsl:if>
    </xsl:template>
    
    <xsl:variable name="genfuns">
        ({<cr:gen-fun>offsets</cr:gen-fun>},{<cr:gen-fun>lengths</cr:gen-fun>})
    </xsl:variable>
    
    <xsl:template match="*[@cr:id = $all-ids]" priority="1">
        <xsl:variable name="elt" as="element()" select="."/>
        <xsl:variable name="cr:id" select="data(@cr:id)"/>
        <xsl:variable name="id-parsed" select="$ids-parsed[id = $cr:id and (not(exists(length)) or length != string-length($elt))]"/>
        <xsl:variable name="offsets" select="for $o in $id-parsed[(rfpid = '') or (rfpid=$rfpid)]/offset return xs:integer($o) " as="xs:integer*"/>
        <xsl:variable name="lengths" select="for $l in $id-parsed[(rfpid = '') or (rfpid=$rfpid)]/length return xs:integer($l)" as="xs:integer*"/>
        <xsl:copy copy-namespaces="no">
            <xsl:copy-of select="@*"/>
            <xsl:choose>
                <!-- we want to be sure that we do not highlight whole resourcefragments -->
                <xsl:when test="exists(parent::element())">
                    <xsl:choose>
                        <xsl:when test="exists($offsets) and exists($lengths)">
                            <xsl:variable name="highlight-ends" select="for $i in (1 to count($offsets)) return $offsets[$i] + $lengths[$i]"/>
                            <xsl:variable name="texts" select="$elt//text()"/>
                            <xsl:variable name="texts-lengths" select="for $str in $texts return string-length($str)"/>
                            <xsl:variable name="texts-offsets" select="cr:calculate-offsets($texts-lengths)"/>
                            <xsl:variable name="texts-offsets-before-match" select="for $o in $offsets return $texts-offsets[some $o2 in . satisfies $o2 &lt; $o][last()]"/>
                            <xsl:variable name="texts-offsets-before-match-end" select="for $e in $highlight-ends return $texts-offsets[some $o2 in . satisfies $o2 &lt; $e][last()]"/>
                            <xsl:variable name="splitted-offsets" select="cr:calculate-splitted($offsets, $lengths, $texts-offsets,  $texts-offsets-before-match, $texts-offsets-before-match-end, $genfuns/*[. = 'offsets'])"/>
                            <xsl:variable name="splitted-lengths" select="cr:calculate-splitted($offsets, $lengths, $texts-offsets, $texts-offsets-before-match, $texts-offsets-before-match-end, $genfuns/*[. = 'lengths'])"/>
                            <xsl:copy>
                                <xsl:copy-of select="@*"/>
                                <xsl:apply-templates select="*|$texts" mode="injectMatches">
                                    <xsl:with-param name="offsets" select="$splitted-offsets" tunnel="yes"/>
                                    <xsl:with-param name="lengths" select="$splitted-lengths" tunnel="yes"/>
                                    <xsl:with-param name="texts" select="$texts" tunnel="yes"/>
                                    <xsl:with-param name="texts-lengths" select="$texts-lengths" tunnel="yes"/>
                                    <xsl:with-param name="texts-offsets" select="$texts-offsets" tunnel="yes"/>
                                    <xsl:with-param name="texts-offsets-before-match" select="$texts-offsets-before-match" tunnel="yes"/>
                                    <xsl:with-param name="texts-offsets-before-match-end" select="$texts-offsets-before-match-end" tunnel="yes"/>
                                </xsl:apply-templates>
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
    
    <xd:doc>
        <xd:desc>In viDicts some lexical information is obvoius only to humans
            reading the text so was replaced by markup and the original text retained in the orig attribute.
            <xd:p><xd:i>Note:</xd:i>This is most probably the wrong place for this type of transformation.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template match="*[@orig]" mode="injectMatches">
        <xsl:param name="offsets" tunnel="yes"/>
        <xsl:param name="lengths" tunnel="yes"/>
        <xsl:param name="texts" tunnel="yes"/>
        <xsl:param name="texts-lengths" tunnel="yes"/>
        <xsl:param name="texts-offsets" tunnel="yes"/>
        <xsl:param name="texts-offsets-before-match" tunnel="yes"/>
        <xsl:param name="texts-offsets-before-match-end" tunnel="yes"/>
        <xsl:variable name="texts-ids" select="for $t in $texts return generate-id($t)"/>
        <xsl:variable name="current-text-sequence-position" select="index-of($texts-ids, generate-id(.))"/>
        <xsl:variable name="relative-offsets" select="for $o in $offsets return $o - $texts-offsets[$current-text-sequence-position]"/>
        <xsl:variable name="should-inject" select="$texts-offsets[$current-text-sequence-position] = ($texts-offsets-before-match, $texts-offsets-before-match-end) and count($relative-offsets) ne 0"/>
        <xsl:choose>
            <xsl:when test="$should-inject">
                <xsl:call-template name="injectMatchTags">
                    <xsl:with-param name="listOfOffsets" select="$relative-offsets"/>
                    <xsl:with-param name="listOflengths" select="$lengths"/>
                    <xsl:with-param name="previousMatches">
                        <xsl:value-of select="data(@orig)"/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>                
                <xsl:value-of select="data(@orig)"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xd:doc>
        <xd:desc>If the text() node contains a match us the named template to inject the match
            tags at the position given as the parameter to this script.
        </xd:desc>
    </xd:doc>
    <xsl:template match="text()" mode="injectMatches" priority="5">
        <xsl:param name="offsets" tunnel="yes"/>
        <xsl:param name="lengths" tunnel="yes"/>
        <xsl:param name="texts" tunnel="yes"/>
        <xsl:param name="texts-lengths" tunnel="yes"/>
        <xsl:param name="texts-offsets" tunnel="yes"/>
        <xsl:param name="texts-offsets-before-match" tunnel="yes"/>
        <xsl:param name="texts-offsets-before-match-end" tunnel="yes"/>
        <xsl:variable name="texts-ids" select="for $t in $texts return generate-id($t)"/>
        <xsl:variable name="current-text-sequence-position" select="index-of($texts-ids, generate-id(.))"/>
        <xsl:variable name="relative-offsets" select="for $o in $offsets return $o - $texts-offsets[$current-text-sequence-position]"/>
        <xsl:variable name="should-inject" select="$texts-offsets[$current-text-sequence-position] = ($texts-offsets-before-match, $texts-offsets-before-match-end) and count($relative-offsets) ne 0"/>
        <xsl:choose>
            <xsl:when test="$should-inject">
                <xsl:call-template name="injectMatchTags">
                    <xsl:with-param name="listOfOffsets" select="$relative-offsets"/>
                    <xsl:with-param name="listOflengths" select="$lengths"/>
                    <xsl:with-param name="previousMatches">
                        <xsl:value-of select="."/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>                
                <xsl:value-of select="."/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xd:doc xml:space="">
        <xd:desc>Cuts up the text and inserts the exst:match where appropriate
        </xd:desc>
        <xd:param name="previousMatches"><xd:i>Note:</xd:i>This needs to be a XML structure containing text() not a text node.</xd:param>
    </xd:doc>
    <xsl:template name="injectMatchTags">
        <xsl:param name="listOfOffsets" as="xs:integer*"/>
        <xsl:param name="listOflengths" as="xs:integer*"/>
        <xsl:param name="texts" as="text()*"/>
        <xsl:param name="previousMatches" as="node()*" select="()"/>
        <xsl:choose>
            <xsl:when test="count($listOflengths) = 0 or 0 >= $listOfOffsets[last()]">
                <xsl:sequence select="$previousMatches"/>
            </xsl:when>
            <xsl:when test="$listOfOffsets[last()] > string-length($previousMatches)">
                <xsl:call-template name="injectMatchTags">
                    <xsl:with-param name="previousMatches" select="$previousMatches"/>
                    <xsl:with-param name="listOflengths" select="subsequence($listOflengths, 1, count($listOflengths) - 1)"/>
                    <xsl:with-param name="listOfOffsets" select="subsequence($listOfOffsets, 1, count($listOfOffsets) - 1)"/>
                </xsl:call-template>                  
            </xsl:when>
            <xsl:otherwise>
                <xsl:call-template name="injectMatchTags">
                    <xsl:with-param name="previousMatches">
                        <xsl:value-of select="substring($previousMatches/text()[1],0,$listOfOffsets[last()])"/>
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
    
    <xsl:function name="cr:calculate-offsets">
        <xsl:param name="text-lengths" as="xs:integer*"/>
        <xsl:sequence select="
            if (empty($text-lengths)) then ()
            else (cr:calculate-offsets(subsequence($text-lengths, 1, count($text-lengths) -1)),
            sum(subsequence($text-lengths, 1, count($text-lengths) - 1)))"></xsl:sequence>
    </xsl:function>
    
    <xsl:function name="cr:calculate-splitted" as="xs:integer*">
        <xsl:param name="offsets" as="xs:integer*"/>
        <xsl:param name="lengths" as="xs:integer*"/>
        <xsl:param name="texts-offsets" as="xs:integer*"/>
        <xsl:param name="texts-offsets-before-match" as="xs:integer*"/>        
        <xsl:param name="texts-offsets-before-match-end" as="xs:integer*"/>
        <xsl:param name="gen-fun" as="element(cr:gen-fun)"/>
        <xsl:variable name="texts-offsets-with-match-parts" select="distinct-values(
            for $i in (1 to count($texts-offsets-before-match)) 
            return 
              for $j in (index-of($texts-offsets, $texts-offsets-before-match[$i]) to index-of($texts-offsets, $texts-offsets-before-match-end[$i]))
                return $texts-offsets[$j])"/>
        <xsl:for-each select="$offsets">
            <xsl:variable name="index" select="index-of($offsets, .)"/>
            <xsl:variable name="offset" select="." as="xs:integer"/>
            <xsl:variable name="length" select="$lengths[$index]" as="xs:integer"/>
            <xsl:for-each select="$texts-offsets">
                <xsl:variable name="text-index" select="index-of($texts-offsets, .)"/>
                <xsl:variable name="text-offset" select="."/>
                <xsl:variable name="text-length" select="$texts-offsets[$text-index + 1] - $texts-offsets[$text-index]"/>
                <xsl:variable name="rel-offset" select="$offset - $text-offset"/>                
                <xsl:if test="($offset >= $text-offset or $offset + $length >= $text-offset) and ($text-offset + $text-length > $offset or $text-offset + $text-length > $offset + $length)">
                    <xsl:choose>
                        <xsl:when test="$gen-fun[.='offsets']">                           
                            <xsl:sequence select="if ($offset >= $text-offset) then $offset else ($text-offset + 1)"></xsl:sequence> 
                        </xsl:when>
                        <xsl:when test="$gen-fun[.='lengths']">
                            <xsl:sequence select="if ($offset >= $text-offset) then $length else $length + $rel-offset"></xsl:sequence>
                        </xsl:when>
                    </xsl:choose>
                </xsl:if>              
            </xsl:for-each>   
        </xsl:for-each>   
    </xsl:function>
    
</xsl:stylesheet>