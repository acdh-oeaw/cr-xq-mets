Overview
========

The system strictly separates logic from content.
Within exist-db - following the current convention - all the code (and layout templates) is by default placed into
`/db/apps/{app-name}` (where `app-name` is `cr-xq-mets` by default). However individual projects are placed in a separate folder, which can/should be outside of the `/db/apps` collection.
By default it is: `/db/cr-projects` but it can be chosen freely (set in `build.properties`).
Additionally, a separate collection is foreseen for the actual (project-)data. This collection is by default `/db/cr-data`, but can also be customized (property: `data.dir`).

```
/db/apps/cr-xq-mets
/db/cr-data
/db/cr-projects
```

Project
-------

Within `/db/cr-projects` a subdirectory is created whenever a new project is created via [`sandbox_init_project.xql`](src/sandbox_init_project.xql) or the admin website.
This directory contains all the static files that make up HTML part of the project.
That is here you find:
* `project.xml` the central configuration file for the project.
 * you have to define some parts of this file
 * you generate parts of this file e. g. with [`sandbox_init_resource.xql`](src/sandbox_init_resource.xql)
* html pages (recommeded extension `.html`)
* html snippets (recommended extension `.xml`)
* XSL files that change some aspects of the [cs-xsl library](https://github.com/acdh-oeaw/cs-xsl)
* `css` stylesheets
* JavaScript code (`js`)
* fonts (`woff`, `woff2` etc.)
* pictures
* an XQuery module (`/cr-projects/{project-name}/modules/index-functions.xqm`) that is imported into the cr-xq-mets app to speed up getting the indexes and results defined in `project.xml`
 * you generate this file using [`sandbox_ixgen.xql`](src/sandbox_ixgen.xql)
* etc.

The project and the app folder work together as a layered file system.
Files with the same name and in the same subdirectroy as in `/db/apps/{app-name}` will be served
instead of the default on in `/db/apps/{app-name}`. E. g. `/db/apps/cr-projects/{project-name}/template/minimal/index.html` overrides `/db/apps/cr-xq-mets/template/minimal/index.html`.

Data
----

Also within `/db/cr-data` a subdirectory is created whenever a new project is created via [`sandbox_init_project.xql`](src/sandbox_init_project.xql) or the admin website.
This dirctory contains the source xml files that contain the (TEI encoded) data of your project, your edition.
The data needs to be preprocessed using the admin website or [`sandbox_init_resource.xql`](src/sandbox_init_resource.xql).
This produces auxilliary files like:
* working copies (copies of the source files with additional attributes): `_workingcopies`
* resource fragments (snippets of the source files that contain a fragment which is presented to the user as a whole as defined in the `project.xml`): `_resourcefragment`
* lookup tables that speed up processing queries: `_lookuptables`

Furthermore there are additional directories that will contain auxilliary files:
* `_md` can contain (CMDI) metadata for your source files
* `_indexes` conains cached results for the various indexes that users can fetch. The files are generated when a users requests an index.
