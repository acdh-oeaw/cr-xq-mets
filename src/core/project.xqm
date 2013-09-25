xquery version "3.0";
(:~ 
: This module provides functions for managing cr-xq projects, including:
: <ul>
:   <li>creation, modification, deletion</li> 
:   <li>import and export</li>
:   <li>validation and sanity checking</li>
: </ul>
:
: It relies on the cr-project data definion version 1.0, as expressed 
: in the mets profile at http://www.github.com/vronk/SADE/docs/crProject-profile.xml. 
: The profile also contains a sample instance which my be used for testing purposes.   
:
: It is designed to be used with a version of the cr-xq content 
: repository from September 2013 or later.
:
: @author Daniel Schopper, daniels.schopper@oeaw.ac.at
: @version 0.1
: @see http://www.github.com/vronk/SADE/docs/crProject-readme.md
~:)

module namespace project = "http://aac.ac.at/content_repository/projects";

declare namespace mets = "http://www.loc.gov./mets";

(:~
:  Instanciates an empty project template.
:
: @return mets:mets
~:)
declare function project:new() as element(mets:mets) {
    element mets:mets {}
};


(:~
:  Creates an empty project template.
:
: @param $config the URI to a project config.xml file.
: @return mets:mets
~:)
declare function project:new($config as xs:anyURI) as element(mets:mets) {
   element mets:mets {}    
};


(:~
: Imports a cr-archive (a self-contained cr-project) into the content repository.
:
: @param $archive the cr-archive to be imported.
: @return the uri of the new project collection containing the cr-catalog.
~:)
declare function project:import($archive as document-node()) as xs:anyURI? {
    ()
};


(:~
: Exports a cr-catalog (a cr-project referencing data in a cr-xq repository) as a standalone cr-archive.  
:
: @param $config the uri of the cr-catalog to be exported
: @return the self-contained cr-archive.
~:)
declare function project:export($config as xs:anyURI) as document-node()? {
    ()
};


(:~
: removes the cr-project from the content repository without removing the project's resources. Same as 
: calling project:purge($config, true()).  
:
: @param $config the uri of the cr-catalog to be removed
: @return true if projec 
~:)
declare function project:purge($config as xs:anyURI) as xs:boolean {
    false()
};

(:~
: removes the cr-project from the content repository without removing the project's resources. 
: @param $config the uri of the cr-catalog to be removed
: @return true if projec 
~:)
declare function project:purge($config as xs:anyURI, $delete-data as xs:boolean) as xs:boolean {
    false()
};





