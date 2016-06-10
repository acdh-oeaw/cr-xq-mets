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
declare namespace xlink = "http://www.w3.org/1999/xlink";
declare namespace sru = "http://www.loc.gov/zing/srw/";

import module namespace fcs="http://clarin.eu/fcs/1.0" at "modules/fcs/fcs.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "core/config.xqm"; 
import module namespace toc = "http://aac.ac.at/content_repository/toc" at "core/toc.xqm";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at  "core/repo-utils.xqm";
import module namespace project="http://aac.ac.at/content_repository/project" at "core/project.xqm";
import module namespace index="http://aac.ac.at/content_repository/index" at "core/index.xqm";
import module namespace ltb = "http://aac.ac.at/content_repository/lookuptable" at "core/lookuptable.xqm";
import module namespace ixgen="http://aac.ac.at/content_repository/generate-index" at "modules/index-functions/generate-index-functions.xqm";
import module namespace ixfn = "http://aac.ac.at/content-repository/projects-index-functions/" at "modules/index-functions/index-functions.xqm";

let $project-pid := "abacus",
    $resource-pid := $project-pid||".1",
    $config:=config:project-config($project-pid)
    
return ixgen:generate-index-functions($project-pid)
(: or if an existing project is restored: :)
(:return ixgen:register-project-index-functions():)
(:return index:store-xconf($project-pid ):)
(:return xmldb:reindex(project:path($project-pid,"workingcopies")):)
(:return ltb:dump($resource-pid, $project-pid):)
(:return :)