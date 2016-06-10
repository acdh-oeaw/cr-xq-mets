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
import module namespace fcs="http://clarin.eu/fcs/1.0" at "modules/fcs/fcs.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "core/config.xqm"; 
import module namespace project = "http://aac.ac.at/content_repository/project" at "core/project.xqm";
import module namespace resource="http://aac.ac.at/content_repository/resource" at "core/resource.xqm";
import module namespace rf = "http://aac.ac.at/content_repository/resourcefragment" at "core/resourcefragment.xqm";
import module namespace wc="http://aac.ac.at/content_repository/workingcopy" at "core/wc.xqm";
import module namespace lt = "http://aac.ac.at/content_repository/lookuptable" at "core/lookuptable.xqm";
import module namespace toc = "http://aac.ac.at/content_repository/toc" at "core/toc.xqm";
import module namespace facs = "http://aac.ac.at/content_repository/facs" at "core/facs.xqm";

import module namespace index = "http://aac.ac.at/content_repository/index" at "core/index.xqm";

let $project-pid := 'abacus'

let $path := project:path($project-pid,"workingcopies"),
    $data := collection($path)

let $pos1 := "ADV",
    $pos2 := "PIS"
let $window := 2

let $hits := ($data//*[@cr:w][@type=$pos1])
return
    for $hit in $hits return
    let $prev := root($hit)//*[@cr:w = (xs:integer($hit/@cr:w)+1 to xs:integer($hit/@cr:w)+$window)],
        $foll := root($hit)//*[@cr:w = (xs:integer($hit/@cr:w)-$window to xs:integer($hit/@cr:w)-1)],
        $window := ($prev,$foll)
    return 
    if ($pos2 = $window/@type)
    then (($prev,$hit,$foll),'**')
    else ()
