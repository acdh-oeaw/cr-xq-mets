xquery version "3.0";

module namespace config="http://exist-db.org/xquery/apps/config-params";

(:~ 
config.template.xql file is copied (manually or during build) to config.xql and optionally adapted
config.xql is part of the app - imported by config.xqm
:)

(: the simple variant, however with projects-collection inside /db/apps
declare variable $config:projects-dir := "/db/apps/@projects.dir@/";
declare variable $config:projects-baseuri:= "/@projects.dir@/";
:)

(: this variant allows the projects-folder outside /db/apps
 (mark the trick with parent folder for the baseuri - this is necessary to fool the controller ):
:) 
declare variable $config:projects-dir := "/db/@projects.dir@/";
declare variable $config:projects-baseuri:= "/@app.name@/../../@projects.dir@/";
