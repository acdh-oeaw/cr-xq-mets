<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:sru="http://www.loc.gov/zing/srw/" xmlns:fcs="http://clarin.eu/fcs/1.0" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:cr="http://aac.ac.at/content_repository" version="2.0">


    <!--
        two tasks (in separate calls, managed by $mode-param):
        1. produces an index by grouping content	
        2. selects a subsequence of the produced content
    -->
    <xsl:param name="scan-clause"/>
    <xsl:param name="mode" select="'aggregate'"/>
    <xsl:param name="sort" select="'text'"/>
    <xsl:param name="filter" select="''"/>
    <xsl:param name="filter-mode" select="if (starts-with($filter,'*')) then 'contains' else 'starts-with'"/>
    <xd:doc xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl">
        <xd:desc>
            <xd:p>filter without '*'</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:param name="filter-x" select="lower-case(translate($filter,'*',''))"/>
    <!-- contains, starts-with -->
    <xsl:param name="start-item" select="1"/>
    <xsl:param name="response-position" select="1"/>
    <xsl:param name="max-items" select="100"/>
    <xsl:param name="x-context"/>
    <!-- if max-items=0 := return all -->
    <xsl:output indent="yes"/>
    <xsl:template match="/">
        <!--		
            <params mode="{$mode}" sort="{$sort}"  /> -->
        <sru:scanResponse>
            <sru:version>1.2</sru:version>
            <xsl:choose>
                <xsl:when test="$mode='subsequence'">
                    <!--                    don't go descendants-axis, because of nested terms
                        <xsl:apply-templates mode="subsequence" select=".//sru:terms"/>-->
                    <xsl:apply-templates mode="subsequence" select="sru:scanResponse/sru:terms"/>
                    <!-- dont copy the sru:terms on next level they are handled recursively in subsequence-mode -->
                    <sru:extraResponseData>
                        <xsl:copy-of select="sru:scanResponse/sru:extraResponseData/*[not(local-name()='terms')]"/>
                    </sru:extraResponseData>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:variable name="terms">
                        <xsl:apply-templates/>
                    </xsl:variable>
                    <!--                    <xsl:sequence select="$terms"/>-->
                    <xsl:apply-templates/>
                    <sru:extraResponseData>
                        <fcs:countTerms>
                            <xsl:value-of select="count($terms//sru:term)"/>
                        </fcs:countTerms>
                    </sru:extraResponseData>
                </xsl:otherwise>
            </xsl:choose>
            <sru:echoedScanRequest>
                <sru:scanClause>
                    <xsl:value-of select="$scan-clause"/>
                </sru:scanClause>
                <sru:maximumTerms>
                    <xsl:value-of select="$max-items"/>
                </sru:maximumTerms>
            </sru:echoedScanRequest>
        </sru:scanResponse>
    </xsl:template>
    <xsl:template match="nodes[*]">
        <sru:terms>
            <xsl:copy-of select="@*"/>
            <xsl:choose>
                <xsl:when test="group">
                    <xsl:apply-templates/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:call-template name="group"/>
                </xsl:otherwise>
            </xsl:choose>
        </sru:terms>
    </xsl:template>

    <!-- if filter by default use only filtered data, except when sort=text and either filter mode = starts-with (only sensible result )
        or the response-position is other than 1 (needed for navigation scan)
        than use the subsequence of the data-set, starting from first filter-matching term +/- response-position  -->
    <xsl:template match="sru:terms" mode="subsequence">
<!--        <xsl:variable name="only-filtered" select="not($sort='text' and ($filter-mode='starts-with' or not(xs:integer($response-position) = 1)))"/>-->
        <xsl:variable name="only-filtered" select="true()"/>
        <!-- position of the matching term within the index, if there is a filter -->
        <!-- only filter leaves, not higher level terms -->
        <xsl:variable name="filtered" select="./sru:term[if ($filter-x!='' and not(sru:extraTermData/sru:terms) ) then                      if ($filter-mode='starts-with') then (starts-with(lower-case(sru:value),$filter-x)                      or starts-with(lower-case(sru:displayTerm),$filter-x))                           else (contains(lower-case(sru:value), $filter-x) or contains(lower-case(sru:displayTerm), $filter-x))                            else true()]"/>
        <xsl:variable name="match-position" select="count(sru:term[.=$filtered[1]]/preceding-sibling::sru:term)"/>

        <!--        <xsl:message><xsl:value-of select="$match-position" /></xsl:message>-->
        <xsl:message>scan-clause: <xsl:value-of select="$scan-clause"/> filter: <xsl:value-of select="$filter"/> only-filtered: <xsl:value-of select="$only-filtered"/> count:
                <xsl:value-of select="count($filtered)"/>
        </xsl:message>

        <!-- expect ordered data 
            except for cmd.profile ! -->
        <xsl:variable name="ordered">
            <xsl:choose>
                <xsl:when test="contains($scan-clause, 'cmd.profile')">
                    <xsl:choose>
                        <xsl:when test="$sort='text'">
                            <xsl:for-each select="$filtered">
                                <xsl:sort select="lower-case(sru:displayTerm)" data-type="text" order="ascending"/>
                                <xsl:copy-of select="."/>
<!--                                    <xsl:copy-of select="."></xsl:copy-of>>-->
                            </xsl:for-each>
                        </xsl:when>
                        <xsl:otherwise>
                            <!-- sort=size -->
                            <xsl:for-each select="$filtered">
                                <xsl:sort select="sru:numberOfRecords" data-type="number" order="descending"/>
                                <xsl:copy-of select="."/>
<!--                                    <xsl:apply-templates select="." ></xsl:apply-templates>-->
                            </xsl:for-each>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:when>
                <xsl:when test="$only-filtered">
                    <xsl:copy-of select="$filtered"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:copy-of select="*"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:message>ordered: <xsl:value-of select="count($ordered/*)"/>
        </xsl:message>

        <!-- 		<xsl:variable name="count-items" select="count($filtered)" />-->
        <xsl:copy>
            <!--            <xsl:copy-of select="@*" />-->

            <!--			<xsl:attribute name="count_items" select="if (xs:integer($count-items) > xs:integer($max-items)) then $max-items else $count-items" /> -->
            <!--            <xsl:message>cnt:<xsl:value-of select="count($ordered/*)"/>-match:<xsl:value-of select="$match-position"/>-start:<xsl:value-of select="$effective-start-item"/>-end:<xsl:value-of select="$effective-end-item"/>
                </xsl:message>-->
            <xsl:variable name="start-pos" select="if ($only-filtered) then 0 else xs:integer($match-position)"/>
            <xsl:variable name="effective-start-item" select="xs:integer($start-item) + $start-pos - xs:integer($response-position) + 1"/>
            <xsl:variable name="effective-end-item" select="xs:integer($effective-start-item) + xs:integer($max-items)"/>
            <xsl:apply-templates select="$ordered/*[xs:integer(position()) &gt;= xs:integer($effective-start-item) and ((xs:integer(position()) &lt; (xs:integer($effective-end-item))) or xs:integer($max-items)=0)]">
                <xsl:with-param name="start-pos" select="$effective-start-item"/>
            </xsl:apply-templates>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="sru:term">
        <xsl:param name="start-pos" select="0"/>
        <!-- dig deaper -->
        <xsl:variable name="subsequence">
            <xsl:apply-templates select="sru:extraTermData/sru:terms" mode="subsequence"/>
        </xsl:variable>
        <xsl:if test="not(sru:extraTermData/sru:terms/sru:term and empty($subsequence/sru:terms/sru:term))">
            <xsl:copy>
                <xsl:copy-of select="*[not(local-name()='extraTermData')]"/>
            <!-- <xsl:attribute name="pos" select="position()"/> -->
                <sru:extraTermData>
                <!--                pass pre-existing sru:extraTermData through-->
                    <xsl:copy-of select="sru:extraTermData/*[not(local-name()='terms')]"/>
                    <fcs:position>
                        <xsl:value-of select="position() + $start-pos"/>
                    </fcs:position>
                    <xsl:sequence select="$subsequence"/>
                </sru:extraTermData>
            </xsl:copy>
        </xsl:if>
    </xsl:template>
    <xsl:template match="group">
        <sru:term>
            <sru:value>
                <xsl:value-of select="@value"/>
            </sru:value>
            <sru:displayTerm>
                <xsl:value-of select="if(@label) then @label else @value"/>
            </sru:displayTerm>
            <sru:extraTermData>
                <!--<cr:type>
                    <xsl:value-of select="@facet"/>
                </cr:type>-->
                <xsl:choose>
                    <xsl:when test="v">
                        <xsl:variable name="terms" as="item()*">
                            <xsl:call-template name="group"/>
                        </xsl:variable>
                        <xsl:message select="'here'"/>
                        <xsl:message select="count($terms)"/>
                        <fcs:countTerms>
                            <xsl:value-of select="count($terms)"/>
                        </fcs:countTerms>
                        <fcs:position>
                            <xsl:number/>
                        </fcs:position>
                        <sru:terms>
                            <xsl:sequence select="$terms"/>
                        </sru:terms>
                    </xsl:when>
                    <xsl:otherwise>
                        <fcs:countTerms>
                            <xsl:value-of select="count(*)"/>
                        </fcs:countTerms>
                        <fcs:position>
                            <xsl:number/>
                        </fcs:position>
                        <sru:terms>
                            <xsl:apply-templates/>
                        </sru:terms>
                    </xsl:otherwise>
                </xsl:choose>
            </sru:extraTermData>
        </sru:term>
    </xsl:template>
    <xsl:template name="group">
        <xsl:variable name="count-text" select="count(*/text()[.!=''])"/>
        <!-- FIXME: this is not correct, because it counts individual text-nodes.
            if there are nodes with subnodes, text in every child is counted extra-->
        <xsl:variable name="distinct-text-count" select="count(distinct-values(*/text()))"/>
        <xsl:choose>
            <xsl:when test="$sort='text'">
                <xsl:for-each-group select="v" group-by="normalize-space(.)">
                    <xsl:sort select="xs:string(.)" data-type="text" order="ascending"/>
                    <!--                        <xsl:sort select="count(current-group())" data-type="number" order="descending"/>-->
                    <sru:term>
                        <sru:value>
                            <xsl:value-of select=".//text()"/>
                        </sru:value>
                        <xsl:if test="exists(.//@displayTerm)">
                            <sru:displayTerm>
                                <xsl:value-of select="(current-group()//@displayTerm)[1]"/>
                            </sru:displayTerm>
                        </xsl:if>
                        <sru:numberOfRecords>
                            <xsl:value-of select="count(current-group())"/>
                        </sru:numberOfRecords>
                    </sru:term>
                </xsl:for-each-group>
            </xsl:when>
            <xsl:otherwise>
                <xsl:for-each-group select="v" group-by="normalize-space(.)">
                    <xsl:sort select="count(current-group())" data-type="number" order="descending"/>
                    <sru:term>
                        <sru:value>
                            <xsl:value-of select=".//text()"/>
                        </sru:value>
                        <xsl:if test="exists(.//@displayTerm)">
                            <sru:displayTerm>
                                <xsl:value-of select="(current-group()//@displayTerm)[1]"/>
                            </sru:displayTerm>
                        </xsl:if>
                        <sru:numberOfRecords>
                            <xsl:value-of select="count(current-group())"/>
                        </sru:numberOfRecords>
                    </sru:term>
                </xsl:for-each-group>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
</xsl:stylesheet>