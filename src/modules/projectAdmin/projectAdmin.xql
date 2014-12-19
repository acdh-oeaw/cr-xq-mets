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
    xmlns:cmd="http://www.clarin.eu/cmd/"
    xmlns:xlink="http://www.w3.org/1999/xlink"
    xmlns:ev="http://www.w3.org/2001/xml-events">
    <head>
        <script type="text/javascript" src="../../shared-resources/resources/scripts/jquery/jquery-1.7.1.min.js"></script>
        <link rel="stylesheet" href="../../shared-resources/resources/css/bootstrap.min.css"/>
        <script type="text/javascript" src="../../shared-resources/resources/scripts/bootstrap.min.js"></script>
        <style type="text/css"><![CDATA[
        
            body {
                background: none !important;
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
        
        ]]></style>
        <xf:model id="model1">
            
            <!-- METS record / project.xml -->
            <xf:submission id="store" resource="exist:{base-uri(project:get($project-pid))}" method="put" replace="instance" ref="instance('mets')">
            	<xf:message ev:event="xforms-submit-done" level="ephemeral">Project saved.</xf:message>
                <xf:message ev:event="xforms-submit-error" level="ephemeral">An error occurred saving exist:{base-uri(project:get($project-pid))}</xf:message>
            </xf:submission>
            
            <xf:instance src="exist:{base-uri(project:get($project-pid))}" id="mets"/>
            
            <xf:bind id="project.pid" ref="@OBJID"/>
            <xf:bind id="project.label" ref="@LABEL"/>
            <xf:bind id="project.status" ref="mets:metsHdr/@RECORDSTATUS"/>
            <xf:bind id="project.createdate" ref="mets:metsHdr/@CREATEDATE"/>
            
            
            
             <!-- project CMDI --> 
            <xf:instance id="project.cmdi" xmlns="">
            	<data></data>
            </xf:instance>
            
            <xf:submission id="loadProjectCMDI" method="get" replace="instance" ref="instance('project.cmdi')">
            	<xf:resource value="concat('exist:',instance('mets')/mets:dmdSec[@ID='projectDMD']/mets:mdRef/@xlink:href)"/>
                <xf:message ev:event="xforms-submit-error" level="ephemeral">could not load cmdi record from <xf:output ref="instance('mets')/mets:dmdSec[@ID='projectDMD']/mets:mdRef/@xlink:href"/></xf:message>
            </xf:submission>
            
            <xf:submission id="storeProjectCMDI" method="put" replace="instance" ref="instance('project.cmdi')">
            	<xf:resource value="concat('exist:',instance('mets')/mets:dmdSec[@ID='projectDMD']/mets:mdRef/@xlink:href)"/>
                <xf:message ev:event="xforms-submit-error" level="ephemeral">could not store cmdi record at <xf:output ref="instance('mets')/mets:dmdSec[@ID='projectDMD']/mets:mdRef/@xlink:href"/></xf:message>
                <xf:message ev:event="xforms-submit-done" level="ephemeral">stored cmdi record</xf:message>
            </xf:submission>
            
            
            
            
            <!-- instance that stores various states of the user interface -->
            <xf:instance id="state" xmlns="">
                <state xmlns="">
                    <currentResource/>
                </state>
            </xf:instance>
            
            
            
            <xf:instance id="mods.personTemplate">
                <mods:name>
                    <mods:namePart type="family"/>
                    <mods:namePart type="given"/>
                    <mods:role>
                        <mods:roleTerm type="text"/>
                    </mods:role>
                </mods:name>
            </xf:instance>
            
            <xf:instance id="mods.languageTemplate"><mods:language>
                    <mods:languageTerm type="text"/>
                </mods:language>
            </xf:instance>
            
            <xf:instance id="languages" xmlns="" src="exist:/db/apps/cr-xq-mets/modules/projectAdmin/languages.xml">
            </xf:instance>
            
            <xf:instance id="selectedLanguage" xmlns="">
                <data></data>
            </xf:instance>
            
           
            
            
            
            
            <xf:action ev:event="xforms-ready">
            	<xf:send submission="loadProjectCMDI"/>
            </xf:action>
            	
            
            
            <xf:bind id="project.dmd" ref="mets:dmdSec[@ID='projectDMD']/mets:mdWrap[@MDTYPE='MODS']/mets:xmlData/mods:mods">
                <!--<xf:bind ref="mods:language/mods:languageTerm" type="xsd:string" relevant="false()"/>-->
            </xf:bind>
            
        </xf:model>
    </head>
    <body>
        <div class="container-fluid">
            <!-- head -->
            <div class="row-fluid">
                <div class="span12">
                    <h3 class="pull-right">cr_xq Project Administration <small>{$project-pid}</small></h3>
                </div>
            </div>
            
            
            <div class="row-fluid">
                <div class="span2">
                     <xf:group appearance="bf:verticalTable">
                        <xf:trigger>
                            <xf:label>Start</xf:label>
                            <xf:toggle case="start" ev:event="DOMActivate"/>
                        </xf:trigger>
                        <xf:trigger>
                            <xf:label>Project Metadata</xf:label>
                            <xf:toggle case="cmdi" ev:event="DOMActivate"/>
                        </xf:trigger>
                        <xf:trigger>
                            <xf:label>Resources</xf:label>
                            <xf:toggle case="resources" ev:event="DOMActivate"/>
                        </xf:trigger>
                        <xf:trigger>
                            <xf:label>template</xf:label>
                            <xf:toggle case="empty" ev:event="DOMActivate"/>
                        </xf:trigger>
                     </xf:group>
                </div>
                
                <div class="span7">
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
                            <xf:trigger>
		                        <xf:label>Store</xf:label>
		                        <xf:action>
		                            <xf:send submission="store"/>
		                        </xf:action>
		                    </xf:trigger>
                        </xf:case>
                        <xf:case id="cmdi">
                        	<xf:group ref="instance('project.cmdi')">
                        		<xf:input ref="//cmd:Description">
                        			<xf:label>description</xf:label>
                        		</xf:input>
							</xf:group>
							<xf:trigger>
		                        <xf:label>Store</xf:label>
		                        <xf:action>
		                            <xf:send submission="storeProjectCMDI"/>
		                        </xf:action>
		                    </xf:trigger>
                        </xf:case>
                        <xf:case id="resources">
                            <h3>Resources</h3>
                            <xf:group ref="//mets:structMap[@TYPE='internal']/mets:div">
                                 <div class="row-fluid">
                                    <div class="span3">
                                        <xf:repeat nodeset="mets:div[@TYPE='resource']" ID="repeat-resources">
                                            <xf:output value="concat(@LABEL,' (',@ID,')')"/>
                                        </xf:repeat>
                                        <xf:group appearance="bf:horizontalTable"> 
                                            <xf:trigger>
                                                <xf:label>edit</xf:label>
                                                <xf:action>
                                                    <xf:message>
                                                        <xf:output value="index('repeat-resources')"/>
                                                    </xf:message>
                                                    <xf:setvalue ref="instance('state')/currentResource" value="context()/mets:div[@TYPE='resource'][position() = index('repeat-resources')]/@ID"/>
                                                </xf:action>
                                            </xf:trigger>
                                            <xf:trigger>
                                                <xf:label>purge</xf:label> 
                                            </xf:trigger>
                                            
                                        </xf:group>
                                        <xf:switch>
                                            <xf:case id="default">
                                                <xf:trigger>
                                                    <xf:label>add resources</xf:label>
                                                    <xf:toggle case="upload"/>
                                                </xf:trigger>
                                            </xf:case>
                                            <xf:case id="upload">
                                                <!--
                                                <div id="uploader">
                                                    <p>Your browser doesn't have Flash, Silverlight or HTML5 support.</p>
                                                </div>
                                                 
                                                <script type="text/javascript"><![CDATA[
                                                // Initialize the widget when the DOM is ready
                                                $(function() {
                                                    // Setup html5 version
                                                    $("#uploader").pluploadQueue({
                                                        // General settings
                                                        runtimes : 'html5,flash,silverlight,html4',
                                                        url : "/examples/upload",
                                                         
                                                        chunk_size : '1mb',
                                                        rename : true,
                                                        dragdrop: true,
                                                         
                                                        filters : {
                                                            // Maximum file size
                                                            max_file_size : '10mb',
                                                            // Specify what files to browse for
                                                            mime_types: [
                                                                {title : "Image files", extensions : "jpg,gif,png"},
                                                                {title : "Zip files", extensions : "zip"}
                                                            ]
                                                        },                                                 
                                                 
                                                        // Flash settings
                                                        flash_swf_url : '/plupload/js/Moxie.swf',
                                                     
                                                        // Silverlight settings
                                                        silverlight_xap_url : '/plupload/js/Moxie.xap'
                                                    });
                                                });
                                                ]]></script>
                                                -->
                                                <xf:trigger>
                                                    <xf:label>abort</xf:label>
                                                    <xf:toggle case="upload"/>
                                                </xf:trigger>
                                            </xf:case>
                                        </xf:switch>
                                    </div>
                                    <div class="span8">
                                        <xf:group ref="mets:div[@TYPE='resource'][@ID = instance('state')/currentResource]">
                                            <h4>Resource <i><xf:label value="@LABEL"/></i></h4>
                                            <p>contains <xf:output value="count(mets:div[@TYPE='resourcefragments'])"/> resource fragments</p>
                                        </xf:group>
                                   </div>
                               </div>
                            </xf:group>
                        </xf:case>
                        <xf:case id="empty">
                            
                        </xf:case>
                    </xf:switch>
                </div>
                
                <!-- help -->
                <div class="span3">
                    <div class="well" id="help-pane">
                        <h5>Help</h5>
                        <!--<xf:output ref="instance('help-output')"/>-->
                    </div>
                </div>
            </div>
        </div>
    </body>
</html>

