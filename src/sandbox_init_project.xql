xquery version "3.0";

(:
The MIT License (MIT)

Copyright (c) 2016 Austrian Centre for Digital Humanities at the Austrian Academy of Sciences

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE
:)

declare namespace cr="http://aac.ac.at/content_repository";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace mets = "http://www.loc.gov/METS/";
  
import module namespace repo-utils="http://aac.ac.at/content_repository/utils" at "core/repo-utils.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "core/config.xqm"; 
import module namespace project = "http://aac.ac.at/content_repository/project" at "core/project.xqm";

import module namespace index = "http://aac.ac.at/content_repository/index" at "core/index.xqm";


declare function local:init-project($project-pid as xs:string) {
    let $check-projects-path := if (empty(config:path('projects'))) then xmldb:reindex("/db/apps")   
                                else true()
    let $new-project := project:new($project-pid)
    return if (exists($new-project)) then  ("Created project: "||$project-pid||" in "||config:path('projects'), $new-project)
              else if (exists(project:get($project-pid))) then "Project "||$project-pid||" already exists."
              else "Project "||$project-pid||" could not be instantiated."
};

let $project-pid := 'abacus'

(:return     xmldb:reindex("/db/cr-projects"):)

(:let $path:=$config:cr-config//config:path[@key eq 'projects']:)
(:    return $path:)
(:     check if projects dir is set (if not reindex!)     :)

(:~ 1. Create the project (whether you restore or not) :)
return local:init-project($project-pid)

(: return index:store-xconf($project-pid ):)
(:return project:path("mecmua","data"):)
   
(:   return config:path("metadata"):)
(:~ 2. create or upload resources and metadata, register them see sandbox_ixgen.xql and then sandbox_init_resources.xql :)
(:~ 3. if you restore or have created the projects CMDI elsewhere replace the default :)
(:return project:dmd($project-pid, doc('/db/cr-data/'||$project-pid||'/metadata/CMDI/corpus.xml')/*):)