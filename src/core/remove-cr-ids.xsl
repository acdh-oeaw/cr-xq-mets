<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:cr="http://aac.ac.at/content_repository" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl" exclude-result-prefixes="xs xd cr" version="2.0">
  <xd:doc scope="stylesheet">
    <xd:desc>
      <xd:p>
        <xd:b>Created on:</xd:b> Feb 4, 2015</xd:p>
      <xd:p>
        <xd:b>Author:</xd:b> DS</xd:p>
      <xd:p>This stylesheets removes internal ids from all elements of a resource.</xd:p>
    </xd:desc>
  </xd:doc>

  <xsl:param name="cr:namespace-uri">http://aac.ac.at/content_repository</xsl:param>
  
  <xsl:template match="node()">
    <xsl:copy>
      <xsl:apply-templates select="node() | @*"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="@*">
    <xsl:choose>
      <xsl:when test="namespace-uri(.) = $cr:namespace-uri"/>
      <xsl:otherwise>
        <xsl:copy-of select="."/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
</xsl:stylesheet>