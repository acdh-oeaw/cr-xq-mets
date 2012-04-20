xquery version "1.0";

module namespace trigger='http://exist-db.org/xquery/trigger';
import module namespace gen =  "http://sade/gen" at "xmldb:exist:///db/sade/core/generate-processor.xqm";

declare option exist:serialize "method=text media-type=text/text";

declare function trigger:after-update-document($uri as xs:anyURI) {
    
    let $x := util:log('debug', concat('Trigger generate-processor after update default/config fired at ', current-dateTime(), 'because: ', $uri ))
    return if($uri eq "config.xml") then
        let $config :=  doc($uri)/*
        let $generated-code := gen:generate-processor($config)
        return xmldb:store("/db/sade/core", "processor.xql", $generated-code)
    else ()
    
};
