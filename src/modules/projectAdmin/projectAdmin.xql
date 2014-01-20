xquery version "3.0";

import module namespace projectAdmin="http://aac.ac.at/content_repository/projectAdmin" at "projectAdmin.xqm";
import module namespace project="http://aac.ac.at/content_repository/project" at "../../core/project.xqm";

declare option exist:serialize "method=xhtml media-type=text/html indent=yes";

let $html-menu := doc("adminMenu.html")

let $project-pid := request:get-parameter("project","")
let $path := request:get-parameter("path",""),
    $path-steps := tokenize($path,'/'),
    $form-data := projectAdmin:form($path-steps[3]),
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
    

    
    
let $user := xmldb:get-current-user()

(: this variable can be passed to projectAdmin:bind and projectAdmin:form and will be used to
replace attribute value templates in curly brackets, like {$project-pid} :)
let $vars := map {
                "user" := $user,
                "project-pid" := $project-pid,
                "lang" := $lang,
                "section" := $section
            }
let $html:=

<html xmlns="http://www.w3.org/1999/xhtml" 
    xmlns:mods="http://www.loc.gov/mods/v3"
    xmlns:mets="http://www.loc.gov/METS/"
    xmlns:xf="http://www.w3.org/2002/xforms"
    xmlns:xhtml="http://www.w3.org/1999/xhtml"
    xmlns:ev="http://www.w3.org/2001/xml-events">
    <head>
    <script type="text/javascript" src="../../shared-resources/resources/scripts/jquery/jquery-1.7.1.min.js"></script>
    <link rel="stylesheet" type="text/javascript" href="../../shared-resources/resources/css/bootstrap.min.css"/>
        <script type="text/javascript" src="../../shared-resources/resources/scripts/bootstrap.min.js"></script>
        <style type="text/css"><![CDATA[
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
        ]]></style>
        <script type="text/javascript"><![CDATA[
            $(document).ready(
                function(){
                    $(']]>{"#li-"||$form}<![CDATA[').addClass('active');
                    // $(']]>{$form}<![CDATA[').addClass('active');
                }
            );
        ]]></script>
    	<xf:model id="model">
    	   <!-- some basic data which resides on the mets:mets element -->
            <xf:instance id="instance-project-id">
                <mets:mets OBJID="{$project-pid}"/>
            </xf:instance>
            <xf:bind id="project-id" ref="instance('instance-project-id')/@OBJID" readonly="true"/>
            
            <xf:instance id="instance-project-label" resource="/exist/restxq/cr_xq/{$project-pid}/label"/>
            <xf:bind id="project-label" ref="instance('instance-project-label')" readonly="false"/>
            
            <!-- main form data + submission -->
            {(projectAdmin:labels($form,$lang),
              projectAdmin:data($project-pid, $form),
              projectAdmin:help($form,$lang),   
              projectAdmin:bind($project-pid,$form,$vars))}
	        <xf:submission replace="instance" resource="store.xql" id="save" method="post" ref="instance('{$form}')">
	           <xf:header>
		        	<xf:name>project-pid</xf:name>
		        	<xf:value>{$project-pid}</xf:value>
	        	</xf:header>
	        	<xf:header>
		        	<xf:name>form</xf:name>
		        	<xf:value>{$form}</xf:value>
	        	</xf:header>
		        <xf:header>
		        	<xf:name>user-id</xf:name>
		        	<xf:value>{ xmldb:get-current-user() }</xf:value>
	        	</xf:header>
	        	<xf:message level="ephemeral" ev:event="xforms-submit-error">Submission failed</xf:message>
	    		<xf:message level="ephemeral" ev:event="xforms-submit-done">Submission successful</xf:message>
	        </xf:submission>
	        
	        <!-- HELP pane -->
	        <xf:instance id="help-output" xmlns="">
                 <div xmlns="http://www.w3.org/1999/xhtml"/>
             </xf:instance>
             {if ($section!='')
             then 
                <xf:action xmlns:ev="http://www.w3.org/2001/xml-events" ev:event="xforms-ready">
                   <xf:setvalue ref="instance('help-output')" value="instance('help')//xhtml:div[@id='help-{$form}-{$section}']"/>
               </xf:action>
             else ()}
            
            <!-- basic GUI element labels -->
            <xf:bind id="form-title" ref="instance('labels')//label[@key='form-title']"/>
            <xf:bind id="label-form-save" ref="instance('labels')//label[@key='form-save']"/>
            <xf:bind id="label-form-reset" ref="instance('labels')//label[@key='form-reset']"/>
        </xf:model>
        <title>cr-Project Administration: {$project-pid} (<xf:output bind="form-title"/>)</title>
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
                    <!-- menu -->
                    {$html-menu}    
                </div>
                <div class="span7">
                    <!-- main form -->
                    <h1>
                        <xf:output bind="form-title"/>
                    </h1>
                    {$form-data}
                </div>
                
                <!-- help -->
                <div class="span3">
                    <div class="well" id="help-pane">
                        <h5>Help</h5>
                        <xf:output ref="instance('help-output')"/>
                    </div>
                </div>
            </div>
        </div>
    </body>
</html>

return
$html