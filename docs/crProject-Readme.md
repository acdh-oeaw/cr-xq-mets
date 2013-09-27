%The cr-xq project data model
%Daniel Schopper
%2013-09-25

This README describes briefly the main concepts of the cr-project data model. For implementation notes please refer to the xqdocs HTML reference in `xqdocs/html/_core_project.xqm`.

What's a cr-project?
====================
A `project` in respect to the `cr-xq content repository` refers to two different entities: On the one hand, it refers to the real project which uses the cr-xq repository as its storage. an abstract entity is a collection of language resources to be accessed and displayed in a cr-xq content repository^[For more information on `cr-xq` please refer to <http://www.github.com/vronk/SADE>], providing an individual user interface and accompanying material which may range from simple usage notes to entire scientific papers on the resources and services offered. 

The cr-project data structure describes such a project in its entirety. This means it contains information about:

- the project itself: metdata like editorial or legal information,
- the language resources it makes available: metadata as TEI Headers, data as TEI contents,
- deployment requirements like its configuration with respect to its context or indexes,
- the user interface it provides when ingested in a cr-xq instance: html templates, custom JavaScript code etc.

A cr-project instance (henceforth called `project.xml`) provides a single point of entry to the cr-xq content repository it is deployed to. The content repository uses the information in this file to locate the project's data files, decide on user authorization or provide indexes to access its resources.

By default each cr-xq content repository places its projects in a dedicated `cr-projects` collection. Each project's containing subcollections with the project's dedicated files. For a project to be in a consistent, accessible state, there must be a `project.xml` file present in its subcollection. 

Data model 
===============================
A cr-project XML instance is a special kind of METS file (see <http://www.loc.gov/standards/mets> for an overview of METS) which a in

Project 'Catalogs' and 'Archives'
=================================
A `cr-project` may be instantiated into XML in two ways: aside of inherent content like its own descriptive metadata, it may either consist of references to the content of the cr-xq repository it resides in, or it may serve as a container format, including the data of the project, thus making it interchange format between various cr-xq instances. To avoid confusion we will use the term 'cr-project catalog' in respect to a project deployed in a cr-xq repository which references external files, while the term 'cr-project archive' refers to a project which is self-contained archive of a cr-project as a whole.


Current Limitations 
================================
Supported formats for language resources: only TEI data and metadata.
Planned formats: LMF