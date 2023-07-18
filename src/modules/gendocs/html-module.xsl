<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="http://www.w3.org/1999/xhtml"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:fn="http://www.w3.org/2005/02/xpath-functions" xmlns:doc="http://www.xqdoc.org/1.0"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" exclude-result-prefixes="xs doc fn" version="2.0">
    <xsl:output method="html" indent="yes" encoding="UTF-8"/>
    <xsl:strip-space elements="*"/>
    <xsl:param name="source" as="xs:string"/>

    <!-- generate module html //-->
    <xsl:template match="//doc:xqdoc">
        <html>
            <head>
                <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
                <meta http-equiv="Generator"
                    content="xquerydoc - https://github.com/xquery/xquerydoc"/>
                <title>xqDoc - </title>
                <style type="text/css">
                    body {
                        font-family: Helvetica;
                        padding: 0.5em 1em;
                    }
                    pre {
                        font-family: Inconsolata, Consolas, monospace;
                    }
                    ol.results {
                        padding-left: 0;
                    }
                    .footer {
                        text-align: right;
                        border-top: solid 4px;
                        padding: 0.25em 0.5em;
                        font-size: 85%;
                        color: #999;
                    }
                    li.result {
                        list-style-position: inside;
                        list-style: none;
                        height: 140px;
                    }
                    h2 {
                        display: inline-block;
                        margin: 0;
                    }
                    
                    h2 a,
                    .result h3 a {
                        text-decoration: inherit;
                        color: inherit;
                    }
                    h3 {
                        font-size: 140%;
                        background-color: #aaa;
                        border-bottom: 1px solid #000;
                        width: 100%;
                    }
                    h4 {
                        font-size: 100%;
                        background-color: #ddd;
                        width: 90%;
                    }
                    
                    .namespace {
                        color: #999;
                    }
                    .namespace:before {
                        content: "{";
                    }
                    .namespace:after {
                        content: "}";
                    }
                    table {
                        width: 75%;
                        float: right;
                    }
                    td {
                        height: 100px;
                        width: 50%;
                        vertical-align: text-top;
                    }</style>
                <script src="lib/prettify.js" type="text/javascript">
&amp;#160;</script>
                <script src="lib/lang-xq.js" type="text/javascript">
&amp;#160;</script>
                <link rel="stylesheet" type="text/css" href="lib/prettify.css"/>
            </head>
            <body class="home">
                <div id="main">
                    <xsl:apply-templates/>
                    <!--
          <div>
          <h3>Original Source Code</h3>
          <pre class="prettyprint lang-xq"><xsl:value-of select="$source"/></pre>
          </div>
          <br/>
-->
                    <div class="footer">
                        <p style="text-align:right">
                            <i>
                                <xsl:value-of select="()"/>
                            </i> | generated by xquerydoc <a
                                href="https://github.com/xquery/xquerydoc" target="xquerydoc"
                                >https://github.com/xquery/xquerydoc</a>
                        </p>
                    </div>
                </div>
                <script type="application/javascript">
                    window.onload = function () {
                        prettyPrint();
                    }</script>
            </body>
        </html>
    </xsl:template>
    <xsl:template match="doc:module">
        <h1>
            <xsl:value-of select="doc:name"/>
        </h1>
        <h2>
            <span class="namespace">
                <xsl:value-of select="doc:uri"/>
            </span> &#160;<xsl:value-of select="@type"/> module </h2>
        <xsl:apply-templates select="*[not(local-name(.) = ('name', 'uri'))]"/>
    </xsl:template>
    <xsl:template match="doc:variables">
        <div id="variables">
            <h3>Variables</h3>
            <xsl:apply-templates/>
        </div>
    </xsl:template>
    <xsl:template match="doc:variable[@private]"/>
    <xsl:template match="doc:variable">
        <div id="{ concat('var_', replace(doc:uri, ':', '_')) }">
            <h4>
                <pre class="prettyprint lang-xq">
                    <u>Variable</u>:&#160;$<xsl:value-of select="doc:uri"/> as <xsl:value-of select="doc:type"/>
                    <xsl:value-of select="doc:type/@occurrence"/>
                </pre>
            </h4>
            <xsl:apply-templates select="doc:comment"/>
        </div>
    </xsl:template>
    <xsl:template match="doc:uri">
        <xsl:value-of select="."/>
    </xsl:template>
    <xsl:template match="doc:functions">
        <div id="functions">
            <h3>Functions</h3>
            <xsl:apply-templates/>
        </div>
    </xsl:template>
    <xsl:template match="doc:function[@private]"/>
    <xsl:template match="doc:function">
        <div id="{ concat('func_', replace(doc:name, ':', '_'), '_', @arity) }">
            <h4>
                <u>Function</u>:&#160;<xsl:value-of select="doc:name"/>
            </h4>
            <pre class="prettyprint lang-xq">
                <xsl:value-of select="doc:signature"/>
            </pre>
            <xsl:apply-templates select="* except (doc:name | doc:signature)"/>
            <xsl:apply-templates select="doc:comment/doc:error"/>
        </div>
    </xsl:template>
    <xsl:template match="doc:parameters">
        <h5>Params</h5>
        <ul>
            <xsl:apply-templates/>
        </ul>
    </xsl:template>
    <xsl:template match="doc:parameter">
        <li>
            <xsl:value-of select="doc:name"/> as <xsl:value-of select="doc:type"/>
            <xsl:value-of select="doc:type/@occurrence"/>
            <xsl:variable name="name" select="string(doc:name)"/>
            <xsl:for-each
                select="../../doc:comment/doc:param[starts-with(normalize-space(.), $name) or starts-with(normalize-space(.), concat('$', $name))]">
                <xsl:value-of select="substring-after(normalize-space(.), $name)"/>
            </xsl:for-each>
        </li>
    </xsl:template>
    <xsl:template match="doc:return">
        <h5>Returns</h5>
        <ul>
            <li>
                <xsl:value-of select="doc:type"/>
                <xsl:value-of select="doc:type/@occurrence"/>
                <xsl:for-each select="../doc:comment/doc:return">
                    <xsl:text>: </xsl:text>
                    <xsl:value-of select="normalize-space(.)"/>
                </xsl:for-each>
            </li>
        </ul>
    </xsl:template>
    <xsl:template match="doc:error" mode="custom"/>
    <xsl:template match="doc:error">
        <h5>Errors</h5>
        <p>
            <xsl:apply-templates mode="custom"/>
        </p>
    </xsl:template>
    <xsl:template match="doc:comment">
        <xsl:apply-templates mode="custom"/>
    </xsl:template>
    <xsl:template match="doc:description" mode="custom">
        <p>
            <xsl:apply-templates mode="custom"/>
        </p>
    </xsl:template>
    <xsl:template match="*:h1" mode="custom">
        <h1>
            <xsl:apply-templates mode="custom"/>
        </h1>
    </xsl:template>
    <xsl:template match="*:ul" mode="custom">
        <ul>
            <xsl:apply-templates mode="custom"/>
        </ul>
    </xsl:template>
    <xsl:template match="*:li" mode="custom">
        <li>
            <xsl:apply-templates mode="custom"/>
        </li>
    </xsl:template>
    <xsl:template match="*:p" mode="custom">
        <p>
            <xsl:apply-templates mode="custom"/>
        </p>
    </xsl:template>
    <xsl:template match="*:pre" mode="custom">
        <pre class="prettyprint lang-xq">
            <xsl:value-of select="."/>
        </pre>
    </xsl:template>
    <xsl:template match="doc:author" mode="custom #default">
        <p>Author: <xsl:value-of select="."/>
        </p>
    </xsl:template>
    <xsl:template match="doc:version" mode="custom #default">
        <p>Version: <xsl:value-of select="."/>
        </p>
    </xsl:template>
    <xsl:template match="doc:see" mode="custom"> See also: <xsl:for-each
            select="tokenize(., '[ \t\r\n,]+')[. ne '']">
            <xsl:if test="position() ne 1">
                <xsl:text>, </xsl:text>
            </xsl:if>
            <xsl:choose>
                <xsl:when test="contains(., '#')">
                    <a
                        href="#{ concat('func_', replace(substring-before(.,'#'), ':', '_'),             '_', substring-after(.,'#')) }">
                        <xsl:value-of select="."/>
                    </a>
                </xsl:when>
                <xsl:when test="starts-with(., '$')">
                    <a href="#{ concat('var_', replace(substring-after(.,'$'), ':', '_')) }">
                        <xsl:value-of select="."/>
                    </a>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="."/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    </xsl:template>
    <xsl:template match="doc:param" mode="custom"/>
    <xsl:template match="doc:return" mode="custom"/>

    <!--xsl:template match="doc:custom" mode="custom">
    <xsl:apply-templates select="."/>
  </xsl:template>

  <xsl:template match="doc:param" mode="custom">
    <xsl:apply-templates select="."/>
  </xsl:template>


  <xsl:template match="doc:version" mode="custom">
    <xsl:apply-templates select="."/>
  </xsl:template-->
    <xsl:template match="doc:control"/>
    <xsl:template match="text()" mode="custom #default">
        <xsl:value-of select="normalize-space(.)"/>
    </xsl:template>
</xsl:stylesheet>
