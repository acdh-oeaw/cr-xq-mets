import module namespace gen =  "http://cr-xq/gen" at "generate-mappings-functions.xqm";

import module namespace config="http://exist-db.org/xquery/apps/config" at "../../core/config.xqm";
import module namespace project = "http://aac.ac.at/content_repository/project" at "/db/apps/cr-xq-mets/core/project.xqm"; 
 
 let $project-pid := 'abacus'
 let $config := config:config($project-pid)
let $map := project:map($project-pid)
(:    <map><index name="person">:)
(:                    <path>tei:person</path>:)
(:                    </index>:)
(:                <index name="place">:)
(:                <path>tei:place</path>:)
(:                </index>:)
(:                </map>:)

let $generated-code := gen:generate-index-functions($map, $config)
let $store := gen:store-index-functions($generated-code)
(:return $map:)
 return $generated-code

