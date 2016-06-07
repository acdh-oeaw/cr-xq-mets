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

module namespace config="http://exist-db.org/xquery/apps/config-params";

(:~ 
config.template.xql file is copied (manually or during build) to config.xql and optionally adapted
config.xql is part of the app - imported by config.xqm
:)

(: the simple variant, however with projects-collection inside /db/apps
declare variable $config:projects-dir := "/db/apps/@projects.dir@/";
declare variable $config:projects-baseuri:= "/@projects.dir@/";
:)

(: this variant allows the projects-folder outside /db/apps
 (mark the trick with parent folder for the baseuri - this is necessary to fool the controller ):
:) 
declare variable $config:projects-dir := "/db/@projects.dir@/";
declare variable $config:data-dir := "/db/@data.dir@/";
declare variable $config:projects-baseuri:= "/@app.name@/../../@projects.dir@/";
declare variable $config:system-account-user:= "@system.account.user@";
declare variable $config:system-account-pwd:= "@system.account.pwd@";
declare variable $config:shib-user-pwd:= "@shib.user.pwd@";
