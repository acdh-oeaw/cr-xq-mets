xquery version "3.0";

module namespace xfedora = "http://aac.ac.at/content_repository/xfedora";
import module namespace resource = "http://aac.ac.at/content_repository/resource" at "../../core/resource.xqm";
import module namespace project = "http://aac.ac.at/content_repository/project" at "../../core/project.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "../../core/config.xqm";
import module namespace cmd="http://www.clarin.eu/cmd/" at "../cmd/cmdi.xqm";

declare namespace foxml = "info:fedora/fedora-system:def/foxml#";
declare namespace dc = "http://purl.org/dc/elements/1.1/";

declare function xfedora:project2foxml($project-pid as xs:string) as element(foxml:digitalObject) {
    xfedora:project2foxml(("CMDI"),$project-pid)
};

declare function xfedora:project2foxml($datastreams as xs:string*, $project-pid as xs:string) as element(foxml:digitalObject) {
    let $fedora-pid := replace(config:param-value(config:module-config(),"fedora-pid-namespace-prefix"),':$','')||":"||$project-pid,
        $fedora-get-url :=   replace(config:param-value(config:module-config(),"fedora-get-url"),'/$','')
    let $label := project:label($project-pid),
        $owner := project:adminsaccountname($project-pid),
        $MdSelfLink := project:get-handle("CMDI",$project-pid),
        $dc := project:dmd2dc($project-pid),
        $title := $dc//dc:title,
        $dmd := project:dmd($project-pid),
        $dmd-created := xmldb:created(util:collection-name($dmd),util:document-name($dmd))

    return
  (:  <foxml:digitalObject PID="{$fedora-pid}" VERSION="1.1" xmlns:foxml="info:fedora/fedora-system:def/foxml#"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="info:fedora/fedora-system:def/foxml# http://www.fedora.info/definitions/1/0/foxml1-1.xsd">:)
    <foxml:digitalObject PID="{$fedora-pid}" VERSION="1.1" xmlns:foxml="info:fedora/fedora-system:def/foxml#">
        <foxml:objectProperties>
          <foxml:property NAME="info:fedora/fedora-system:def/model#state" VALUE="Active"/>
          <foxml:property NAME="info:fedora/fedora-system:def/model#label" VALUE="{$label}"/>
          <foxml:property NAME="info:fedora/fedora-system:def/model#ownerId" VALUE="{$owner}"/>
          <foxml:property NAME="info:fedora/fedora-system:def/model#createdDate" VALUE="{fn:current-dateTime()}"/>
          <foxml:property NAME="info:fedora/fedora-system:def/view#lastModifiedDate" VALUE="{fn:current-dateTime()}"/>
        </foxml:objectProperties>
        <foxml:datastream CONTROL_GROUP="X" ID="AUDIT" STATE="A" VERSIONABLE="false">
          <foxml:datastreamVersion CREATED="{fn:current-dateTime()}"
            FORMAT_URI="info:fedora/fedora-system:format/xml.fedora.audit" ID="AUDIT.0" LABEL="Audit Trail for this object" MIMETYPE="text/xml">
            <foxml:xmlContent>
              <audit:auditTrail xmlns:audit="info:fedora/fedora-system:def/audit#"/>
            </foxml:xmlContent>
          </foxml:datastreamVersion>
        </foxml:datastream>
        <foxml:datastream CONTROL_GROUP="X" ID="DC" STATE="A" VERSIONABLE="true">
          <foxml:datastreamVersion CREATED="{fn:current-dateTime()}" FORMAT_URI="http://www.openarchives.org/OAI/2.0/oai_dc/"
            ID="DC1.0" LABEL="Dublin Core Record for this object" MIMETYPE="text/xml">
            <foxml:xmlContent>{$dc}</foxml:xmlContent>
          </foxml:datastreamVersion>
        </foxml:datastream>
        {if ($datastreams = "CMDI")
        then 
            (<foxml:datastream CONTROL_GROUP="X" ID="CMDI" STATE="A" VERSIONABLE="true">
              <foxml:datastreamVersion ALT_IDS="{$MdSelfLink}" CREATED="{$dmd-created}"
                ID="CMDI.0" LABEL="CMD record for {$label}" MIMETYPE="text/xml">
                <foxml:xmlContent>{$dmd}</foxml:xmlContent>
              </foxml:datastreamVersion>
            </foxml:datastream>,
            if($datastreams = "CMDI-PROFILED")
            then
             <foxml:datastream CONTROL_GROUP="R" ID="CMDI-COLLECTION" STATE="A" VERSIONABLE="true">
                <foxml:datastreamVersion CREATED="{current-dateTime()}" ID="CMDI-COLLECTION.0"
                  LABEL="CMD record for {$label}" MIMETYPE="text/xml">
                  <foxml:contentLocation REF="{$fedora-get-url}/{$fedora-pid}/CMDI" TYPE="URL"/>
                </foxml:datastreamVersion>
              </foxml:datastream>
            else ())
        else ()}
        <foxml:datastream CONTROL_GROUP="X" ID="RELS-EXT" STATE="A" VERSIONABLE="true">
          <foxml:datastreamVersion CREATED="2013-09-20T10:44:46.262Z" FORMAT_URI="info:fedora/fedora-system:FedoraRELSExt-1.0"
            ID="RELS-EXT.0" LABEL="RDF Statements about this object" MIMETYPE="application/rdf+xml">
            <foxml:xmlContent>
              <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
                <rdf:Description rdf:about="info:fedora/{$fedora-pid}">
                  <itemID rdf:resource="info:fedora/{$fedora-pid}" xmlns="http://www.openarchives.org/OAI/2.0/"/>
                </rdf:Description>
              </rdf:RDF>
            </foxml:xmlContent>
          </foxml:datastreamVersion>
        </foxml:datastream>
      </foxml:digitalObject>
};



declare function xfedora:resource2foxml($resource-pid as xs:string, $project-pid as xs:string) as element(foxml:digitalObject) {
    xfedora:resource2foxml(("CMDI","DATA"),$resource-pid,$project-pid)
};

declare function xfedora:resource2foxml($datastreams as xs:string*, $resource-pid as xs:string, $project-pid as xs:string) as element(foxml:digitalObject) {
    let $fedora-pid := replace(config:param-value(config:module-config(),"fedora-pid-namespace-prefix"),':$','')||":"||$resource-pid,
        $fedora-collection-pid := replace(config:param-value(config:module-config(),"fedora-pid-namespace-prefix"),':$','')||":"||$project-pid
    let $label := resource:label($resource-pid,$project-pid),
        $owner := project:adminsaccountname($project-pid),
        $MdSelfLink := resource:get-handle("CMDI",$resource-pid,$project-pid),
        $dc := resource:dmd2dc($resource-pid, $project-pid),
        $title := $dc//dc:title,
        $dmd := resource:dmd($resource-pid, $project-pid),
        $cmd-profilename := cmd:profile-id-to-name($dmd//cmd:MdProfile),
        $parentCollection-handle := resource:get-handle("project",$resource-pid,$project-pid)[. = project:get-handle("CMDI",$project-pid)],
        $dmd-created := xmldb:created(util:collection-name($dmd),util:document-name($dmd)),
        $master := resource:master($resource-pid,$project-pid)
    return 
    (:<foxml:digitalObject PID="{$fedora-pid}" VERSION="1.1" xmlns:foxml="info:fedora/fedora-system:def/foxml#"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="info:fedora/fedora-system:def/foxml# http://www.fedora.info/definitions/1/0/foxml1-1.xsd">:)
  <foxml:digitalObject PID="{$fedora-pid}" VERSION="1.1" xmlns:foxml="info:fedora/fedora-system:def/foxml#">
        <foxml:objectProperties>
          <foxml:property NAME="info:fedora/fedora-system:def/model#state" VALUE="Active"/>
          <foxml:property NAME="info:fedora/fedora-system:def/model#label" VALUE="{$label}"/>
          <foxml:property NAME="info:fedora/fedora-system:def/model#ownerId" VALUE="{$owner}"/>
          <foxml:property NAME="info:fedora/fedora-system:def/model#createdDate" VALUE="{fn:current-dateTime()}"/>
          <foxml:property NAME="info:fedora/fedora-system:def/view#lastModifiedDate" VALUE="{fn:current-dateTime()}"/>
        </foxml:objectProperties>
        <foxml:datastream CONTROL_GROUP="X" ID="AUDIT" STATE="A" VERSIONABLE="false">
          <foxml:datastreamVersion CREATED="{fn:current-dateTime()}"
            FORMAT_URI="info:fedora/fedora-system:format/xml.fedora.audit" ID="AUDIT.0" LABEL="Audit Trail for this object" MIMETYPE="text/xml">
            <foxml:xmlContent>
              <audit:auditTrail xmlns:audit="info:fedora/fedora-system:def/audit#"/>
            </foxml:xmlContent>
          </foxml:datastreamVersion>
        </foxml:datastream>
        <foxml:datastream CONTROL_GROUP="X" ID="DC" STATE="A" VERSIONABLE="true">
          <foxml:datastreamVersion CREATED="{fn:current-dateTime()}" FORMAT_URI="http://www.openarchives.org/OAI/2.0/oai_dc/"
            ID="DC1.0" LABEL="Dublin Core Record for this object" MIMETYPE="text/xml">
            <foxml:xmlContent>{$dc}</foxml:xmlContent>
          </foxml:datastreamVersion>
        </foxml:datastream>
        <foxml:datastream CONTROL_GROUP="X" ID="RELS-EXT" STATE="A" VERSIONABLE="true">
          <foxml:datastreamVersion CREATED="{fn:current-dateTime()}" FORMAT_URI="info:fedora/fedora-system:FedoraRELSExt-1.0"
            ID="RELS-EXT.0" LABEL="RDF Statements about this object" MIMETYPE="application/rdf+xml">
            <foxml:xmlContent>
              <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
                <rdf:Description rdf:about="info:fedora/{$fedora-pid}">
                  <itemID rdf:resource="{$fedora-pid}" xmlns="http://www.openarchives.org/OAI/2.0/"/>
                  {if (exists($parentCollection-handle))
                  then <isMemberOf rdf:resource="{$fedora-collection-pid}" xmlns="info:fedora/fedora-system:def/relations-external"/>
                  else ()}
                </rdf:Description>
              </rdf:RDF>
            </foxml:xmlContent>
          </foxml:datastreamVersion>
        </foxml:datastream>
        {if ($datastreams = "CMDI")
        then 
            (<foxml:datastream CONTROL_GROUP="X" ID="CMDI" STATE="A" VERSIONABLE="true">
              <foxml:datastreamVersion ALT_IDS="{$MdSelfLink}" CREATED="{$dmd-created}"
                ID="CMDI.0" LABEL="CMD record for {$label}" MIMETYPE="text/xml">
                <foxml:xmlContent>{$dmd}</foxml:xmlContent>
              </foxml:datastreamVersion>
            </foxml:datastream>,
            if ($cmd-profilename != "" and $datastreams = "CMDI-PROFILED")
            then 
                <foxml:datastream CONTROL_GROUP="R" ID="{$cmd-profilename}" STATE="A" VERSIONABLE="true">
                    <foxml:datastreamVersion CREATED="{current-dateTime()}" ID="{$cmd-profilename}.0"
                      LABEL="CMD record for {$label}" MIMETYPE="text/xml">
                      <foxml:contentLocation REF="{$fedora-get-url}/{$fedora-pid}/CMDI" TYPE="URL"/>
                    </foxml:datastreamVersion>
              </foxml:datastream>
            else ())
        else ()}
        {if ($datastreams = "DATA")
        then 
        <foxml:datastream CONTROL_GROUP="X" ID="DATA" STATE="A" VERSIONABLE="true">
          <foxml:datastreamVersion CREATED="{fn:current-dateTime()}" ALT_IDS="{resource:get-handle("data",$resource-pid,$project-pid)}"
            ID="DATA.0" LABEL="Original Data of this resource" MIMETYPE="text/xml">
            <foxml:xmlContent>{$master}</foxml:xmlContent>
          </foxml:datastreamVersion>
        </foxml:datastream>
        else ()}
      </foxml:digitalObject>
};

