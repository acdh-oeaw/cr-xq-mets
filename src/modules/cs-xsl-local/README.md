
The xsl suite cs-xsl is included as a git submodule in

modules/cs-xsl
(needs to be updated separately, it does not get updated automatically with  'git pull' of the main project)

@seeAlso: https://www.kernel.org/pub/software/scm/git/docs/git-submodule.html

this "module" is only for holding the config.xml file
that is needed by the cr-xq for the mappings operation -> xsl-file
i.e. it is specific for cr-xq and thus does not belong in the generic cs-xsl suite.
