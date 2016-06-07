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

module namespace dbutil="http://exist-db.org/xquery/dbutil";

(:~ Scan a collection tree recursively starting at $root. Call $func once for each collection found :)
declare function dbutil:scan-collections($root as xs:anyURI, $func as function(xs:anyURI) as item()*) {
    $func($root),
    for $child in xmldb:get-child-collections($root)
    return
        dbutil:scan-collections(xs:anyURI($root || "/" || $child), $func)
};

(:~
 : List all resources contained in a collection and call the supplied function once for each
 : resource with the complete path to the resource as parameter.
 :)
declare function dbutil:scan-resources($collection as xs:anyURI, $func as function(xs:anyURI) as item()*) {
    for $child in xmldb:get-child-resources($collection)
    return
        $func(xs:anyURI($collection || "/" || $child))
};

(:~ 
 : Scan a collection tree recursively starting at $root. Call the supplied function once for each
 : resource encountered. The first parameter to $func is the collection URI, the second the resource
 : path (including the collection part).
 :)
declare function dbutil:scan($root as xs:anyURI, $func as function(xs:anyURI, xs:anyURI?) as item()*) {
    dbutil:scan-collections($root, function($collection as xs:anyURI) {
        $func($collection, ()),
        (:  scan-resources expects a function with one parameter, so we use a partial application
            to fill in the collection parameter :)
        dbutil:scan-resources($collection, $func($collection, ?))
    })
};

declare function dbutil:find-by-mimetype($collection as xs:anyURI, $mimeType as xs:string) {
    dbutil:scan($collection, function($collection, $resource) {
        if (exists($resource) and xmldb:get-mime-type($resource) = $mimeType) then
            $resource
        else
            ()
    })
};