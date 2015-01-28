<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:mets="http://www.loc.gov/METS/" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl" exclude-result-prefixes="#all" version="2.0">
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>
                <xd:b>Created on:</xd:b> Mar 17, 2014</xd:p>
            <xd:p>
                <xd:b>Author:</xd:b> Daniel Schopper</xd:p>
            <xd:p/>
        </xd:desc>
    </xd:doc>
    <xsl:param name="project-md-handle"/>
    <xsl:template match="/mets:mets">
        <xsl:variable name="project-pid" select="@OBJID" as="xs:string"/>
        <cmd:CMD xmlns:dcr="http://www.isocat.org/ns/dcr" xmlns:cmd="http://www.clarin.eu/cmd/" xmlns:ann="http://www.clarin.eu" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" CMDVersion="1.1" xsi:schemaLocation="http://www.clarin.eu/cmd/ http://catalog.clarin.eu/ds/ComponentRegistry/rest/registry/profiles/clarin.eu:cr1:p_1345561703620/xsd">
            <cmd:Header>
                <cmd:MdCreator>
                    <xsl:value-of select="mets:metsHdr/mets:agent[@ROLE = 'CREATOR' and @ROLE != 'OTHER' ][1]/mets:name"/>
                </cmd:MdCreator>
                <cmd:MdCreationDate>
                    <xsl:value-of select="format-date(current-date(),'[Y]-[M00]-[D00]')"/>
                </cmd:MdCreationDate>
                <cmd:MdSelfLink>http://hdl.handle.net/11022/0000-0000-001B-2</cmd:MdSelfLink>
                <cmd:MdProfile>clarin.eu:cr1:p_1345561703620</cmd:MdProfile>
                <cmd:MdCollectionDisplayName>ICLTT Content Repository</cmd:MdCollectionDisplayName>
            </cmd:Header>
            <cmd:Resources>
                <cmd:ResourceProxyList>
                    <cmd:ResourceProxy id="dict-gate">
                        <cmd:ResourceType mimetype="application/xml">LandingPage</cmd:ResourceType>
                        <cmd:ResourceRef>http://clarin.aac.ac.at/cr/<xsl:value-of select="$project-pid"/>/</cmd:ResourceRef>
                    </cmd:ResourceProxy>
                    <xsl:for-each select="//mets:div[@TYPE='resource']">
                        <cmd:ResourceProxy id="at.icltt.cr.{$project-pid}.{@ID}.cmd">
                            <cmd:ResourceType mimetype="application/xml">Metadata</cmd:ResourceType>
                            <cmd:ResourceRef>http://hdl.handle.net/11022/0000-0000-001E-F</cmd:ResourceRef>
                        </cmd:ResourceProxy>
                    </xsl:for-each>
                    <cmd:ResourceProxy id="at.icltt.cr.dict-gate.2.cmd">
                        <cmd:ResourceType mimetype="application/xml">Metadata</cmd:ResourceType>
                        <cmd:ResourceRef>http://hdl.handle.net/11022/0000-0000-0028-3</cmd:ResourceRef>
                    </cmd:ResourceProxy>
                    <cmd:ResourceProxy id="at.icltt.cr.dict-gate.3.cmd">
                        <cmd:ResourceType mimetype="application/xml">Metadata</cmd:ResourceType>
                        <cmd:ResourceRef>http://hdl.handle.net/11022/0000-0000-001C-1</cmd:ResourceRef>
                    </cmd:ResourceProxy>
                </cmd:ResourceProxyList>
                <cmd:JournalFileProxyList/>
                <cmd:ResourceRelationList/>
            </cmd:Resources>
            <cmd:Components>
                <cmd:collection>
                    <cmd:CollectionInfo ComponentId="clarin.eu:cr1:c_1345561703619">
                        <cmd:Name xml:lang="en-GB">dict-gate</cmd:Name>
                        <cmd:Title xml:lang="en-GB">Dictionary Gate</cmd:Title>
                        <cmd:Owner xml:lang="en-GB">ICLTT</cmd:Owner>
                        <cmd:ISO639 ComponentId="clarin.eu:cr1:c_1271859438110">
                            <cmd:iso-639-3-code>arz</cmd:iso-639-3-code>
                        </cmd:ISO639>
                        <cmd:ISO639 ComponentId="clarin.eu:cr1:c_1271859438110">
                            <cmd:iso-639-3-code>deu</cmd:iso-639-3-code>
                        </cmd:ISO639>
                        <cmd:Modality ComponentId="clarin.eu:cr1:c_1271859438127">
                            <cmd:Modality>Spoken</cmd:Modality>
                            <cmd:Description ComponentId="clarin.eu:cr1:c_1271859438118">
                                <cmd:Description LanguageID="arz" xml:lang="en-US">various arabic dialects</cmd:Description>
                            </cmd:Description>
                        </cmd:Modality>
                        <cmd:TimeCoverage>
                            <cmd:StartYear>2011</cmd:StartYear>
                            <cmd:EndYear>2013</cmd:EndYear>
                        </cmd:TimeCoverage>
                        <cmd:Description>
                            <cmd:Description xml:lang="en-GB">
                                Dictionary Gate is a growing collection of lexical resources
                            </cmd:Description>
                        </cmd:Description>
                    </cmd:CollectionInfo>
                    <cmd:License ComponentId="clarin.eu:cr1:c_1345561703649">
                        <cmd:DistributionType>public</cmd:DistributionType>
                        <cmd:LicenseName>CC-by-nc-sa</cmd:LicenseName>
                        <cmd:LicenseURL>http://creativecommons.org/licenses/by-nc-sa/3.0/</cmd:LicenseURL>
                        <cmd:NonCommercialUsageOnly>true</cmd:NonCommercialUsageOnly>
                        <cmd:UsageReportRequired>true</cmd:UsageReportRequired>
                        <cmd:ModificationsRequireRedeposition>false</cmd:ModificationsRequireRedeposition>
                    </cmd:License>
                    <cmd:Contact ComponentId="clarin.eu:cr1:c_1271859438113">
                        <cmd:Person>Charly Moerth</cmd:Person>
                        <cmd:Address>Sonnenfelsgasse 19, 1010 Wien</cmd:Address>
                        <cmd:Email>icltt@oeaw.ac.at</cmd:Email>
                        <cmd:Organisation>Insitute for CorpusLinguistics and TextTechnology</cmd:Organisation>
                        <cmd:Organisation>Austrian Academy of Sciences</cmd:Organisation>
                        <cmd:Website>http://oeaw.ac.at/icltt</cmd:Website>
                    </cmd:Contact>
                    <cmd:WebReference ComponentId="clarin.eu:cr1:c_1316422391221">
                        <cmd:Website>http://clarin.aac.ac.at/cr/dict-gate</cmd:Website>
                        <cmd:Description xml:lang="en-US">
                            a simple search interface to the dictionaries in the dict-gate
                        </cmd:Description>
                    </cmd:WebReference>
                </cmd:collection>
            </cmd:Components>
        </cmd:CMD>
    </xsl:template>
</xsl:stylesheet>