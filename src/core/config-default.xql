xquery version "3.0";

module namespace config="http://exist-db.org/xquery/apps/config-params";

(:~ this file needs to be renamed to config.xql (imported by config.xqm
and optionally adapted
:)

declare variable $config:projects-dir := "/db/apps/sade-projects/";
declare variable $config:projects-baseuri:= "/sade-projects/";
