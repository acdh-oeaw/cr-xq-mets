<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="http://www.tei-c.org/ns/1.0" xmlns:teidocx="http://www.tei-c.org/ns/teidocx/1.0" xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:w10="urn:schemas-microsoft-com:office:word" xmlns:tbx="http://www.lisa.org/TBX-Specification.33.0.html" xmlns:ve="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:mo="http://schemas.microsoft.com/office/mac/office/2008/main" xmlns:iso="http://www.iso.org/ns/1.0" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:mv="urn:schemas-microsoft-com:mac:vml" xmlns:prop="http://schemas.openxmlformats.org/officeDocument/2006/custom-properties" xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture" xmlns:wne="http://schemas.microsoft.com/office/word/2006/wordml" xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:mml="http://www.w3.org/1998/Math/MathML" xmlns:html="http://www.w3.org/1999/xhtml" xmlns:rel="http://schemas.openxmlformats.org/package/2006/relationships" version="2.0" exclude-result-prefixes="a cp dc dcterms dcmitype prop    html iso m mml mo mv o pic r rel     tbx tei teidocx v xs ve w10 w wne wp">
    <doc xmlns="http://www.oxygenxml.com/ns/doc/xsl" scope="stylesheet" type="stylesheet">
        <desc>
            <p> TEI stylesheet for converting Word docx files to TEI </p>
            <p>This software is dual-licensed:

1. Distributed under a Creative Commons Attribution-ShareAlike 3.0
Unported License http://creativecommons.org/licenses/by-sa/3.0/ 

2. http://www.opensource.org/licenses/BSD-2-Clause
		
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

* Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

This software is provided by the copyright holders and contributors
"as is" and any express or implied warranties, including, but not
limited to, the implied warranties of merchantability and fitness for
a particular purpose are disclaimed. In no event shall the copyright
holder or contributors be liable for any direct, indirect, incidental,
special, exemplary, or consequential damages (including, but not
limited to, procurement of substitute goods or services; loss of use,
data, or profits; or business interruption) however caused and on any
theory of liability, whether in contract, strict liability, or tort
(including negligence or otherwise) arising in any way out of the use
of this software, even if advised of the possibility of such damage.
</p>
            <p>Author: See AUTHORS</p>
            <p>Id: $Id: textruns.xsl 9646 2011-11-05 23:39:08Z rahtz $</p>
            <p>Copyright: 2008, TEI Consortium</p>
        </desc>
    </doc>
    <doc xmlns="http://www.oxygenxml.com/ns/doc/xsl">
        <desc>Processing an inline run of text with its styling</desc>
    </doc>
    <xsl:template match="w:commentReference">
        <xsl:variable name="commentN" select="@w:id"/>
        <xsl:for-each select="document(concat($wordDirectory,'/word/comments.xml'))/w:comments/w:comment[@w:id=$commentN]">
            <note place="comment" resp="{translate(@w:author,' ','_')}">
                <date when="{@w:date}"/>
                <xsl:apply-templates/>
            </note>
        </xsl:for-each>
    </xsl:template>
    <xsl:template match="w:r">
        <xsl:call-template name="processTextrun"/>
    </xsl:template>
    <xsl:template name="processTextrun">
        <xsl:variable name="style">
            <xsl:value-of select="w:rPr/w:rStyle/@w:val"/>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="$style='CommentReference'">
                <xsl:apply-templates/>
            </xsl:when>
            <xsl:when test="$style='mentioned'">
                <mentioned>
                    <xsl:apply-templates/>
                </mentioned>
            </xsl:when>
            <xsl:when test="$style='Hyperlink' and ancestor::w:hyperlink">
                <xsl:call-template name="basicStyles"/>
            </xsl:when>
            <xsl:when test="$style='Hyperlink' and ancestor::w:fldSimple">
                <xsl:call-template name="basicStyles"/>
            </xsl:when>
            <xsl:when test="$style='Hyperlink' and preceding-sibling::w:r[w:instrText][1]/w:instrText">
                <ref>
                    <xsl:attribute name="target">
                        <xsl:for-each select="preceding-sibling::w:r[w:instrText][1]/w:instrText">
                            <xsl:value-of select="substring-before(substring-after(.,'&#34;'),'&#34;')"/>
                        </xsl:for-each>
                    </xsl:attribute>
                    <xsl:call-template name="basicStyles"/>
                </ref>
            </xsl:when>
            <xsl:when test="$style='ref'">
                <ref>
                    <xsl:apply-templates/>
                </ref>
            </xsl:when>
            <xsl:when test="$style='date'">
                <date>
                    <xsl:apply-templates/>
                </date>
            </xsl:when>
            <xsl:when test="$style='orgName'">
                <orgName>
                    <xsl:apply-templates/>
                </orgName>
            </xsl:when>
            <xsl:when test="not($style='')">
                <hi rend="{replace($style,' ','_')}">
                    <xsl:apply-templates/>
                </hi>
            </xsl:when>
            <xsl:otherwise>
                <xsl:call-template name="basicStyles"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <doc xmlns="http://www.oxygenxml.com/ns/doc/xsl">
        <desc>If there is no special style defined, look at the Word
      underlying basic formatting. We can ignore the run's font change if 
      a) it's not a special para AND the font is the ISO default, OR 
      b) the font for the run is the same as its parent paragraph.
      </desc>
    </doc>
    <xsl:template name="basicStyles">
        <xsl:variable name="styles">
            <xsl:if test="w:rPr/w:rFonts//@w:ascii">
                <xsl:if test="(not(matches(parent::w:p/w:pPr/w:pStyle/@w:val,'Special')) and not(matches(w:rPr/w:rFonts/@w:ascii,'Calibri'))) or    not(w:rPr/w:rFonts/@w:ascii = parent::w:p/w:pPr/w:rPr/w:rFonts/@w:ascii)">
                    <xsl:if test="$preserveEffects='true'">
                        <s n="font-family">
                            <xsl:value-of select="w:rPr/w:rFonts/@w:ascii"/>
                        </s>
                    </xsl:if>
	    <!-- w:ascii="Courier New" w:hAnsi="Courier New" w:cs="Courier New" -->
	    <!-- what do we want to do about cs (Complex Scripts), hAnsi (high ANSI), eastAsia etc? -->
                </xsl:if>
            </xsl:if>
            <xsl:if test="w:rPr/w:sz">
                <s n="font-size">
                    <xsl:value-of select="number(w:rPr/w:sz/@w:val) div 2"/>
                    <xsl:text>pt</xsl:text>
                </s>
            </xsl:if>
            <xsl:if test="w:rPr/w:position/@w:val and not(w:rPr/w:position/@w:val='0')">
                <s n="position">
                    <xsl:value-of select="w:rPr/w:position/@w:val"/>
                </s>
            </xsl:if>
        </xsl:variable>
        <xsl:variable name="dir">
	<!-- right-to-left text -->
            <xsl:if test="w:rPr/w:rtl or parent::w:p/w:pPr/w:rPr/w:rtl">
                <xsl:text>rtl</xsl:text>
            </xsl:if>
        </xsl:variable>
        <xsl:variable name="effects">
            <xsl:if test="w:rPr/w:position[number(@w:val)&lt;-2]">
                <n>subscript</n>
            </xsl:if>
            <xsl:if test="w:rPr/w:i">
                <n>italic</n>
            </xsl:if>
            <xsl:choose>
                <xsl:when test="w:rPr/w:b/@w:val='0'">
                    <n>normalweight</n>
                </xsl:when>
                <xsl:when test="w:rPr/w:b">
                    <n>bold</n>
                </xsl:when>
            </xsl:choose>
            <xsl:if test="w:rPr/w:position[number(@w:val)&gt;2]">
                <n>superscript</n>
            </xsl:if>
            <xsl:if test="w:rPr/w:vertAlign">
                <n>
                    <xsl:value-of select="w:rPr/w:vertAlign/@w:val"/>
                </n>
            </xsl:if>
            <xsl:if test="w:rPr/w:strike">
                <n>strikethrough</n>
            </xsl:if>
            <xsl:if test="w:rPr/w:dstrike">
                <n>strikedoublethrough</n>
            </xsl:if>
            <xsl:if test="w:rPr/w:u[@w:val='single']">
                <n>underline</n>
            </xsl:if>
            <xsl:if test="w:rPr/w:u[@w:val='wave']">
                <n>underwavyline</n>
            </xsl:if>
            <xsl:if test="w:rPr/w:u[@w:val='double']">
                <n>underdoubleline</n>
            </xsl:if>
            <xsl:if test="w:rPr/w:smallCaps">
                <n>smallcaps</n>
            </xsl:if>
            <xsl:if test="w:rPr/w:caps">
                <n>capsall</n>
            </xsl:if>
            <xsl:if test="w:rPr/w:color and         not(w:rPr/w:color/@w:val='000000' or w:rPr/w:color/@w:val='auto')">
                <n>
                    <xsl:text>color(</xsl:text>
                    <xsl:value-of select="w:rPr/w:color/@w:val"/>
                    <xsl:text>)</xsl:text>
                </n>
            </xsl:if>
            <xsl:if test="w:rPr/w:highlight">
                <n>
                    <xsl:text>background(</xsl:text>
                    <xsl:value-of select="w:rPr/w:highlight/@w:val"/>
                    <xsl:text>)</xsl:text>
                </n>
            </xsl:if>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="$effects/* or ($styles/* and $preserveEffects='true')">
                <hi>
                    <xsl:if test="$dir!='' and $preserveEffects='true'">
                        <xsl:attribute xmlns="http://www.w3.org/2005/11/its" name="dir" select="$dir"/>
                    </xsl:if>
                    <xsl:choose>
                        <xsl:when test="$effects/*">
                            <xsl:attribute name="rend">
                                <xsl:for-each select="$effects/*">
                                    <xsl:value-of select="."/>
                                    <xsl:if test="following-sibling::*">
                                        <xsl:text> </xsl:text>
                                    </xsl:if>
                                </xsl:for-each>
                            </xsl:attribute>
                        </xsl:when>
                        <xsl:when test="$preserveEffects='true'">
                            <xsl:attribute name="rend">
                                <xsl:text>isoStyle</xsl:text>
                            </xsl:attribute>
                        </xsl:when>
                    </xsl:choose>
                    <xsl:if test="$styles/* and $preserveEffects='true'">
                        <xsl:attribute name="html:style">
                            <xsl:for-each select="$styles/*">
                                <xsl:value-of select="@n"/>
                                <xsl:text>:</xsl:text>
                                <xsl:value-of select="."/>
                                <xsl:text>;</xsl:text>
                            </xsl:for-each>
                        </xsl:attribute>
                    </xsl:if>
                    <xsl:apply-templates/>
                </hi>
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <doc xmlns="http://www.oxygenxml.com/ns/doc/xsl">
        <desc>
        Handle Text, Comments, Tabs, Symbols etc. 
    </desc>
    </doc>
    <xsl:template match="w:t">
        <xsl:variable name="t">
            <xsl:choose>
                <xsl:when test="@xml:space='preserve' and string-length(normalize-space(.))=0">
                    <seg>
                        <xsl:text> </xsl:text>
                    </seg>
                </xsl:when>
                <xsl:when test="@xml:space='preserve'">
                    <xsl:value-of select="."/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="normalize-space(.)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="parent::w:r/w:rPr/w:rFonts[starts-with(@w:ascii,'ISO')]">
                <seg html:style="font-family:{parent::w:r/w:rPr/w:rFonts/@w:ascii};">
                    <xsl:value-of select="$t"/>
                </seg>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy-of select="$t"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <doc xmlns="http://www.oxygenxml.com/ns/doc/xsl">
        <desc>
        Convert special characters (w:syms) into Unicode characters or
	<gi>g</gi> elements. Symbol to Unicode mapping from http://unicode.org/Public/MAPPINGS/VENDORS/ADOBE/symbol.txt
    </desc>
    </doc>
    <xsl:template match="w:sym">
        <xsl:choose>
            <xsl:when test="@w:font='Symbol' or @w:font='MT Symbol'">
                <xsl:choose>
                    <xsl:when test="@w:char='F022'">∀</xsl:when><!--	# FOR ALL # universal -->
                    <xsl:when test="@w:char='F024'">∃</xsl:when><!--	# THERE EXISTS # existential -->
                    <xsl:when test="@w:char='F025'">%</xsl:when><!--	# PERCENT SIGN # percent -->
                    <xsl:when test="@w:char='F026'">&amp;</xsl:when><!--	# AMPERSAND # ampersand -->
                    <xsl:when test="@w:char='F027'">∋</xsl:when><!--	# CONTAINS AS MEMBER	# suchthat -->
                    <xsl:when test="@w:char='F028'">(</xsl:when><!--	# LEFT PARENTHESIS	# parenleft -->
                    <xsl:when test="@w:char='F029'">)</xsl:when><!--	# RIGHT PARENTHESIS	# parenright -->
                    <xsl:when test="@w:char='F02A'">∗</xsl:when><!--	# ASTERISK OPERATOR	# asteriskmath -->
                    <xsl:when test="@w:char='F02B'">+</xsl:when><!--	# PLUS SIGN # plus -->
                    <xsl:when test="@w:char='F02C'">,</xsl:when><!--	# COMMA	# comma -->
                    <xsl:when test="@w:char='F02D'">−</xsl:when><!--	# MINUS SIGN # minus -->
                    <xsl:when test="@w:char='F02E'">.</xsl:when><!--	# FULL STOP # period -->
                    <xsl:when test="@w:char='F02F'">/</xsl:when><!--	# SOLIDUS # slash -->
                    <xsl:when test="@w:char='F030'">0</xsl:when>
                    <xsl:when test="@w:char='F031'">1</xsl:when><!--	# DIGIT ONE # one -->
                    <xsl:when test="@w:char='F032'">2</xsl:when><!--	# DIGIT TWO # two -->
                    <xsl:when test="@w:char='F033'">3</xsl:when><!--	# DIGIT THREE # three -->
                    <xsl:when test="@w:char='F034'">4</xsl:when><!--	# DIGIT FOUR # four -->
                    <xsl:when test="@w:char='F035'">5</xsl:when><!--	# DIGIT FIVE # five -->
                    <xsl:when test="@w:char='F036'">6</xsl:when><!--	# DIGIT SIX # six -->
                    <xsl:when test="@w:char='F037'">7</xsl:when><!--	# DIGIT SEVEN # seven -->
                    <xsl:when test="@w:char='F038'">8</xsl:when>
                    <xsl:when test="@w:char='F039'">9</xsl:when><!--	# DIGIT NINE # nine -->
                    <xsl:when test="@w:char='F03A'">:</xsl:when><!--	# COLON	# colon -->
                    <xsl:when test="@w:char='F03B'">;</xsl:when><!--	# SEMICOLON # semicolon -->
                    <xsl:when test="@w:char='F03C'">&lt;</xsl:when><!--	# LESS-THAN SIGN	# less -->
                    <xsl:when test="@w:char='F03D'">=</xsl:when><!--	# EQUALS SIGN # equal -->
                    <xsl:when test="@w:char='F03E'">&gt;</xsl:when><!--	# GREATER-THAN SIGN	# greater -->
                    <xsl:when test="@w:char='F03F'">?</xsl:when><!--	# QUESTION MARK	# question -->
                    <xsl:when test="@w:char='F040'">≅</xsl:when><!--	# APPROXIMATELY EQUAL TO	# congruent -->
                    <xsl:when test="@w:char='F041'">Α</xsl:when><!--	# GREEK CAPITAL LETTER ALPHA	# Alpha -->
                    <xsl:when test="@w:char='F042'">Β</xsl:when><!--	# GREEK CAPITAL LETTER BETA	# Beta -->
                    <xsl:when test="@w:char='F043'">Χ</xsl:when><!--	# GREEK CAPITAL LETTER CHI	# Chi -->
                    <xsl:when test="@w:char='F044'">Δ</xsl:when><!--	# GREEK CAPITAL LETTER DELTA	# Delta -->
                    <xsl:when test="@w:char='F044'">∆</xsl:when><!--	# INCREMENT # Delta -->
                    <xsl:when test="@w:char='F045'">Ε</xsl:when><!--	# GREEK CAPITAL LETTER EPSILON	# Epsilon -->
                    <xsl:when test="@w:char='F046'">Φ</xsl:when><!--	# GREEK CAPITAL LETTER PHI	# Phi -->
                    <xsl:when test="@w:char='F047'">Γ</xsl:when><!--	# GREEK CAPITAL LETTER GAMMA	# Gamma -->
                    <xsl:when test="@w:char='F048'">Η</xsl:when><!--	# GREEK CAPITAL LETTER ETA	# Eta -->
                    <xsl:when test="@w:char='F049'">Ι</xsl:when><!--	# GREEK CAPITAL LETTER IOTA	# Iota -->
                    <xsl:when test="@w:char='F04A'">ϑ</xsl:when><!--	# GREEK THETA SYMBOL	# theta1 -->
                    <xsl:when test="@w:char='F04B'">Κ</xsl:when><!--	# GREEK CAPITAL LETTER KAPPA	# Kappa -->
                    <xsl:when test="@w:char='F04C'">Λ</xsl:when><!--	# GREEK CAPITAL LETTER LAMDA	# Lambda -->
                    <xsl:when test="@w:char='F04D'">Μ</xsl:when><!--	# GREEK CAPITAL LETTER MU	# Mu -->
                    <xsl:when test="@w:char='F04E'">Ν</xsl:when><!--	# GREEK CAPITAL LETTER NU	# Nu -->
                    <xsl:when test="@w:char='F04F'">Ο</xsl:when><!--	# GREEK CAPITAL LETTER OMICRON	# Omicron -->
                    <xsl:when test="@w:char='F050'">Π</xsl:when><!--	# GREEK CAPITAL LETTER PI	# Pi -->
                    <xsl:when test="@w:char='F051'">Θ</xsl:when><!--	# GREEK CAPITAL LETTER THETA	# Theta -->
                    <xsl:when test="@w:char='F052'">Ρ</xsl:when><!--	# GREEK CAPITAL LETTER RHO	# Rho -->
                    <xsl:when test="@w:char='F053'">Σ</xsl:when><!--	# GREEK CAPITAL LETTER SIGMA	# Sigma -->
                    <xsl:when test="@w:char='F054'">Τ</xsl:when><!--	# GREEK CAPITAL LETTER TAU	# Tau -->
                    <xsl:when test="@w:char='F055'">Υ</xsl:when><!--	# GREEK CAPITAL LETTER UPSILON	# Upsilon -->
                    <xsl:when test="@w:char='F056'">ς</xsl:when>
                    <xsl:when test="@w:char='F057'">Ω</xsl:when><!--	# GREEK CAPITAL LETTER OMEGA	# Omega -->
                    <xsl:when test="@w:char='F057'">Ω</xsl:when><!--	# OHM SIGN # Omega -->
                    <xsl:when test="@w:char='F058'">Ξ</xsl:when><!--	# GREEK CAPITAL LETTER XI	# Xi -->
                    <xsl:when test="@w:char='F059'">Ψ</xsl:when><!--	# GREEK CAPITAL LETTER PSI	# Psi -->
                    <xsl:when test="@w:char='F05A'">Ζ</xsl:when><!--	# GREEK CAPITAL LETTER ZETA	# Zeta -->
                    <xsl:when test="@w:char='F05B'">[</xsl:when><!--	# LEFT SQUARE BRACKET	# bracketleft -->
                    <xsl:when test="@w:char='F05C'">∴</xsl:when><!--	# THEREFORE # therefore -->
                    <xsl:when test="@w:char='F05D'">]</xsl:when><!--	# RIGHT SQUARE BRACKET	# bracketright -->
                    <xsl:when test="@w:char='F05E'">⊥</xsl:when><!--	# UP TACK # perpendicular -->
                    <xsl:when test="@w:char='F05F'">_</xsl:when><!--	# LOW LINE # underscore -->
                    <xsl:when test="@w:char='F060'"></xsl:when><!--	# RADICAL EXTENDER	# radicalex (CUS) -->
                    <xsl:when test="@w:char='F061'">α</xsl:when><!--	# GREEK SMALL LETTER ALPHA	# alpha -->
                    <xsl:when test="@w:char='F062'">β</xsl:when><!--	# GREEK SMALL LETTER BETA	# beta -->
                    <xsl:when test="@w:char='F063'">χ</xsl:when><!--	# GREEK SMALL LETTER CHI	# chi -->
                    <xsl:when test="@w:char='F064'">δ</xsl:when><!--	# GREEK SMALL LETTER DELTA	# delta -->
                    <xsl:when test="@w:char='F065'">ε</xsl:when><!--	# GREEK SMALL LETTER EPSILON	# epsilon -->
                    <xsl:when test="@w:char='F066'">φ</xsl:when><!--	# GREEK SMALL LETTER PHI	# phi -->
                    <xsl:when test="@w:char='F067'">γ</xsl:when><!--	# GREEK SMALL LETTER GAMMA	# gamma -->
                    <xsl:when test="@w:char='F068'">η</xsl:when><!--	# GREEK SMALL LETTER ETA	# eta -->
                    <xsl:when test="@w:char='F069'">ι</xsl:when><!--	# GREEK SMALL LETTER IOTA	# iota -->
                    <xsl:when test="@w:char='F06A'">ϕ</xsl:when><!--	# GREEK PHI SYMBOL	# phi1 -->
                    <xsl:when test="@w:char='F06B'">κ</xsl:when><!--	# GREEK SMALL LETTER KAPPA	# kappa -->
                    <xsl:when test="@w:char='F06C'">λ</xsl:when><!--	# GREEK SMALL LETTER LAMDA	# lambda -->
                    <xsl:when test="@w:char='F06D'">µ</xsl:when><!--	# MICRO SIGN # mu -->
                    <xsl:when test="@w:char='F06D'">μ</xsl:when><!--	# GREEK SMALL LETTER MU	# mu -->
                    <xsl:when test="@w:char='F06E'">ν</xsl:when><!--	# GREEK SMALL LETTER NU	# nu -->
                    <xsl:when test="@w:char='F06F'">ο</xsl:when><!--	# GREEK SMALL LETTER OMICRON	# omicron -->
                    <xsl:when test="@w:char='F070'">π</xsl:when><!--	# GREEK SMALL LETTER PI	# pi -->
                    <xsl:when test="@w:char='F071'">θ</xsl:when>
                    <xsl:when test="@w:char='F072'">ρ</xsl:when><!--	# GREEK SMALL LETTER RHO	# rho -->
                    <xsl:when test="@w:char='F073'">σ</xsl:when><!--	# GREEK SMALL LETTER SIGMA	# sigma -->
                    <xsl:when test="@w:char='F074'">τ</xsl:when><!--	# GREEK SMALL LETTER TAU	# tau -->
                    <xsl:when test="@w:char='F075'">υ</xsl:when><!--	# GREEK SMALL LETTER UPSILON	# upsilon -->
                    <xsl:when test="@w:char='F076'">ϖ</xsl:when><!--	# GREEK PI SYMBOL	# omega1 -->
                    <xsl:when test="@w:char='F077'">ω</xsl:when><!--	# GREEK SMALL LETTER OMEGA	# omega -->
                    <xsl:when test="@w:char='F078'">ξ</xsl:when><!--	# GREEK SMALL LETTER XI	# xi -->
                    <xsl:when test="@w:char='F079'">ψ</xsl:when><!--	# GREEK SMALL LETTER PSI	# psi -->
                    <xsl:when test="@w:char='F07A'">ζ</xsl:when><!--	# GREEK SMALL LETTER ZETA	# zeta -->
                    <xsl:when test="@w:char='F07B'">{</xsl:when><!--	# LEFT CURLY BRACKET	# braceleft -->
                    <xsl:when test="@w:char='F07C'">|</xsl:when><!--	# VERTICAL LINE	# bar -->
                    <xsl:when test="@w:char='F07D'">}</xsl:when><!--	# RIGHT CURLY BRACKET	# braceright -->
                    <xsl:when test="@w:char='F07E'">∼</xsl:when><!--	# TILDE OPERATOR	# similar -->
                    <xsl:when test="@w:char='F0A0'">€</xsl:when><!--	# EURO SIGN # Euro -->
                    <xsl:when test="@w:char='F0A1'">ϒ</xsl:when><!--	# GREEK UPSILON WITH HOOK SYMBOL	# Upsilon1 -->
                    <xsl:when test="@w:char='F0A2'">′</xsl:when><!--	# PRIME	# minute -->
                    <xsl:when test="@w:char='F0A3'">≤</xsl:when><!--	# LESS-THAN OR EQUAL TO	# lessequal -->
                    <xsl:when test="@w:char='F0A4'">⁄</xsl:when><!--	# FRACTION SLASH	# fraction -->
                    <xsl:when test="@w:char='F0A4'">∕</xsl:when><!--	# DIVISION SLASH	# fraction -->
                    <xsl:when test="@w:char='F0A5'">∞</xsl:when><!--	# INFINITY # infinity -->
                    <xsl:when test="@w:char='F0A6'">ƒ</xsl:when><!--	# LATIN SMALL LETTER F WITH HOOK	# florin -->
                    <xsl:when test="@w:char='F0A7'">♣</xsl:when><!--	# BLACK CLUB SUIT	# club -->
                    <xsl:when test="@w:char='F0A8'">♦</xsl:when><!--	# BLACK DIAMOND SUIT	# diamond -->
                    <xsl:when test="@w:char='F0A9'">♥</xsl:when><!--	# BLACK HEART SUIT	# heart -->
                    <xsl:when test="@w:char='F0AA'">♠</xsl:when><!--	# BLACK SPADE SUIT	# spade -->
                    <xsl:when test="@w:char='F0AB'">↔</xsl:when><!--	# LEFT RIGHT ARROW	# arrowboth -->
                    <xsl:when test="@w:char='F0AC'">←</xsl:when><!--	# LEFTWARDS ARROW	# arrowleft -->
                    <xsl:when test="@w:char='F0AD'">↑</xsl:when><!--	# UPWARDS ARROW	# arrowup -->
                    <xsl:when test="@w:char='F0AE'">→</xsl:when><!--	# RIGHTWARDS ARROW	# arrowright -->
                    <xsl:when test="@w:char='F0AF'">↓</xsl:when><!--	# DOWNWARDS ARROW	# arrowdown -->
                    <xsl:when test="@w:char='F0B0'">°</xsl:when><!--	# DEGREE SIGN # degree -->
                    <xsl:when test="@w:char='F0B1'">±</xsl:when><!--	# PLUS-MINUS SIGN	# plusminus -->
                    <xsl:when test="@w:char='F0B2'">″</xsl:when><!--	# DOUBLE PRIME # second -->
                    <xsl:when test="@w:char='F0B3'">≥</xsl:when><!--	# GREATER-THAN OR EQUAL TO	# greaterequal -->
                    <xsl:when test="@w:char='F0B4'">×</xsl:when><!--	# MULTIPLICATION SIGN	# multiply -->
                    <xsl:when test="@w:char='F0B5'">∝</xsl:when><!--	# PROPORTIONAL TO	# proportional -->
                    <xsl:when test="@w:char='F0B6'">∂</xsl:when><!--	# PARTIAL DIFFERENTIAL	# partialdiff -->
                    <xsl:when test="@w:char='F0B7'">•</xsl:when><!--	# BULLET # bullet -->
                    <xsl:when test="@w:char='F0B8'">÷</xsl:when><!--	# DIVISION SIGN	# divide -->
                    <xsl:when test="@w:char='F0B9'">≠</xsl:when><!--	# NOT EQUAL TO # notequal -->
                    <xsl:when test="@w:char='F0BA'">≡</xsl:when><!--	# IDENTICAL TO # equivalence -->
                    <xsl:when test="@w:char='F0BB'">≈</xsl:when><!--	# ALMOST EQUAL TO	# approxequal -->
                    <xsl:when test="@w:char='F0BC'">…</xsl:when><!--	# HORIZONTAL ELLIPSIS	# ellipsis -->
                    <xsl:when test="@w:char='F0BD'"></xsl:when><!--	# VERTICAL ARROW EXTENDER	# arrowvertex (CUS) -->
                    <xsl:when test="@w:char='F0BE'"></xsl:when><!--	# HORIZONTAL ARROW EXTENDER	# arrowhorizex (CUS) -->
                    <xsl:when test="@w:char='F0BF'">↵</xsl:when><!--	# DOWNWARDS ARROW WITH CORNER LEFTWARDS	# carriagereturn -->
                    <xsl:when test="@w:char='F0C0'">ℵ</xsl:when><!--	# ALEF SYMBOL # aleph -->
                    <xsl:when test="@w:char='F0C1'">ℑ</xsl:when><!--	# BLACK-LETTER CAPITAL I	# Ifraktur -->
                    <xsl:when test="@w:char='F0C2'">ℜ</xsl:when><!--	# BLACK-LETTER CAPITAL R	# Rfraktur -->
                    <xsl:when test="@w:char='F0C3'">℘</xsl:when><!--	# SCRIPT CAPITAL P	# weierstrass -->
                    <xsl:when test="@w:char='F0C4'">⊗</xsl:when><!--	# CIRCLED TIMES	# circlemultiply -->
                    <xsl:when test="@w:char='F0C5'">⊕</xsl:when><!--	# CIRCLED PLUS # circleplus -->
                    <xsl:when test="@w:char='F0C6'">∅</xsl:when><!--	# EMPTY SET # emptyset -->
                    <xsl:when test="@w:char='F0C7'">∩</xsl:when><!--	# INTERSECTION # intersection -->
                    <xsl:when test="@w:char='F0C8'">∪</xsl:when><!--	# UNION	# union -->
                    <xsl:when test="@w:char='F0C9'">⊃</xsl:when><!--	# SUPERSET OF # propersuperset -->
                    <xsl:when test="@w:char='F0CA'">⊇</xsl:when><!--	# SUPERSET OF OR EQUAL TO	# reflexsuperset -->
                    <xsl:when test="@w:char='F0CB'">⊄</xsl:when><!--	# NOT A SUBSET OF	# notsubset -->
                    <xsl:when test="@w:char='F0CC'">⊂</xsl:when><!--	# SUBSET OF # propersubset -->
                    <xsl:when test="@w:char='F0CD'">⊆</xsl:when><!--	# SUBSET OF OR EQUAL TO	# reflexsubset -->
                    <xsl:when test="@w:char='F0CE'">∈</xsl:when><!--	# ELEMENT OF # element -->
                    <xsl:when test="@w:char='F0CF'">∉</xsl:when><!--	# NOT AN ELEMENT OF	# notelement -->
                    <xsl:when test="@w:char='F0D0'">∠</xsl:when><!--	# ANGLE	# angle -->
                    <xsl:when test="@w:char='F0D1'">∇</xsl:when><!--	# NABLA	# gradient -->
                    <xsl:when test="@w:char='F0D2'"></xsl:when><!--	# REGISTERED SIGN SERIF	# registerserif (CUS) -->
                    <xsl:when test="@w:char='F0D3'"></xsl:when><!--	# COPYRIGHT SIGN SERIF	# copyrightserif (CUS) -->
                    <xsl:when test="@w:char='F0D4'"></xsl:when><!--	# TRADE MARK SIGN SERIF	# trademarkserif (CUS) -->
                    <xsl:when test="@w:char='F0D5'">∏</xsl:when><!--	# N-ARY PRODUCT	# product -->
                    <xsl:when test="@w:char='F0D6'">√</xsl:when><!--	# SQUARE ROOT # radical -->
                    <xsl:when test="@w:char='F0D7'">⋅</xsl:when><!--	# DOT OPERATOR # dotmath -->
                    <xsl:when test="@w:char='F0D8'">¬</xsl:when><!--	# NOT SIGN # logicalnot -->
                    <xsl:when test="@w:char='F0D9'">∧</xsl:when><!--	# LOGICAL AND # logicaland -->
                    <xsl:when test="@w:char='F0DA'">∨</xsl:when><!--	# LOGICAL OR # logicalor -->
                    <xsl:when test="@w:char='F0DB'">⇔</xsl:when><!--	# LEFT RIGHT DOUBLE ARROW	# arrowdblboth -->
                    <xsl:when test="@w:char='F0DC'">⇐</xsl:when><!--	# LEFTWARDS DOUBLE ARROW	# arrowdblleft -->
                    <xsl:when test="@w:char='F0DD'">⇑</xsl:when><!--	# UPWARDS DOUBLE ARROW	# arrowdblup -->
                    <xsl:when test="@w:char='F0DE'">⇒</xsl:when><!--	# RIGHTWARDS DOUBLE ARROW	# arrowdblright -->
                    <xsl:when test="@w:char='F0DF'">⇓</xsl:when><!--	# DOWNWARDS DOUBLE ARROW	# arrowdbldown -->
                    <xsl:when test="@w:char='F0E0'">◊</xsl:when><!--	# LOZENGE # lozenge -->
                    <xsl:when test="@w:char='F0E1'">〈</xsl:when><!--	# LEFT-POINTING ANGLE BRACKET	# angleleft -->
                    <xsl:when test="@w:char='F0E2'"></xsl:when><!--	# REGISTERED SIGN SANS SERIF	# registersans (CUS) -->
                    <xsl:when test="@w:char='F0E3'"></xsl:when><!--	# COPYRIGHT SIGN SANS SERIF	# copyrightsans (CUS) -->
                    <xsl:when test="@w:char='F0E4'"></xsl:when><!--	# TRADE MARK SIGN SANS SERIF	# trademarksans (CUS) -->
                    <xsl:when test="@w:char='F0E5'">∑</xsl:when><!--	# N-ARY SUMMATION	# summation -->
                    <xsl:when test="@w:char='F0E6'"></xsl:when><!--	# LEFT PAREN TOP	# parenlefttp (CUS) -->
                    <xsl:when test="@w:char='F0E7'"></xsl:when><!--	# LEFT PAREN EXTENDER	# parenleftex (CUS) -->
                    <xsl:when test="@w:char='F0E8'"></xsl:when><!--	# LEFT PAREN BOTTOM	# parenleftbt (CUS) -->
                    <xsl:when test="@w:char='F0E9'"></xsl:when><!--	# LEFT SQUARE BRACKET TOP	# bracketlefttp (CUS) -->
                    <xsl:when test="@w:char='F0EA'"></xsl:when><!--	# LEFT SQUARE BRACKET EXTENDER	# bracketleftex (CUS) -->
                    <xsl:when test="@w:char='F0EB'"></xsl:when><!--	# LEFT SQUARE BRACKET BOTTOM	# bracketleftbt (CUS) -->
                    <xsl:when test="@w:char='F0EC'"></xsl:when><!--	# LEFT CURLY BRACKET TOP	# bracelefttp (CUS) -->
                    <xsl:when test="@w:char='F0ED'"></xsl:when><!--	# LEFT CURLY BRACKET MID	# braceleftmid (CUS) -->
                    <xsl:when test="@w:char='F0EE'"></xsl:when><!--	# LEFT CURLY BRACKET BOTTOM	# braceleftbt (CUS) -->
                    <xsl:when test="@w:char='F0EF'"></xsl:when><!--	# CURLY BRACKET EXTENDER	# braceex (CUS) -->
                    <xsl:when test="@w:char='F0F1'">〉</xsl:when><!--	# RIGHT-POINTING ANGLE BRACKET	# angleright -->
                    <xsl:when test="@w:char='F0F2'">∫</xsl:when><!--	# INTEGRAL # integral -->
                    <xsl:when test="@w:char='F0F3'">⌠</xsl:when><!--	# TOP HALF INTEGRAL	# integraltp -->
                    <xsl:when test="@w:char='F0F4'"></xsl:when><!--	# INTEGRAL EXTENDER	# integralex (CUS) -->
                    <xsl:when test="@w:char='F0F5'">⌡</xsl:when><!--	# BOTTOM HALF INTEGRAL	# integralbt -->
                    <xsl:when test="@w:char='F0F6'"></xsl:when><!--	# RIGHT PAREN TOP	# parenrighttp (CUS) -->
                    <xsl:when test="@w:char='F0F7'"></xsl:when><!--	# RIGHT PAREN EXTENDER	# parenrightex (CUS) -->
                    <xsl:when test="@w:char='F0F8'"></xsl:when><!--	# RIGHT PAREN BOTTOM	# parenrightbt (CUS) -->
                    <xsl:when test="@w:char='F0F9'"></xsl:when><!--	# RIGHT SQUAREBRACKET TOP	# bracketrighttp (CUS) -->
                    <xsl:when test="@w:char='F0FA'"></xsl:when><!--	# RIGHT SQUARE BRACKET EXTENDER	# bracketrightex (CUS) -->
                    <xsl:when test="@w:char='F0FB'"></xsl:when><!--	# RIGHT SQUARE BRACKET BOTTOM	# bracketrightbt (CUS) -->
                    <xsl:when test="@w:char='F0FC'"></xsl:when><!--	# RIGHT CURLY BRACKET TOP	# bracerighttp (CUS) -->
                    <xsl:when test="@w:char='F0FD'"></xsl:when><!--	# RIGHT CURLY BRACKET MID	# bracerightmid (CUS) -->
                    <xsl:when test="@w:char='F0FE'"></xsl:when><!--	# RIGHT CURLY BRACKET BOTTOM	# bracerightbt (CUS) -->
                    <xsl:otherwise>
                        <g html:style="font-family:{@w:font};" n="{@w:char}"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <xsl:when test="@w:font='Wingdings 2' and @w:char='F050'">✓</xsl:when><!-- tick mark-->
            <xsl:otherwise>
                <g html:style="font-family:{@w:font};" n="{@w:char}"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <doc xmlns="http://www.oxygenxml.com/ns/doc/xsl">
        <desc>
        handle tabs
    </desc>
    </doc>
    <xsl:template match="w:r/w:tab">
        <xsl:text>	</xsl:text>
    </xsl:template>
    <doc xmlns="http://www.oxygenxml.com/ns/doc/xsl">
        <desc>
        handle ptabs (absolute position tab character)
    </desc>
    </doc>
    <xsl:template match="w:r/w:ptab">
        <c rend="ptab" type="{@w:alignment}">
            <xsl:text>	</xsl:text>
        </c>
    </xsl:template>
    <doc xmlns="http://www.oxygenxml.com/ns/doc/xsl">
        <desc>
        capture line breaks
    </desc>
    </doc>
    <xsl:template match="w:br">
        <xsl:choose>
            <xsl:when test="@w:type='page'">
                <pb/>
            </xsl:when>
            <xsl:otherwise>
                <lb/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <doc xmlns="http://www.oxygenxml.com/ns/doc/xsl">
        <desc>
        Contains text that has been tracked as a revision. 
    </desc>
    </doc>
    <xsl:template match="w:del">
        <del when="{@w:date}">
            <xsl:call-template name="identifyChange">
                <xsl:with-param name="who" select="@w:author"/>
            </xsl:call-template>
            <xsl:apply-templates/>
        </del>
    </xsl:template>
    <xsl:template match="w:rPr/w:del"/>
    <xsl:template match="w:delText">
        <xsl:apply-templates/>
    </xsl:template>
    <xsl:template match="w:ins">
        <add when="{@w:date}">
            <xsl:call-template name="identifyChange">
                <xsl:with-param name="who" select="@w:author"/>
            </xsl:call-template>
            <xsl:call-template name="processTextrun"/>
        </add>
    </xsl:template>
    <xsl:template match="w:rPr/w:ins"/>
    <xsl:template match="w:noBreakHyphen">
        <xsl:text>‑</xsl:text>
    </xsl:template>
</xsl:stylesheet>