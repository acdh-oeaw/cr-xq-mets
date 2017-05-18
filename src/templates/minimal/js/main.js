/**
 * @fileOverview All the functionality necessary for having our
 * three column navigation -> main -> detail layout
 * based on mecmua_template (tried to make project neutral)
 * main (expected) areas:
    #navigation
    #main-container
    #detail/#tabs
   
    more info on the expected HTML-structure of the page: https://github.com/vronk/SADE/blob/cr-xq/docs/template_layout_parts.png   
 */

/**
 * @module minimal_template
 */

!function($, URI){

var m = {},
    currentUrl = new URI(),
/** 
 * configuration object
 * currently only parameter: dataview
*/
    cr_config = { main: {
                     dataview: "title,facets,kwic"
                },
                  detail: {
                     dataview: 'title,cite,navigation,full,facs'
                  },
                  params: {
                    "detail.query": '',
                    query: '',                    
                    "x-format":"html"
                  }
                },


//var detail_tabs;

/**
 * XML Viewer componenet
 */
    xmlViewer,

/**
 * Id of the search container
 */
    search_container_selector = '#search-result',

/**
 * Base URL for the AJAX calls, replaces index.html
 * (or whatever the original URL ends in)
 */
//var cUrl_ = currentUrl.clone();
//cUrl_.query("");
//cUrl_.filename("fcs");
    baseurl = currentUrl
              .clone()
              .query("")
              .filename("fcs");
              
//export
this.MinimalTemplateMain = m;

m.getCurrentURL = function() { return currentUrl.clone();};
m.getBaseURL = function() { return baseurl.clone();};
m.getSearchContainerSelector = function() { return search_container_selector;};
m.getXMLViewer = function() { return xmlViewer;};
m.getCrConfig = function () { return $.extend({}, cr_config);};
m.setCrConfig = function (a_cr_config) {
    // TODO: sanity checks
    cr_config = $.extend({}, a_cr_config);
    return m;
};

m.doLoadDetail = function() {};
m.doLoadDetailData = function() {};

m.resultSelectors = '.result-header,.result-body';

/**
 * Initialization for the ui.
 */
function minimal_template_ui_setup() {
    // Create an accordion for search/navigation
    $(".accordion").accordion({
        header : "h3",
        autoHeight : false,
        active : 0
    });

/* not working yet
    $("#resource-filter").QueryInput({params: {                        
            resource: {label:"Werk", value:"", widget:"selectone", static_source: baseurl.clone().query(?version=1.2&operation=scan&scanClause=fcs.resource&x-format=json")},            
        submit_resource: {value:"filter", label:"", widget:"submit" }},
           onValueChanged: function(v) {console.log(this, v)}
            });

     $('#input-submit_resource').live("click", filter_resource)
   */  
     
    // Create tabs for the detail view, xmlViewer may need refresh.
    // tab-view currently deactivated
    /* detail_tabs = $('#tabs').tabs({
        show : function(event, ui) {
            m.doLoadDetailData(ui.index);
        }
    }); */
    
        // Dialog
    $('#dialog').dialog({
        autoOpen : false,
        width : 600,
        buttons : {
            "Ok" : function() {
                $(this).dialog("close");
            },
            "Cancel" : function() {
                $(this).dialog("close");
            }
        }
    });

    processParams();
    
    m.priority_event_handlers();
    // refresh persistent link
    $(document).on('hover', "a#persistent-link", persistentLink);
    
    
    // handle link to toggle info
    $(document).on('click', "#navigation a.link-info", toggle_info);    
    $("#navigation .data-view.metadata, #navigation .data-view.image, #navigation .data-view.cite").hide();
    
    // handle link to explain
    $(document).on('click', "#navigation a.link-explain", m.load_explain);
    $(document).on('click', "#navigation .indexInfo a", m.load_scan);
    $(document).on('click', "#navigation .zr-indexInfo a.value-caller", m.load_scan);
    
    // handle loading to main (scan -> search) (.content - to distinguish from .header .prev-next) 
    $(document).on('click', "#navigation .load-main .content a", m.load_main);
    // paging in scan
    $(document).on('click', "#navigation .scan a.internal", m.load_scan);
    $(document).on('click', "#navigation .projectDMD.record .result-navigation.prev-next a", m.load_scan);
    
    //
    $(document).on('click', "#navigation .record.resource a.toc", m.load_toc_or_toggle);
    
    $(document).on('click', "#navigation .toc a", handle_toc);
    $(document).on('click', "#navigation .scan-index-fcs-toc .resource a", handle_toc);
    
    $(document).on('click', "#navigation a.index", m.load_scan);

    // register filter
    $(document).on('submit', "#navigation form", filter_default_nav_results);
  
    $(document).on('submit', "#query-input form", m.query);

    // Dialog Link
    $('#dialog_link').click(function() {
        $('#dialog').dialog('open');
        return false;
    });

    $(document).on("click", '.result-header a', m.load_main);
    $(document).on("click", "#navigation .indexes .scan a", m.load_main);
        
    $(document).on("click", '#context-detail a', load_in_context_details);

    // customize icons (from generic 
    m.customizeIcons();

}

m.priority_event_handlers = function() {};

//register this on document ready
$(minimal_template_ui_setup); 

/** checks the request params 
   and post-loads detail-view if detail.query is filled
*/
function processParams () {
    
        cr_config.params = $.extend(cr_config.params, currentUrl.query(true));
        console.log("cr_config.params:")
        console.log(cr_config.params);
        
        if (cr_config.params["detail.query"] || cr_config.params["query"].startsWith("fcs.rf")) {
            
            var detail_params = $.extend({},cr_config.params);
            detail_params["query"] = cr_config.params["detail.query"];
            if (cr_config.params["query"].startsWith("fcs.rf")) {
                detail_params["query"] = cr_config.params["query"];
                cr_config.params["detail.query"] = cr_config.params["query"];
                cr_config.params["query"] = '';
                $("#main #input-query").val('');
            }
            detail_params["x-dataview"] = cr_config.detail.dataview;
           var detail_request = baseurl.clone().query(detail_params).toString();
           console.log("post-loading DETAIL: " + detail_request);
            m.doLoadDetailData(detail_request);
         }
         
           
}

/** generate a persistent link - capturing the current search and detail 
  *  and set the a#persistent-link.href AND window.location.href accordingly
 
  */
function persistentLink() {
    
    var url = currentUrl.clone();
    
    url.query(cr_config.params);    
    link = url.href();
    
    $.extend((new URI()).query(true),
cr_config.params)
    // FIXME: want to just set the location, but not reload page
    // window.location.href=link;
    var persistentLink = $("#persistent-link");
    if (persistentLink.is('input')) {
        persistentLink.val(link);
    }
    if (persistentLink.is('a')) {
        persistentLink.attr("href",link);       
    }
    return link;    
}

/** generic function for ajax-loading snippets into page
just a wrapper around jQuery.load() to ensure consistent functionality 
*/
function load_(targetContainer, targetRequest, callback) {

console.log("load_: " + targetRequest );
     m.loading(targetContainer, 'start');
     
     //targetContainer.html('');
     targetContainer.load(targetRequest, function( response, status, xhr ) {
            m.loading(targetContainer, 'stop');
            //targetContainer.removeClass("cmd_get");
            if (status=='error') { 
                var targetContIds = targetRequest.substr(targetRequest.indexOf(' ') + 1);
                var targetURI = targetRequest.substr(0, targetRequest.indexOf(' '));  
            targetContainer.append("<p class='error'>Sorry, there was an error!</p>" +
                  "<p>calling <a target='_blank'' href='" + targetURI + "' >" + targetURI + "</a>"+ targetContIds + "</p>");
            } else  {
               if (typeof callback == 'function')  {
                   callback();
               } 
            }
     });        
     
}

m.load_ = load_;

function load_explain(event) {
    event.preventDefault();
    var target = $(this).parents('.links');
    
    if (target.find('.explain').length > 0)  
       { target.find('.explain').toggle(); target.find('.scan').toggle();}
      else { 
        var targetRequest = $(this).attr('href');
    //var detailFragment = targetRequest + ' ' + search_container_selector;
        
        $.get(targetRequest,function(data) {
                target.append(data);
                target.append("<div class='scan load-main' />");
                target.prepend("<span class='ui-icon ui-icon-close cmd_close' />");
                close_button = target.find(".cmd_close");
                close_button.click(function() { target.find('.explain').toggle(); target.find('.scan').toggle(); });                
            }        
        );        
      }
}

m.load_explain = load_explain;

function load_scan(event) {
    event.preventDefault();
    //var target = $(this).parents('.record').find(".scan");
  var target = $(this).parents('div').find(".scan");

    
    if (target.length == 0) { 
        $(this).parents('div').append("<div class='scan load-main' />")
    } else { 
        target.toggle();   
    } 
       
     var targetRequest = $(this).attr('href');
    //var detailFragment = targetRequest + ' ' + search_container_selector;

        console.log("targetRequest");
        console.log(target);
        target.show();
/*       target.toggleClass("cmd_get");*/
       m.load_(target, targetRequest, function() {               
                $(target).prepend("<span class='ui-icon ui-icon-close cmd_close' />");
                close_button = $(target).find(".cmd_close");
                close_button.click(function(event) { m.onCloseButtonClicked(event, target); });
                m.customizeIcons();

                target.find("ul").treeview({
        			collapsed: true,
        			animated: "medium"
        		});
            }        
       ); 
/*     target.load(targetRequest, function() {target.toggleClass("cmd_get");});        */
     
}      

m.load_scan = load_scan;

function onCloseButtonClicked(event, target) {
    target.toggle();
}

m.onCloseButtonClicked = onCloseButtonClicked;

function load_toc_or_toggle(event) {
    event.preventDefault();
    var parentRecord = $(this).parents('div.record');
    var target = parentRecord.find('.context-detail');
    if (target.find('.scan-index-fcs-toc').length > 0)  
       { target.toggle(); }
    else { m.load_toc.apply(this, [event])}
}

m.load_toc_or_toggle = load_toc_or_toggle;

function load_toc(event) {
    event.preventDefault();
    var parentRecord = $(this).parents('div.record');
    var target = parentRecord.find('.context-detail');
            //var targetRequest = $(this).attr('href') + " ul.resource";
            var targetRequest = $(this).attr('href');
            // a hack to have the correct element as target even though we are stripping the envelope of the response and just retrieve the inner list (ul.resource)    
            //target_wrapper.append("<div class='scan-index-fcs-toc' />");
            //var target = target_wrapper.find('.scan-index-fcs-toc');
    //var detailFragment = targetRequest + ' ' + search_container_selector;
        /*target.append("<div class='scan load-main' />");
        wrap = target.find(".scan");*/        
        m.load_(target, targetRequest, function(){m.toc_loaded(target, event);});        
}

m.load_toc = load_toc;

function toc_loaded(target, event) {               
    $(target).prepend("<span class='ui-icon ui-icon-close cmd_close' />");
    close_button = $(target).find(".cmd_close");
    close_button.click(function(event){m.onCloseButtonClicked(event, target)});                     
    // a hack to remove the top element (Work itself)    
    var ul_resource = target.find('ul.resource');
    // workaround: IE does not append the content of ul.resource ?! jQuery version 1.11.2?
    var ul_resource_content = ul_resource.html();
    target.find('.scan-index-fcs-toc').html('').append(ul_resource);
    // workaroung: now in IE we hava a ul.resource without any child nodes :(           
    target.find('ul.resource').html(ul_resource_content);
}

m.toc_loaded = toc_loaded;

/** run query via ajax 
  * read query-param from the form 
 */
function query(event) {
    event.preventDefault();
    var target = $('#results');
    
    var query = $(event.target).find("input[name='query']").val();
    var params = {"query":query, "operation": 'searchRetrieve', "x-dataview": 'title,kwic,facets', "x-format":"html" } ; //,xmlescaped
    targetRequest = baseurl.clone().query(params).toString();
    cr_config.params["query"] = query;
    // persistentLink();    
    m.load_(target, targetRequest + ' ' + m.resultSelectors, m.customizeIcons );
}

m.query = query;

/**
 * AJAX loading for the main container (middle column) = search
 * expects a searchRetrieve request URL in $this.href  
 * @param {Object} event
 */
function load_main(event) {
    event.preventDefault();
    var target = $('#results');
    var params = new URI($(this).attr('href')).query(true);    
    // Recreate the x-dataview param from scratch    
    params["x-dataview"] = cr_config.main.dataview;
    var targetRequest = baseurl.clone().query(params).toString();
    //var detailFragment = targetRequest + ' ' + search_container_selector;
    
    cr_config.params["query"] = params["query"];
    
    // set the query into the query input field
    $('#input-query').val(params["query"]);
    
    m.load_(target,targetRequest + ' ' + m.resultSelectors, m.customizeIcons );
}

m.load_main = load_main;

function toggle_info(event) {
    toggle_navigation_data_views(this,event,'info')
}


function toggle_navigation_data_views(context,event, type) {
   event.preventDefault();
    var data_view = {};
    data_view['info'] = $(context).parents(".record").find('.data-view.metadata, .data-view.image, .data-view.cite');
        
    // first check for current status
    var hidden = data_view[type].is(":hidden");
    // then hide all
    $(context).parents(".record").find('.data-view').hide();
    // then open the requested view it was closed
/*    console.log(context);*/
    if (hidden) data_view[type].show();
}

/** handles interactions with the full toc
resource level toggles the nested levels, 
click in nested levels loads in detail
*/
function handle_toc(event) {
    event.preventDefault();
    var parent_span = $(this).parent('span');
    if (parent_span.hasClass('resource')) {
     var parent_li  = parent_span.parent('li');
     parent_li.find('ul .chapter').toggle();    
     parent_li.find('ul .resourcefragment').toggle();
     //filter(":hidden").css("display","inline");
     //parent_li.find('ul span.resourcefragment').filter(":visible").hide();
    } else {
        var target = $('#main');
        var targetRequest = $(this).attr('href');
        m.doLoadDetailData(targetRequest)
    }
}

/**
 * AJAX reloading of the navigation links when using the filter function
 * @param {Object} event
 */
function filter_default_nav_results(event) {
    var loadParent = $(this).parents('div.scan');
    //var loadParentID = loadParent.attr('id');
    // special hack, to only apply on index-scans
    //if (loadParentID != 'fcs-query') {
        event.preventDefault();
        var targetRequest = baseurl.clone().query($(this).serialize()).toString();
        // + ' #' + loadParentID;
        console.log(targetRequest);
        //loadParent.load(targetRequest,customizeIcons);
        target = loadParent;
        loadParent.load(targetRequest,
            function() {
                $(target).prepend("<span class='ui-icon ui-icon-close cmd_close' />");
                close_button = $(target).find(".cmd_close");
                close_button.click(function() { target.toggle(); });
                m.customizeIcons();

                target.find("ul").treeview({
      				collapsed: true,
      				animated: "medium"
      			});
            }  
            );
    //}
}  

function filter_resource(event) {
    event.preventDefault();
    var res_id = $("#input-resource").val();
    var res_label = $("#input-resource").text();
    $('#filtered-resources').text(res_id + ": " + res_label );
     //console.log($("#input-resource").val());
}


/**
 * Preserved target
 */
var targetRequest;
/**
 * Parsed parameters from URL
 */
var params;

/**
 * Extracts the header of the AJAX request and puts it on top of the detail tabs
 */
function extract_header(){
        $('#detail').find('.navi').toggleClass("cmd_get");
        // move title above the tabbed box
        $('.detail-header').html($(this).find(".title"));
        // move navigation above tabbed box
        $('.detail-header .title').after($(this).find(".data-view.navigation"));
        // debug; if released solve differently
        params["x-format"] = "xml";
        $('.detail-header .data-view.navigation').after('<a class="navigation" href="' + baseurl.clone().query(params).toString() + '">&nbsp;FCS/XML&nbsp;</a>');
        }

/**
 * The result of an fcs query contains all the classes needed for the
 * annotated view. To get an unannotated view the classes are stripped.
 */
function create_unannotated_text_in(anotherTab) {
    var detail_anno = $(this).html();
    anotherTab.html(detail_anno);
    // get rid-off the highlighted stuff
    anotherTab.find("span").removeClass("persName bibl placeName name");
    // get rid-off the links
    anotherTab.find('a').replaceWith(function() {
        return $(this).contents();
    });
}

function load_in_context_details(event) {
    event.preventDefault();
    var target = $(search_container_selector);
    targetRequest = $(this).attr('href');
    var detailFragment = targetRequest + ' ' + search_container_selector;
    $(target).load(detailFragment);
}

m.load_in_context_details = load_in_context_details;

function customizeIcons () {
    $('.cmd_prev, .cmd_next, .navigation .prev, .navigation .next').html(""); 
    $('.cmd_prev, .navigation .prev').addClass("fa fa-chevron-left").removeClass("cmd prev cmd_prev");
    $('.cmd_next, .navigation .next').addClass("fa fa-chevron-right").removeClass("cmd next cmd_next");;
}

m.customizeIcons = customizeIcons; 

function loading(targetContainer, startstop) {

if (startstop=='start') {
    targetContainer.prepend("<span class='loading' >loading...</span>");
    var  loading = targetContainer.find(".loading"); 
    loading.modernBlink('start');
   } else {
      var  loading = targetContainer.find(".loading");
      loading.remove();
 }  
}

m.loading = loading;
}(jQuery, URI)

if (!String.prototype.startsWith) {
  String.prototype.startsWith = function(searchString, position) {
    position = position || 0;
    return this.indexOf(searchString, position) === position;
  };
}