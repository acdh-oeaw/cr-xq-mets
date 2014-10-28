module fcs
==========


Exposes a REST-interface to given project adhering to the FCS/SRU protocol 
agreed upon in the Federated Content Search initiative of the CLARIN infrastructure (http://clarin.eu/fcs).


Dependencies
============

* `cs-xsl` - the stylesheets of the corpus_shell project
	currently a snapshot is checked-in, but this will be changed to an external dependency, that will be fetched upon build
* cqlparser  module - activate in `{$EXIST.ROOT}/conf.xml` (possibly necessary to rebuild with the extension module activated explicitely
 under `extension/build.properties` :
```
 	# Contextual Query Parser (CQL) module
		include.module.cqlparser = true
```
