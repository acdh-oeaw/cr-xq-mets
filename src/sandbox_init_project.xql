xquery version "3.0";

declare namespace cr="http://aac.ac.at/content_repository";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace mets = "http://www.loc.gov/METS/";
  
import module namespace repo-utils="http://aac.ac.at/content_repository/utils" at "core/repo-utils.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "core/config.xqm"; 
import module namespace project = "http://aac.ac.at/content_repository/project" at "core/project.xqm";

import module namespace index = "http://aac.ac.at/content_repository/index" at "core/index.xqm";

let $project-pid := 'dict-gate'

(:return project:new($project-pid):)
(:  return config:path('projects'):)
 let $path:=$config:cr-config//config:path[@key eq 'projects']
    return $path

(: return index:store-xconf($project-pid ):)
 
(:return  project:list-resources-resolved($project-pid):)

 