xquery version "3.0";

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
