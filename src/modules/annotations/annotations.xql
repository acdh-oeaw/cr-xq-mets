xquery version "3.0";

import module namespace annotations = "http://aac.ac.at/content_repository/annotations" at "annotations.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "../../core/config.xqm";

let $action := request:get-parameter("action", "list"),
    (: $projectPID is called $project in the controller! :)
    $projectPID := request:get-parameter("project", ""), 
    $user := xmldb:get-current-user()
    

let $className := request:get-parameter("class", ""),
    $resourcePID := request:get-parameter("resourcePID", ""),
    $resourcefragmentPID := request:get-parameter("resourcefragmentPID", ""),
    $crID := request:get-parameter("crID", ""),
    $annID := request:get-parameter("annID", "")
    

return 
    switch($action)
        (: returns the annotation definition for annotation class $className :)
        case "describe" return  
            switch(true())
                case ($className = '') return <error>missing parameter $className</error>
                case ($projectPID = '') return <error>missing parameter $projectPID</error>
                default return annotations:class($projectPID,$className)
                
        case "describeJSON" return  
            switch(true())
                case ($className = '') return <error>missing parameter $className</error>
                case ($projectPID = '') return <error>missing parameter $projectPID</error>
                default return (response:set-header("Content-Type","text/json"), util:serialize(annotations:class($projectPID,$className),'method=JSON'))
                
        
                
        (: returns the HTML form for annotation class $className, possibly populated with current data :)
        case "form" return
            let $request := map{ "user" := $user }
            let $exec :=  
                switch(true())
                    case ($className = '') return <error>missing parameter $className</error>
                    case ($projectPID = '') return <error>missing parameter $projectPID</error>
                    case ($className = 'resourcefragment' and $resourcefragmentPID != '') return annotations:form($projectPID, (), $className, $resourcePID, $resourcefragmentPID, $crID, $request)
                    default return annotations:form($projectPID,$className)
            return 
                if ($exec)
                then $exec
                else <div class="error">An erorr has occured</div>
        
        (: sets the data annotation; if the annotation does not exists it is created first. 
           the annotation is specified either
            - by its project-wide unique id $annID and $projectPID
            - in case of class "resourcefragment" by $className, $resourcePID, $resourcefragmentPID and $projectPID,
            - in case of class "resource" by $className, $resourcePID and $projectPID
            - in case of generic class definitions by the $crID (the identifier of any element in the working copy), $className, $resourcePID and $projectPID
        :)
        case "set" return
            let $expectedParameters :=  annotations:class($projectPID, $className)/annotations:category
            (: we collect the passed paramters by looking at the annotation class definition :)
            let $data := 
                    map:new((
                        for $p in $expectedParameters return 
                        if (not($p/@cardinality) or $p/@cardinality = "1")
                        then map:entry($p,request:get-parameter($p,""))
                        else 
                            for $q in request:get-parameter-names()[starts-with(.,$p)]
                            return map:entry($q,request:get-parameter($q,""))
                    ))
            let $log := util:log-app("DEBUG",$config:app-name, "*** annotation data ***")
            let $log := for $x in map:keys($data) return util:log-app("DEBUG",$config:app-name, concat($x,": ",map:get($data,$x)))
            let $updatedData :=  
                switch(true())
                    case ($className = '') return <error>missing parameter $className</error>
                    case ($projectPID = '') return <error>missing parameter $projectPID</error>
                    
                    (: annotation ID has highest priority :)
                    case ($annID != '') return 
                        annotations:setByID($projectPID, $annID, $data)
                    
                    (: special class "resourcefragment" :)
                    case ($className = 'resourcefragment') return
                        switch(true())
                            case ($resourcefragmentPID = '') return <error>missing parameter $resourcefragmentPID</error>
                            case ($resourcePID = '') return  <error>missing parameter $resourcePID</error>
                            default return annotations:set($projectPID, (), $className, $resourcePID, $resourcefragmentPID, (), $data)
                    
                    (: special class "resource" :)
                    case ($className = 'resource') return 
                        if ($resourcePID = "")
                        then <error>missing parameter $resourcePID</error>
                        else annotations:set($projectPID, (), $className, $resourcePID, (), (), $data)
                    
                    (: generic class definitons  :)
                    default return  
                        switch(true())
                            case ($resourcePID = "") return <error>missing parameter $resourcePID</error>
                            case ($crID = "") return <error>missing parameter $crID</error>
                            case ($className = "") return <error>missing parameter $class</error>
                            default return annotations:set($projectPID, (), $className, $resourcePID, (), $crID, $data)
                    
            return
                (: annotations:set() returns one annotation element, so we have to convert it to an HTML form :)
                if ($updatedData)
                then annotations:form($projectPID, (), $className, $resourcePID, $resourcefragmentPID, $crID, ())
                else <div class="error">An error has occured.</div>
        
        case "get" return
            annotations:get($projectPID, $annID, $className, $resourcePID, $resourcefragmentPID, $crID)
            
        case "remove" return
            ()
            
        case "list" return annotations:classes($projectPID) 
            
        default return annotations:classes($projectPID)
