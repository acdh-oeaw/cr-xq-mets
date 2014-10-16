Project Configuration
=====================
Every project has its own configuration stored in `$projects/$project-id/project.xml`
in [METS](http://www.loc.gov/standards/mets/) format.

This provides project-specific information as parameters to the modules.
It has three levels of parameters:

    global
    module
    container/function

There is a tentative schema [config.xsd](../schemas/config.xsd).
See also [default project config](/tharman/SADE/blob/sade_modules/src/project-boilerplate/config.xml)

Optionally, also modules can have config.

config:param-value()
--------------------

To ensure consistent access to the configuration information the config-module provides appropriate functions, that can be called by the modules to retrieve param-values.

There is a precedence ordering defined for retrieving the param-values  (see inline-docs for config:param-value()).