<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:teix="http://www.tei-c.org/ns/Examples" xmlns:XSL="http://www.w3.org/1999/XSL/Transform" xmlns:estr="http://exslt.org/strings" xmlns:exsl="http://exslt.org/common" xmlns:edate="http://exslt.org/dates-and-times" xmlns:rng="http://relaxng.org/ns/structure/1.0" xmlns:fotex="http://www.tug.org/fotex" xmlns:fo="http://www.w3.org/1999/XSL/Format" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:a="http://relaxng.org/ns/compatibility/annotations/1.0" xmlns:m="http://www.w3.org/1998/Math/MathML" xmlns:html="http://www.w3.org/1999/xhtml" extension-element-prefixes="exsl estr edate" exclude-result-prefixes="exsl edate a fo rng tei teix fotex m html" version="1.0">
    <xsl:output indent="yes" encoding="utf-8"/>
    <xsl:template match="XSL:stylesheet">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:copy-of select="XSL:*"/>
        </xsl:copy>
    </xsl:template>
</xsl:stylesheet>