xquery version "3.0";

declare option exist:serialize "method=xml media-type=text/xml";

<projects>
    {
let $path := '/db/cr-projects/'
for $projects in xmldb:get-child-collections($path)
return
    <projectName>{$projects}</projectName>
    }
</projects>