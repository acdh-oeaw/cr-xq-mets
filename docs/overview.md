Overview
========

The system strictly separates logic from content.
Within exist-db - following the current convention - all the code (and layout templates) is by default placed into
`/db/apps/{app-name}`. However individual projects are placed in a separate folder, which can/should be outside of the `/db/apps` collection.
By default it is: `/db/cr-projects` but it can be chosen freely (set in `build.properties`).
Additionally, a separate collection is foreseen for the actual (project-)data. This collection is by default `/db/cr-data`, but can also be customized (property: `data.dir`).

```
/db/apps/cr-xq-mets
/db/cr-data
/db/cr-projects
```

