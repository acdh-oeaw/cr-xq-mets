xquery version "3.0";

import module namespace projectAdmin="http://aac.ac.at/content_repository/projectAdmin" at "projectAdmin.xqm";
import module namespace project="http://aac.ac.at/content_repository/project" at "../../core/project.xqm";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "xhtml";
declare option output:media-type "text/html";
declare option output:indent "no";

let $html-menu := doc("adminMenu.html")

let $project-pid := request:get-parameter("project","")
let $path :=        request:get-parameter("path",""),
    $path-steps :=  tokenize($path,'/'),
    $form-data :=   projectAdmin:form($path-steps[3]),
    $form :=  
        if (exists($form-data))
        then $path-steps[3]
        else "dmd",
    $form-data := 
    	if (not(exists($form-data)))
    	then projectAdmin:form($form)
    	else $form-data
    
let $lang:= request:get-parameter("lang","en"),
    $section := $path-steps[4]
    
return
    
<html xmlns="http://www.w3.org/1999/xhtml" 
    xmlns:mods="http://www.loc.gov/mods/v3"
    xmlns:mets="http://www.loc.gov/METS/"
    xmlns:xf="http://www.w3.org/2002/xforms"
    xmlns:xhtml="http://www.w3.org/1999/xhtml"
    xmlns:ev="http://www.w3.org/2001/xml-events">
    <head>
        <script type="text/javascript" src="../../shared-resources/resources/scripts/jquery/jquery-1.7.1.min.js"></script>
        <link rel="stylesheet" href="../../shared-resources/resources/css/bootstrap.min.css"/>
        <script type="text/javascript" src="../../shared-resources/resources/scripts/bootstrap.min.js"></script>
        <style type="text/css"><![CDATA[
        /*
            body {
                background: none;
            }
            
            .xfRepeatIndex {
                background-color: #DBDBDB;
            }
            
            #help-pane {
                background-color: #D6D6D6;
                border: 1px solid #B3B3B3;
                margin-top: 30px;
            }
            
            #help-pane h5 {
                margin: 0;
            }
            
            thead {
                background: gray;
                color: white;
                border-color: white;
            }
            
            th {
                font-weight: normal;
                text-align: left;
                border-color: white;
                padding: 2px 4px;
            }
            
            td {
                border-color: gray;
            }

            /*table, th, tr, td {
                border-style: dotted;
                border-width: 1px;
                border-collapse: collapse;
            }
            
            table div {
                margin: 0!important;
            } */
            
            .xfFullGroup label {
                vertical-align: top;
            }
            
            .bf .bfVerticalTable .bfVerticalTableLabel .xfLabel {
                padding-top: 0;
            }
            
            .bfVerticalTableLabel {
                padding-right: 15px;
            }
        */
        ]]></style>
        <xf:model>
            <xf:submission id="store" resource="exist:{base-uri(project:get($project-pid))}" method="post" replace="instance" ref="instance('mets')"/>
            
            <xf:instance id="mods.personTemplate">
                <mods:name>
                    <mods:namePart type="family"/>
                    <mods:namePart type="given"/>
                    <mods:role>
                        <mods:roleTerm type="text"/>
                    </mods:role>
                </mods:name>
            </xf:instance>
            
            <xf:instance id="mods.languageTemplate">
                <mods:language>
                    <mods:languageTerm type="text"/>
                </mods:language>
            </xf:instance>
            
            <xf:instance id="languages" xmlns="" src="exist:/db/apps/cr-xq-dev0913/modules/projectAdmin/languages.xml">
            </xf:instance>
            
            <xf:instance id="selectedLanguage" xmlns="">
                <data></data>
            </xf:instance>
            <xf:instance src="exist:{base-uri(project:get($project-pid))}" id="mets"/>
            
            <xf:bind id="project.pid" ref="@OBJID"/>
            <xf:bind id="project.label" ref="@LABEL"/>
            <xf:bind id="project.status" ref="mets:metsHdr/@RECORDSTATUS"/>
            <xf:bind id="project.createdate" ref="mets:metsHdr/@CREATEDATE"/>
            <xf:bind id="project.dmd" ref="mets:dmdSec[@ID='projectDMD']/mets:mdWrap[@MDTYPE='MODS']/mets:xmlData/mods:mods">
                <xf:bind ref="mods:language/mods:languageTerm" type="xsd:string" relevant="false()"/>
            </xf:bind>
        </xf:model>
    </head>
    <body>
        <h1>Project Admin "{$project-pid}"</h1>
        <xf:switch ref="instance('mets')">
            <xf:case id="start">
                <xf:group appearance="bf:verticalTable">
                    <xf:output bind="project.pid">
                        <xf:label>Project PID</xf:label>
                    </xf:output>
                    <xf:output bind="project.createdate">
                        <xf:label>Created: </xf:label>
                    </xf:output>
                    
                    <xf:input bind="project.label">
                        <xf:label>Project Label</xf:label>
                    </xf:input>
                    <xf:select1 bind="project.status">
                        <xf:label>Project Status</xf:label>
                        <xf:item>
                            <xf:label>available</xf:label>
                            <xf:value>available</xf:value>
                        </xf:item>
                        <xf:item>
                            <xf:label>under revision</xf:label>
                            <xf:value>under revision</xf:value>
                        </xf:item>
                        <xf:item>
                            <xf:label>restricted</xf:label>
                            <xf:value>restricted</xf:value>
                        </xf:item>
                        <xf:item>
                            <xf:label>removed</xf:label>
                            <xf:value>removed</xf:value>
                        </xf:item>
                    </xf:select1>
                    <xf:group bind="project.dmd" appearance="bf:verticalTable">
                        <xf:input ref="mods:titleInfo/mods:title">
                            <xf:label>Title</xf:label>
                        </xf:input>
                        
                        <table>
                            <thead>
                                <tr>
                                    <th>Family Name</th>
                                    <th>Given Name</th>
                                    <th>Role</th>
                                    <th/>
                                </tr>
                            </thead>
                            <tbody xf:repeat-nodeset="mods:name" id="modsNames-repeat">
                                <tr>
                                    <td><xf:input ref="mods:namePart[@type='family']"/></td>
                                    <td><xf:input ref="mods:namePart[@type='given']"/></td>
                                    <td><xf:input ref="mods:role/mods:roleTerm[@type='text']"/></td>
                                    <td>
                                    </td>
                                </tr>
                            </tbody>
                        </table>
                        <xf:trigger>
                            <xf:label>Remove Person</xf:label>
                            <xf:action>
                                <xf:delete ref="mods:name" at="index('modsNames-repeat')"/>
                            </xf:action>
                        </xf:trigger>
                        <xf:trigger>
                            <xf:label>Add Person</xf:label>
                            <xf:action>
                                <xf:insert context="." nodeset="*" origin="instance('mods.personTemplate')">
                                </xf:insert>
                            </xf:action>
                        </xf:trigger>
                        
                        <xf:select1 ref="mods:typeOfResource" required="true" selection="closed">
                            <xf:label>Type of Resource</xf:label>
                            <xf:alert>Type of Resource must not be empty.</xf:alert>
                            <xf:item>
                                <xf:value>text</xf:value>
                                <xf:label>text</xf:label>
                            </xf:item>
                            <xf:item>
                                <xf:value>cartographic</xf:value>
                                <xf:label>cartographic</xf:label>
                            </xf:item>
                            <xf:item>
                                <xf:value>notated music</xf:value>
                                <xf:label>notated music</xf:label>
                            </xf:item>
                            <xf:item>
                                <xf:value>sound recording</xf:value>
                                <xf:label>sound recording</xf:label>
                            </xf:item>
                            <xf:item>
                                <xf:value>sound recording-musical</xf:value>
                                <xf:label>sound recording-musical</xf:label>
                            </xf:item>
                            <xf:item>
                                <xf:value>sound recording-nonmusical</xf:value>
                                <xf:label>sound recording-nonmusical</xf:label>
                            </xf:item>
                            <xf:item>
                                <xf:value>still image</xf:value>
                                <xf:label>still image</xf:label>
                            </xf:item>
                            <xf:item>
                                <xf:value>moving image</xf:value>
                                <xf:label>moving image</xf:label>
                            </xf:item>
                            <xf:item>
                                <xf:value>three dimensional object</xf:value>
                                <xf:label>three dimensional object</xf:label>
                            </xf:item>
                            <xf:item>
                                <xf:value>software, multimedia</xf:value>
                                <xf:label>software, multimedia</xf:label>
                            </xf:item>
                            <xf:item>
                                <xf:value>mixed material</xf:value>
                                <xf:label>mixed material</xf:label>
                            </xf:item>
                        </xf:select1>
                        
                        <xf:output value="string-join(mods:language/mods:languageTerm,', ')">
                            <xf:label>Language(s): </xf:label>
                        </xf:output>
                        
                        
                        
                        <xf:select1 ref="instance('selectedLanguage')" selection="closed" appearance="compact">
                            <xf:label>Language</xf:label>
                            <xf:itemset nodeset="instance('languages')/language">
                                <xf:value ref="@code"/>
                                <xf:label ref="@label"/>
                            </xf:itemset>
                            <xf:action ev:event="xforms-select">
                                <xf:insert context="instance('mets')//mods:mods" nodeset="*" origin="instance('mods.languageTemplate')"/>
                                <xf:setvalue ref="instance('mets')//mods:mods/mods:language/mods:languageTerm[.='']" value="instance('selectedLanguage')"/>
                            </xf:action>
                        </xf:select1>
                        
                        <xf:trigger>
                            <xf:label>Remove Language</xf:label>
                            <xf:action>
                                <xf:delete ref="mods:language[mods:languageTerm = instance('selectedLanguage')]"/>
                            </xf:action>
                        </xf:trigger>
                        <xf:trigger>
                            <xf:label>Add Language</xf:label>
                            <xf:action>
                                <xf:insert context="." nodeset="*" origin="instance('mods.languageTemplate')"/>
                                <xf:setvalue ref="mods:language/mods:languageTerm[.='']" value="instance('selectedLanguage')"/>
                            </xf:action>
                        </xf:trigger>
                        
                        
                        
                        
                        <xf:textarea ref="mods:abstract">
                            <xf:label>Abstract</xf:label>
                        </xf:textarea>
                    </xf:group>
                </xf:group>
            </xf:case>
            <xf:case id="empty"/>
        </xf:switch>
        <xf:trigger>
            <xf:label>save</xf:label>
            <xf:action>
                <xf:send submission="store"/>
                <xf:message ev:event="xforms-submit-done" level="ephemeral">Project saved.</xf:message>
                <xf:message ev:event="xforms-submit-error" level="ephemeral">An error occurred.</xf:message>
            </xf:action>
        </xf:trigger>
    </body>
</html>

