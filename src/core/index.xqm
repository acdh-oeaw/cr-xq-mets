xquery version "3.0";

module namespace index = "http://aac.ac.at/content_repository/index";
import module namespace project = "http://aac.ac.at/content_repository/project" at "project.xqm";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at "repo-utils.xqm";
declare namespace xconf = "http://exist-db.org/collection-config/1.0";

declare function index:mappings($project-pid as xs:ID) as element(mappings) {
    project:mappings($project-pid)
};


declare function index:index($project-pid as xs:ID,$key as xs:string) as element(index)? {
    project:mappings($project-pid)//index[@key=$key]
};

declare function index:default($project-pid as xs:ID) as element(index)? {
    project:mappings($project-pid)//index[@key='cql.serverChoice']
};

declare function index:resourcefragment-pid($project-pid as xs:ID) as element(index)? {
    index:index($project-pid, 'cql.serverChoice')
};

declare function index:generate-xconf($project-pid as xs:ID) as element(xconf:collection) {
    let $mappings := index:mappings($project-pid),
        $xsl := doc("mappings2xconf.xsl"),
        $params := <parameters></parameters>,
        $xconf := transform:transform($mappings,$xsl,$params)
    return $xconf
};

declare function index:store-xconf($project-pid as xs:ID) {
    let $xconf:=index:generate-xconf($project-pid)
    let $paths:=(
        project:path($project-pid,'workingcopies'),
        project:path($project-pid,'resourcefragments'),
        project:path($project-pid,'metadata'),
        project:path($project-pid,'lookuptables')
    )
    return
        for $p in $paths
        return
            let $config-path :=  "/db/system/config"||$p
            let $mkPath := repo-utils:mkcol("/db/system/config",$p)
            let $store:=xmldb:store($config-path,"collection.xconf",$xconf)
            return xmldb:reindex($config-path)
(:            return $xconf:)
};