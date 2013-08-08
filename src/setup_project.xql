xquery version "3.0";

import module namespace config="http://exist-db.org/xquery/apps/config" at "/db/apps/cr-xq/core/config.xqm";

(:~  setup project :)
  
  
declare function local:mkcol-recursive($collection, $components) {
    if (exists($components)) then
        let $newColl := concat($collection, "/", $components[1])
        return (
            xmldb:create-collection($collection, $components[1]),
            local:mkcol-recursive($newColl, subsequence($components, 2))
        )
    else
        ()
};

(: Helper function to recursively create a collection hierarchy. :)
declare function local:mkcol($collection, $path) {
    local:mkcol-recursive($collection, tokenize($path, "/"))
};

  
let $project := 'mdrepo'
 let $config := config:config($project)
let $model := map { "config" := $config}
let $project-dir := config:param-value($model, "project-dir")
let $data-dir := config:param-value($model, "data.path")

return xmldb:copy($project-dir, concat("/db/system/config", $data-dir), "collection.xconf")
(:    (local:mkcol("/db/system/config", $data.path),:)
(:        xmldb:copy(concat("/project.template"),$config:projects-dir) ):)
(:xdb:store-files-from-pattern(concat("/system/config", $target), $dir, "*.xconf"):)
