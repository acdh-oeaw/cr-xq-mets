xquery version "3.0";

module namespace facs="http://www.oeaw.ac.at/icltt/cr-xq/facsviewer";
import module namespace config="http://exist-db.org/xquery/apps/config" at "../../core/config.xqm";
import module namespace config-params="http://exist-db.org/xquery/apps/config-params" at "../../core/config.xql";
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at "../../core/repo-utils.xqm"; 
declare namespace exist="http://exist.sourceforge.net/NS/exist";
declare namespace tei="http://www.tei-c.org/ns/1.0";
import module namespace kwic="http://exist-db.org/xquery/kwic";
import module namespace ngram="http://exist-db.org/xquery/ngram";
import module namespace fcs = "http://clarin.eu/fcs/1.0" at "../fcs/fcs.xqm";


(: moved to fcs.xqm :)
(:declare function facs:add-exist-match($match as node()) {
    let $ancestor-with-id:= $match/ancestor-or-self::*[@xml:id][1]
    return  if (exists($ancestor-with-id)) 
            then facs:add-exist-match($ancestor-with-id, $match)
            else $match
};

declare function facs:add-exist-match($ancestor as node(), $match as node()) {
    typeswitch ($ancestor)
        case element()  return   element {name($ancestor)} {
                                    $ancestor/@*,
                                    if ((some $x in $ancestor/@* satisfies $x is $match) or $ancestor is $match)
                                    then <exist:match>{$ancestor/node() except $ancestor/@*}</exist:match> 
                                    else for $i in $ancestor/node() except $ancestor/@* 
                                         return facs:add-exist-match($i, $match)
                                }
        case text()     return $ancestor
        default         return $ancestor
};:)

declare function facs:filename-to-path($filename as xs:string, $x-context){
	let $config:=config:config($x-context)
	return facs:filename-to-path($filename, $x-context, map{"config":=$config})
};


declare function facs:filename-to-path($filename as xs:string, $x-context, $config){
    let $facs-path:=    config:param-value((), $config, 'facsviewer', '', "facs.path"),
        $facs-prefix:=  if (config:param-value($config, "facs.prefix")) then config:param-value($config, "facs.prefix") else '',
        $facs-suffix:=  if (config:param-value($config, "facs.suffix")) then config:param-value($config, "facs.suffix") else ''
    return
        concat(
            (if (not(matches($facs-path,concat($x-context,'/?$'))))
            then $facs-path||$x-context||'/'
            else (if (ends-with($facs-path,'/')) then $facs-path else $facs-path||'/')),
            $facs-prefix,$filename,$facs-suffix
        )
};



declare function facs:doc-uri-to-project-id($uri as xs:anyURI) as xs:string? {
    if ($uri!='/.')
    then 
        let $path:=util:collection-name($uri||".") (: dot needed to get to the innermost collection, otherwise collection-name("/db/collection") wil return /db instead of /db/collection :)
        let $project-dirs:=collection($config-params:projects-dir)//param[@key='data-dir']
        let $log:=if(empty($project-dirs)) then util:log("INFO","$project-dirs is empty") else ()
        return 
            if ($project-dirs!replace(.,'/$','') = $path) 
            then
                let $project-id:=$project-dirs[replace(.,'/$','') = $path]  /ancestor::config//param[@key='project-id']
                return 
                    if ($project-id !='' and config:project-exists($project-id))
                    then ($project-id,util:log("INFO","$project-id: "||$project-id))
                    else ()
            else (facs:doc-uri-to-project-id(xs:anyURI(replace($path,'/[^/.]*?$','')||"/.")))
    else ()
};

declare function facs:innerContent($input as node()) as node() {
    let $content:=  typeswitch ($input)
                        case attribute()     return $input
                        case text()          return $input
                        case document-node() return $input/*
                        case element(TEI)    return $input/text
                        default              return $input/*
    return  switch (count($content))
                case 0      return $input
                case 1      return facs:innerContent($content) 
                default     return $input
};
    
declare function facs:create-scratchfile($doc-uri) {
    let $facs:page-element:="div",
        $facs:page-element-namespace:="http://www.tei-c.org/ns/1.0",
        $facs:page-element-attributes:="type='page' n='{pos}'"
    return facs:create-scratchfile($doc-uri,$facs:page-element,$facs:page-element-namespace,$facs:page-element-attributes)
};

declare function facs:create-scratchfile($doc-uri, $facs:page-element, $facs:page-element-namespace, $facs:page-element-attributes) {
    (: TODO read from config :)
    let $doc-filename:=     replace($doc-uri,'/.*/','')
    let $project:=          facs:doc-uri-to-project-id($doc-uri)
    let $config:=           if (config:project-exists($project)) 
                            then map {"config" := config:project-config($project)} 
                            else ()
    let $data-dir:=         config:param-value($config,"data-dir")
    let $pages-project-dir:=config:param-value($config,"pages-dir")
    let $data-dir-to-pages-dir:=replace($pages-project-dir,$data-dir,'')
    let $scratchfile-filename:="pages-"||$doc-filename
    
    let $doc:=  if (doc-available($doc-uri))
                then doc($doc-uri)
                else util:log("INFO", "document "||$doc-uri||" not available")
                
    let $create-pages-project-dir:= if (xmldb:collection-available($pages-project-dir))
                                    then ()
                                    else xmldb:create-collection($data-dir,$data-dir-to-pages-dir)
    let $t1:=       current-time()
    let $pages:=    if (exists($doc) and config:project-exists($project))
                    then 
                        for $pb at $pos in ($doc//pb|$doc//tei:pb)
                        let $page-id:=  let $orig-id:=  switch(true())
                                                            case exists($pb/@xml:id)return $pb/@xml:id
                                                            case exists($pb/@facs)  return $pb/@facs
                                                            default                 return fn:format-number($pos,'000000')
                                        return "page_"||$orig-id
                        let $next:=     ($pb/following::tei:pb|$pb/following::pb)[1]
                        let $log:=       util:log("INFO", "start processing "||$page-id)
                        let $content:=  util:parse(
                                            util:get-fragment-between($pb,$next,true(),true())
                                        )
                        (:let $innerContent:=facs:innerContent($content)
                        return <div type="page" xml:id="{$page-id}">{$innerContent}</div>:)
                        return 
                            element {QName($facs:page-element-namespace,$facs:page-element)} {
                                if ($facs:page-element-attributes != '')
                                then 
                                    for $attr in tokenize($facs:page-element-attributes, '\s+')
                                    let $name:=substring-before($attr,'='),
                                        $value:=replace(substring-after($attr,'='),'(^["'']|["'']$)','')
                                    return attribute {$name} {
                                        switch ($value)
                                            case '{pos}'    return xs:string($pos)
                                            default         return xs:string($value)
                                    }
                                else (),
                                attribute xml:id {$page-id},
                                $content
                            }
                     else ()
    let $t2:=       current-time()   
    let $scratchfile-content:=  <TEI xmlns="http://www.tei-c.org/ns/1.0">
                                    <teiHeader>
                                        <fileDesc>
                                            <titleStmt>
                                               <title>Pages from {$doc-filename}</title>
                                            </titleStmt>
                                            <publicationStmt>
                                               <p>Publication Information</p>
                                            </publicationStmt>
                                            <sourceDesc>
                                               <p>Automatically generated by exist:get-fragment-between()</p>
                                            </sourceDesc>
                                            <revisionDesc>
                                                <change type="created" when="{current-dateTime()}" who="{xmldb:get-current-user()}"/>
                                             </revisionDesc>
                                        </fileDesc>
                                    </teiHeader>
                                    <text>
                                        <body>{$pages}</body>
                                    </text>
                                </TEI>
    
    return 
        if (exists($doc) and config:project-exists($project)) 
        then 
            let $log:=util:log("INFO","created a scratchfile "||$scratchfile-filename),
                $log:=util:log("INFO","writing it to "||$pages-project-dir)
            let $store:=xmldb:store($pages-project-dir,$scratchfile-filename,$scratchfile-content)
            let $reindex:=xmldb:reindex($pages-project-dir)
(:            let $log:=util:log("INFO","reindexing "||$pages-project-dir):)
            return ()
        else ()
};