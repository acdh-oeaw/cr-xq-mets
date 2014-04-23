xquery version "3.0";

module namespace api = "http://www.aac.ac.at/content_repository/api";
declare namespace rest="http://exquery.org/ns/restxq";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare namespace cr="http://aac.ac.at/content_repository";
declare namespace mets = "http://www.loc.gov/METS/";
declare namespace mods="http://www.loc.gov/mods/v3";
declare namespace metsrights = "http://cosimo.stanford.edu/sdr/metsrights/";
declare namespace sm="http://exist-db.org/xquery/securitymanager";

(: *** project.xqm *** :)
declare
    %rest:GET
    %rest:path("/cr_xq")
function api:project_project-pids() {
    ()
	(:project:project-pids():)
};

declare 
    %rest:POST
    %rest:path("/cr_xq")
function api:project_new() {
    ()
	(:project:new():)
};


declare
    %rest:POST
    %rest:path("/cr_xq/{$project-pid}")
function api:project_new($project-pid as xs:string) {
    ()
	(:project:new($project-pid as xs:string):)
};

declare
    %rest:PUT("{$data}")
    %rest:path("/cr_xq/{$project-pid}")
function api:project_new($data as element(mets:mets),$project-pid as xs:string?) as element(mets:mets)?  {
    ()
	(:project:new($data as element(mets:mets),$project-pid as xs:string?) as element(mets:mets)? ):)
};


declare
    %rest:GET
    %rest:path("/cr_xq/{$project-pid}/label")
    %output:method("xml")
    %output:media-type("text/xml")
function api:project_label($project-pid as xs:string) as element(data) {
    ()
	(:project:label($project-pid as xs:string) as element(data):)
};
    
declare
    %rest:PUT("{$data}")
    %rest:path("/cr_xq/{$project-pid}/label")
function api:project_label($project-pid as xs:string, $data as document-node()) as document-node() {
    ()
	(:project:label($project-pid as xs:string, $data as document-node()) as document-node():)
};

declare 
    %rest:GET
    %rest:path("/cr_xq/{$project}")
function api:project_get($project) as element(mets:mets)? {
   ()
	(:project:get($project) as element(mets:mets)?):)
};


declare
    %rest:DELETE
    %rest:path("/cr_xq/{$project-pid}")
function api:project_purge($project-pid as xs:string) as empty() {
    ()
	(:project:purge($project-pid as xs:string) as empty():)
};

declare
    %rest:DELETE
    %rest:query-param("delete-data", "{$delete-data}")
    %rest:path("/cr_xq/{$project-pid}")
function api:project_purge($project-pid as xs:string, $delete-data as xs:boolean*) as empty() {
    ()
	(:project:purge($project-pid as xs:string, $delete-data as xs:boolean*) as empty():)
};


declare 
    %rest:path("/cr_xq/{$project-pid}/status")
    %rest:PUT("{$data}")
function api:project_status($project-pid as xs:string, $data as document-node()) as document-node()? {
    ()
	(:project:status($project-pid as xs:string, $data as document-node()) as document-node()?):)
};

declare 
    %rest:GET
    %rest:path("/cr_xq/{$project-pid}/status")
function api:project_status($project-pid as xs:string) as element(data) {
    ()
	(:project:status($project-pid as xs:string) as element(data):)
};

declare
    %rest:GET
    %rest:path("/cr_xq/{$project-pid}/status-code")
function api:project_status-code($project-pid as xs:string) as element(data) {
    ()
	(:project:status-code($project-pid as xs:string) as element(data):)
};

declare 
    %rest:path("/cr_xq/{$project-pid}/status-code")
    %rest:PUT("{$data}")
function api:project_status-code($project-pid as xs:string, $data as xs:integer) as empty() {
    ()
	(:project:status-code($project-pid as xs:string, $data as xs:integer) as empty():)
};

declare
    %rest:GET
    %rest:path("/cr_xq/status-list") 
function api:project_list-defined-status() as element(status){
    ()
};

declare
    %rest:GET
    %rest:path("/cr_xq/{$project-pid}/resources")
function api:project_resources($project-pid as xs:string) as element(mets:div)* {
    ()
	(:project:list-defined-status() as element(status){
    ()
};

declare
    %rest:GET
    %rest:path("/cr_xq/{$project-pid}/resources")
function api:project_resources($project-pid as xs:string) as element(mets:div)*):)
};

declare
    %rest:GET
    %rest:path("/cr_xq/{$project-pid}/resource-pids")
function api:project_resource-pids($project-pid as xs:string) as xs:string* {
    ()
	(:project:resource-pids($project-pid as xs:string) as xs:string*):)
};

declare 
    %rest:GET
    %rest:path("/cr_xq/{$project-pid}/metsHdr")
function api:project_metsHdr($project-pid as xs:string) as element(mets:metsHdr){
    ()
};

declare
    %rest:path("/cr_xq/{$project-pid}/metsHdr")
    %rest:PUT("{$data}")
function api:project_metsHdr($project-pid as xs:string, $data as element(mets:metsHdr)) as empty() {
    ()
	(:project:metsHdr($project-pid) :)
    ()
};

declare
    %rest:path("/cr_xq/{$project-pid}/metsHdr")
    %rest:PUT("{$data}")
function api:project_metsHdr($project-pid as xs:string, $data as element(mets:metsHdr)) as empty() {
    ()
};

declare 
    %rest:GET
    %rest:path("/cr_xq/{$project-pid}/dmd")
function api:project_dmd($project-pid as xs:string) as element(mods:mods){
    ()
};

declare
    %rest:path("/cr_xq/{$project-pid}/dmd")
    %rest:PUT("{$data}")
function api:project_dmd($project-pid as xs:string, $data as element(mods:mods)) as empty() {
    ()
	(:project:dmd($project-pid as xs:string):)
};


declare
    %rest:GET
    %rest:path("/cr_xq/{$project}/map") 
function api:project_map($project) as element(map)? {
    ()
	(:project:map($project) as element(map)?):)
};

declare
    %rest:path("/cr_xq/{$project-pid}/map")
    %rest:PUT("{$data}")
function api:project_map($project-pid as xs:string, $data as element(map)) as empty() {
    ()
	(:project:map($project-pid as xs:string, $data as element(map)) as empty():)
};

declare 
    %rest:GET
    %rest:path("/cr_xq/{$project-pid}/parameters") 
function api:project_parameters($project-pid as xs:string) as element(param)* {
    ()
	(:project:parameters($project-pid as xs:string) as element(param)*):)
};

declare
    %rest:path("/cr_xq/{$project-pid}/parameters")
    %rest:PUT("{$data}")
function api:project_parameters($project-pid as xs:string, $data as element(param)*) as empty() {
    ()
	(:project:parameters($project-pid as xs:string, $data as element(param)*) as empty():)
};

declare
    %rest:GET
    %rest:path("/cr_xq/{$project-pid}/moduleconfig")
function api:project_moduleconfig($project-pid as xs:string) as element(module)* {
    ()
	(:project:moduleconfig($project-pid as xs:string) as element(module)*):)
};

declare
    %rest:path("/cr_xq/{$project-pid}/moduleconfig")
    %rest:PUT("{$data}")
function api:project_moduleconfig($project-pid as xs:string, $data as element(module)*) as empty() {
    ()
	(:project:moduleconfig($project-pid as xs:string, $data as element(module)*) as empty():)
};


declare
    %rest:GET
    %rest:path("/cr_xq/{$project-pid}/license")
function api:project_license($project-pid as xs:string) as element(metsrights:RightsDeclarationMD)? {
    ()
	(:project:license($project-pid as xs:string) as element(metsrights:RightsDeclarationMD)?):)
};

declare
    %rest:path("/cr_xq/{$project-pid}/license")
    %rest:PUT("{$data}")
function api:project_license($project-pid as xs:string, $data as element(metsrights:RightsDeclarationMD)?) as empty() {
    ()
	(:project:license($project-pid as xs:string, $data as element(metsrights:RightsDeclarationMD)?) as empty():)
};


declare
    %rest:GET
    %rest:path("/cr_xq/{$project-pid}/acl")
function api:project_acl($project-pid as xs:string) as element(sm:permission)? {
    ()
	(:project:acl($project-pid as xs:string) as element(sm:permission)?):)
};

declare 
    %rest:path("/cr_xq/{$project-pid}/acl")
    %rest:PUT("{$data}")
function api:project_acl($project-pid as xs:string, $data as element(sm:permission)?) as empty() {
    ()
	(:project:acl($project-pid as xs:string, $data as element(sm:permission)?) as empty():)
};


(: *** resource.xqm *** :)
declare 
    %rest:DELETE
    %rest:path("/cr_xq/{$project-pid}/{$resource-pid}")
function api:resource_purge($resource-pid as xs:string, $project-pid as xs:string){
    ()
};

declare
    %rest:DELETE
    %rest:path("/cr_xq/{$project-pid}/{$resource-pid}")
    %rest:query-param("delete-data","{$delete-data}")
function api:resource_purge($resource-pid as xs:string, $project-pid as xs:string, $delete-data as xs:boolean*) as empty() {
    ()
	(:resource:purge($resource-pid as xs:string, $project-pid as xs:string):)
};

declare
    %rest:DELETE
    %rest:path("/cr_xq/{$project-pid}/{$resource-pid}")
    %rest:query-param("delete-data","{$delete-data}")
function api:resource_purge($resource-pid as xs:string, $project-pid as xs:string, $delete-data as xs:boolean*) as empty() {
    ()
    (:resource:purge($resource-pid, $project-pid, $delete-data):)
};

declare
    %rest:POST("{$data}")
    %rest:path("/cr_xq/{$project-pid}/newResourceWithLabel")
    %rest:header-param("resource-label", "{$resource-label}")
function api:resource_new-with-label($data as document-node(), $project-pid as xs:string, $resource-label as xs:string*) {
    ()
	(:resource:new-with-label($data as document-node(), $project-pid as xs:string, $resource-label as xs:string*):)
};

declare
    %rest:POST("{$data}")
    %rest:path("/cr_xq/{$project-pid}/newResource")
function api:resource_new($data as document-node(), $project-pid as xs:string){
    ()
};

declare
    %rest:POST("{$data}")
    %rest:path("/cr_xq/{$project-pid}/newResource")
    %rest:query-param("make-fragments","{$make-fragments}")
function api:resource_new($data as document-node(), $project-pid as xs:string, $make-fragments as xs:boolean*) as xs:string? {
    ()
(:	resource:new($data, $project-pid):)
};

declare
    %rest:POST("{$data}")
    %rest:path("/cr_xq/{$project-pid}/newResource")
    %rest:query-param("make-fragments","{$make-fragments}")
function api:resource_new($data as document-node(), $project-pid as xs:string, $make-fragments as xs:boolean*) as xs:string? {
    ()
    (:	resource:new($data, $project-pid,$make-fragments):)
};

declare
    %rest:GET
    %rest:path("/cr_xq/{$project-pid}/{$resource-pid}/entry")
function api:resource_get($resource-pid as xs:string,$project-pid as xs:string) as element(mets:div)? {
    ()
	(: resource:get($resource-pid,$project-pid) :)    
};

declare
    %rest:GET
    %rest:path("/cr_xq/{$project-pid}/{$resource-pid}/files")
function api:resource_files($resource-pid as xs:string,$project-pid as xs:string) as element(mets:fileGrp)? {
  ()
	(:resource:files($resource-pid,$project-pid):)
};

declare
    %rest:GET
    %rest:path("/cr_xq/{$project-pid}/{$resource-pid}")
function api:resource_master($resource-pid as xs:string, $project-pid as xs:string) as document-node()? {
    ()
	(:resource:master($resource-pid, $project-pid):)
};

declare
    %rest:GET
    %rest:path("/cr_xq/{$project-pid}/{$resource-pid}/dmd")
function api:resource_dmd-from-id($resource-pid as xs:string,$project-pid as xs:string) as element()? {
    ()
	(:resource:dmd-from-id($resource-pid,$project-pid):)
};

declare
    %rest:PUT("{$data}")
    %rest:path("/cr_xq/{$project-pid}/{$resource-pid}/dmd")
    %rest:query-param("mdtype","{$mdtype}","TEI")
function api:resource_dmd($resource-pid as xs:string, $project-pid as xs:string, $data as item(), $mdtype as xs:string*) as empty() {
    ()
	(:resource:dmd($resource-pid, $project-pid, $data, $mdtype):)
};

declare
    %rest:PUT("{$data}")
    %rest:path("/cr_xq/{$project-pid}/{$resource-pid}/dmd")
function api:resource_dmd($resource-pid as xs:string, $project-pid as xs:string, $data as item(), $mdtype as xs:string, $store-to-db as xs:boolean?) as empty() {
    ()
	(:resource:dmd($resource-pid, $project-pid, $data, $mdtype, $store-to-db):)
};


declare
    %rest:GET
    %rest:path("/cr_xq/{$project-pid}/{$resource-pid}/label")
function api:resource_label($resource-pid as xs:string, $project-pid as xs:string) as element(cr:response) {
    ()
	(:resource:label($resource-pid, $project-pid):)
};

declare
    %rest:PUT("{$data}")
    %rest:path("/cr_xq/{$project-pid}/{$resource-pid}/label")
function api:resource_label($data as document-node(), $resource-pid as xs:string, $project-pid as xs:string) as element(cr:response)? {
    ()
	(:resource:label($data, $resource-pid, $project-pid):)
};


(: *** resourcefragment.xqm *** :)
declare
    %rest:GET
    %rest:path("/cr_xq/{$project-pid}/{$resource-pid}/{$resourcefragment-pid}/entry")
function api:rf_record($resourcefragment-pid as xs:string, $resource-pid as xs:string, $project-pid as xs:string) as element(mets:div)? {
    ()
	(:rf:record($resourcefragment-pid, $resource-pid, $project-pid):)
};

declare
    %rest:GET
    %rest:path("/cr_xq/{$project-pid}/{$resource-pid}/{$resourcefragment-pid}")
function api:rf_get($resourcefragment-pid as xs:string, $resource-pid as xs:string, $project-pid as xs:string) as element()? {
    ()
	(:rf:get($resourcefragment-pid, $resource-pid, $project-pid) :)
};