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

module namespace test="http://sade/test";
import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";

declare variable $test:id := "test";

declare function test:main ($node as node(), $model as map(*)) {
 
 config:app-info($node, $model)
 (:   <table><thead><tr><th>key</th><th>value</th></tr></thead>{
        for $key in config:param-keys($model)
            return <tr><td>{$key}</td><td>{config:param-value($node, $model,$test:id,'main',$key)}</td></tr>
       }
       </table>:)
 
};



declare function test:params ($node as node(), $model as map(*), $param1 as xs:string, $param2 as xs:string) {
 
 
    <table><thead><tr><th>key</th><th>value</th></tr></thead>
           <tr><td>param1</td><td>{$param1}</td></tr>
           <tr><td>param2</td><td>{$param2}</td></tr>
       </table>
 
};
