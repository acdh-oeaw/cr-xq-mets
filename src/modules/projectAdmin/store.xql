xquery version "3.0";

import module namespace project="http://aac.ac.at/content_repository/project" at "../../core/project.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

let $project-pid := request:get-header("project-pid"),
	$form := 		request:get-header("form"),
	$user-id := 	request:get-header("user-id")
let $data := 		request:get-data()

let $log := util:log("INFO", "*** store.xql ***")
let $data-log := util:log("INFO", name($data/*))
(:let $log2 := 
    for $i in ("$data","$project-pid", "$user-id")
    return 
        (util:log("INFO", "*** "||$i||" ***"),
        util:log("INFO", util:eval($i)))
:)
let $update := 
    switch ($form)
        case "dmd"      return project:dmd($project-pid, $data/*)
        case "start"    return project:metsHdr($project-pid, $data/*)
        case "data"     return project:mappings($project-pid, $data/*)
        default     return ()
return $data