<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" xmlns:project="http://aac.ac.at/content_repository/project" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl" exclude-result-prefixes="xs xd" version="2.0">
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>
                <xd:b>Created on:</xd:b> Nov 25, 2013</xd:p>
            <xd:p>
                <xd:b>Author:</xd:b> Daniel</xd:p>
            <xd:p/>
        </xd:desc>
    </xd:doc>
    <xsl:param name="targetNamespace" select="namespace-uri(/*)"/>
    <xsl:template match="/*">
        <wsdl:definitions xmlns:mime="http://schemas.xmlsoap.org/wsdl/mime/" xmlns:http="http://schemas.xmlsoap.org/wsdl/http/" xmlns:ws="http://www.example.com/webservice" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/" xmlns:wsoap12="http://schemas.xmlsoap.org/wsdl/soap12/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" targetNamespace="{$targetNamespace}">
            <wsdl:portType name="{local-name(.)}">
                <xsl:for-each select="*">
                    <xsl:apply-templates/>
                </xsl:for-each>
            </wsdl:portType>
        </wsdl:definitions>
    </xsl:template>
    <xsl:template match="*[local-name() = 'properties' or local-name() = 'methods']">
        <xsl:apply-templates/>
    </xsl:template>
    <xsl:template match="*[local-name(.) eq 'property']"/>
    <xsl:template match="*[local-name(.) eq 'method']">
        <wsdl:operation name="{@name}">
            <wsdl:input message=""/>
        </wsdl:operation>
    </xsl:template>
</xsl:stylesheet>