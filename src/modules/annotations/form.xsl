<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="http://www.w3.org/1999/xhtml" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl" xmlns:an="http://aac.ac.at/content_repository/annotations" exclude-result-prefixes="#all" version="2.0">
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>
                <xd:b>Created on:</xd:b> Sep 30, 2014</xd:p>
            <xd:p>
                <xd:b>Author:</xd:b> transforms a annotation:class element into a HTML form</xd:p>
            <xd:p/>
        </xd:desc>
    </xd:doc>
    <xsl:param name="projectPID"/>
    <xsl:param name="resourcePID"/>
    <xsl:param name="resourcefragmentPID"/>
    <xsl:param name="crID"/>
    <xsl:param name="annotation-id"/>
    <xsl:param name="annotation-url"/>
    <xsl:param name="method">POST</xsl:param>
    <xsl:param name="action">annotations</xsl:param>
    <xsl:param name="data"/>
    <xsl:param name="user"/>
    <xsl:variable name="annotation" as="element(an:annotation)*">
        <xsl:for-each select="tokenize($data,'\s*;\s*')">
            <xsl:sequence select="doc(substring-before(.,':'))//an:annotation[@xml:id = substring-after(current(),':')]"/>
        </xsl:for-each>
    </xsl:variable>
    <xsl:template match="an:class">
        <form action="{$action}" method="{$method}">
            <input type="hidden" name="action" value="set"/>
            <input type="hidden" name="class" value="{@name}"/>
            <xsl:if test="$user!=''">
                <input type="hidden" name="user" value="{$user}"/>
            </xsl:if>
            <xsl:if test="$projectPID!=''">
                <input name="projectPID" type="hidden" value="{$projectPID}"/>
            </xsl:if>
            <xsl:if test="$annotation-id!=''">
                <input name="annotation-id" type="hidden" value="{$annotation-id}"/>
            </xsl:if>
            <xsl:if test="$resourcePID!=''">
                <input name="resourcePID" type="hidden" value="{$resourcePID}"/>
            </xsl:if>
            <xsl:if test="$resourcefragmentPID!=''">
                <input name="resourcefragmentPID" type="hidden" value="{$resourcefragmentPID}"/>
            </xsl:if>
            <xsl:if test="$crID!=''">
                <input name="crID" type="hidden" value="{$crID}"/>
            </xsl:if>
            <table>
                <tbody>
                    <xsl:apply-templates/>
                    <tr>
                        <td>
                            <button type="submit">Store</button>
                            <button type="reset">Reset</button>
                        </td>
                    </tr>
                </tbody>
            </table>
        </form>
    </xsl:template>
    <xsl:template match="an:category">
        <xsl:variable name="category" select="."/>
        <xsl:variable name="cardinality">
            <xsl:choose>
                <xsl:when test="@cardinality = 'unbound'">1</xsl:when>
                <xsl:when test="not(@cardinality)">1</xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="@cardinality"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <tr>
            <xsl:for-each select="1 to $cardinality">
                <xsl:variable name="pos" select="."/>
                <td>
                    <xsl:value-of select="$category/(@label[.!=''],@name)[1]"/>
                </td>
                <td>
                    <xsl:choose>
                        <xsl:when test="$category/@type = 'checkbox'">
                            <input name="{$category/@name}{.}" type="{$category/@type}">
                                <xsl:choose>
                                    <xsl:when test="$pos gt 1 and $annotation/*[local-name() = concat($category/@type,$pos)]">
                                        <xsl:attribute name="value">
                                            <xsl:value-of select="$annotation/*[local-name() = concat($category/@type,$pos)]"/>
                                        </xsl:attribute>
                                    </xsl:when>
                                    <xsl:when test="$annotation/*[local-name() = $category/@type]">
                                        <xsl:attribute name="value">
                                            <xsl:value-of select="$annotation/*[local-name() = $category/@type]"/>
                                        </xsl:attribute>
                                    </xsl:when>
                                </xsl:choose>
                            </input>
                        </xsl:when>
                        <xsl:when test="$category/@type = 'textarea'">
                            <textarea name="{$category/@name}{.}"/>
                        </xsl:when>
                        <xsl:when test="$category/@type = 'select'">
                            <select name="{$category/@name}{.}">
                                <xsl:for-each select="tokenize($category/@values,'\s*,\s*')">
                                    <option value="{.}">
                                        <xsl:value-of select="."/>
                                    </option>
                                </xsl:for-each>
                            </select>
                        </xsl:when>
                        <xsl:otherwise>
                            <input name="{$category/@name}{.}"/>
                        </xsl:otherwise>
                    </xsl:choose>
                    <xsl:if test="$category/@cardinality = 'unbound'">
                        <button class="addCategory">add</button>
                        <button class="removeCategory">remove</button>
                    </xsl:if>
                    <xsl:if test="$category/@desc">
                        <a class="hint">
                            <span class="hintHook ui-icon ui-icon-help">?</span>
                            <span class="hintContent">
                                <xsl:value-of select="$category/@desc"/>
                            </span>
                        </a>
                    </xsl:if>
                </td>
            </xsl:for-each>
        </tr>
    </xsl:template>
</xsl:stylesheet>