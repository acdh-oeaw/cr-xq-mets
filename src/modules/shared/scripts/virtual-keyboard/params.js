/**
 * @fileOverview a default version of the module-file for instance specific configuration.
 * Makes things work just pointing a CORS compatible Browser (non-IE, IE >= 10) at the
 * local copy. The switch URL is a temporary reverse proxy solution.
 */
!function(){

var module = {};

/**
 * @module corpus_shell 
 */

/** Base url or where do we live. Does not make much sense on a locally downloaded copy.
 * @type {path|url}  
 */
module.baseURL = "./";
/** The place where the php scripts for user data management live (see the modules/userdata sub directory). It's assumend this is a path which needs to be added to baseUrl.
 * @type {path}
 */
module.userData = "modules/userdata/";
/** The url of the switch script. May be anywhere on the internet if cross-origin resource shareing (CORS, see enable-cors.org) is properly set up.
 * @type {url} 
 */
module.switchURL = "http://localhost/corpus_shell/modules/fcs-aggregator/switch.php";
/** The url or path where the templates which are used for the UI should be loaded from.
 * Please not: if this is a relative url it may be relative to whatever URL the
 * corpus_shell is called from. Do not use relative URLs if you can't be sure
 * about that. Note that this is assumed to end with a slash (/)
 * @type {url|path}
 */
module.templateLocation = "src/";

/**
 * Default width of a new panel.
 * Anything acceptable as a CSS width, px preferable.
 * @type {string}
 */
module.defaultWidth = "525px";

/**
 * Default height of a new panel
 * Anything acceptable as a CSS height, px preferable.
 * @type {string}
 */
module.defaultHeight = "600px";

/**
 * Default left offset for new panels.
 * This will be used to calculate the offset of new windows so a cascading
 * windows effect is achieved.
 * @type {number}
 */
module.defaultLeftOffset = 212;

/**
 * Default top offset for new panels.
 * This will be used to calculate the offset of new windows so a cascading
 * windows effect is achieved.
 */
module.defaultTopOffset = 10;

// publish as params
this.params = module;

}();