xquery version "3.0";

declare namespace cr="http://aac.ac.at/content_repository";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace mets = "http://www.loc.gov/METS/";
  
import module namespace repo-utils="http://aac.ac.at/content_repository/utils" at "core/repo-utils.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "core/config.xqm"; 
import module namespace project = "http://aac.ac.at/content_repository/project" at "core/project.xqm";

import module namespace index = "http://aac.ac.at/content_repository/index" at "core/index.xqm";

let $project-pid := 'mecmua'

(:return     xmldb:reindex("/db/cr-projects"):)

(:let $path:=$config:cr-config//config:path[@key eq 'projects']:)
(:    return $path:)
(:     check if projects dir is set (if not reindex!)     :)
 let $check-projects-path := if (empty(config:path('projects'))) then xmldb:reindex("/db/apps")
                             else true()
(:let $new-project := project:new($project-pid):)
(:return if (exists($new-project)) then  ("Created project: "||$project-pid||" in "||config:path('projects'), $new-project):)
(:          else if (exists(project:get($project-pid))) then "Project "||$project-pid||" already exists.":)
(:          else "Project "||$project-pid||" could not be instantiated.":)
 return index:store-xconf($project-pid )
(:return project:path("mecmua","data"):)
   
(:   return config:path("metadata"):)