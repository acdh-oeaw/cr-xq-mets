/**
 * @fileOverview a default version of the module-file for instance specific configuration.
 * Makes things work just pointing a CORS compatible Browser (non-IE, IE >= 10) at the
 * local copy. The switch URL is a temporary reverse proxy solution.
 */
!function(){

var module = {};

/** The url or path where the templates which are used for the UI should be loaded from.
 * Please not: if this is a relative url it may be relative to whatever URL the
 * corpus_shell is called from. Do not use relative URLs if you can't be sure
 * about that. Note that this is assumed to end with a slash (/)
 * @type {url|path}
 */
module.templateLocation = "modules/shared/scripts/virtual-keyboard/";

// publish as params
this.params = module;

}();