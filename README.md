About SADE
==========

The Scalable Architecture for Digital Editions (SADE) tries to meet the requirement for an easy to use publication system for electronic resources and Digital Editions. It is an attempt to provide a modular concept for publishing scholarly editions in a digital medium, based on open standards. Furthermore it is a distribution of open source software tools for the easy publication of Digital Editions and digitized texts in general out of the box. SADE is a scalable system that can be adapted by different projects which follow the TEI guidelines or other XML based formats.

Build
=====

* Copy build.properties.default to build.properties and edit to your needs.
* Build the SADE modules for eXist with ant.
* Build the distribution zip file with build.sh from dist-utils.

Configuration
=============

The system strictly separates logic from content.
Within exist-db - following the current convention - all the code (and templates) is by default placed into
/db/apps/{app-name}

But individual projects are placed in a separate folder, which can/should be outside of the `/db/apps` collection.
By default it is:
/db/sade-projects
but it can be chosen freely, and only has to be set once in:
core/config.xql

more in docs/config.md, templating.md.

Setup steps:

1. Edit build.properties

	app.name=cr-xq
	app.uri=http://vronk.net/ns/cr-xq
	app.version=0.3
	projects.dir=cr-projects

	during build they are used to generate 
	
	repo.template -> repo.xml
	expath-pkg.template.xml -> expath-pkg.xml
	
	$projects.dir + core/config.template.xql -> config.xql
	
2. ant generates an .xar package, that can be installed via package manager 

	upon installation 
	setup.xql is executed
	
	which generates the projects.dir
	and sets up the default project (as copy of the project.template-collection)
	

