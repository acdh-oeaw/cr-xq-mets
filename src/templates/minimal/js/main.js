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


var currentUrl = new URI();


/** 
 * configuration object
 * currently only parameter: dataview
*/
var cr_config = { main: {dataview: "title,facets,kwic"}, detail: { dataview: 'title,cite,navigation,full,facs'},
                   params: {"x-format":"html"}
                };


//var detail_tabs;

/**
 * Global var for XML Viewer componenet
 */
var xmlViewer;

/**
 * Id of the search container
 */
var search_container_selector = '#search-result';

/**
 * Base URL for the AJAX calls, replaces index.html
 * (or whatever the original URL ends in)
 */
//var baseurl = currentUrl.clone();
var cUrl_ = currentUrl.clone();
cUrl_.query("");
cUrl_.filename("fcs");
var baseurl = cUrl_.toString();

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
            resource: {label:"Werk", value:"", widget:"selectone", static_source: baseurl + "fcs?version=1.2&operation=scan&scanClause=fcs.resource&x-format=json"},            
        submit_resource: {value:"filter", label:"", widget:"submit" }},
           onValueChanged: function(v) {console.log(this, v)}
            });

     $('#input-submit_resource').live("click", filter_resource)
   */  
     
    // Create tabs for the detail view, xmlViewer may need refresh.
    // tab-view currently deactivated
    /* detail_tabs = $('#tabs').tabs({
        show : function(event, ui) {
            load_detail_data(ui.index);
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
    
    
    // refresh persistent link
    $("a#persistent-link-invoke").live('hover', persistentLink);
    $("a#persistent-link-invoke").live('click', persistentLink);
    
    
    // handle link to toggle info
    $("#navigation a.link-info").live('click', toggle_info);    
    $("#navigation .data-view.metadata, #navigation .data-view.image, #navigation .data-view.cite").hide();
    
    // handle link to explain
    $("#navigation a.link-explain").live('click', load_explain);
    $("#navigation .indexInfo a").live('click', load_scan);
    
    // handle loading to main (scan -> search) (.content - to distinguish from .header .prev-next) 
    $("#navigation .load-main .content a").live('click', load_main);
    // paging in scan
    //$("#navigation .scan .prev-next a").live('click', load_scan);
    $("#navigation .scan a.internal").live('click', load_scan)
    
    //
    $("#navigation a.toc").live('click', load_toc);
    
    $("#navigation .toc a").live('click', handle_toc);
    $("#navigation .scan-index-fcs-toc a").live('click', handle_toc);
    
    $("#navigation a.index").live('click', load_scan);
        
    $("#navigation .load-detail a").live('click', load_detail);


    // register filter
    $("#navigation form").live('submit', filter_default_nav_results);
  
    $("#query-input form").live('submit', query);

    // Dialog Link
    $('#dialog_link').click(function() {
        $('#dialog').dialog('open');
        return false;
    });

    $('.result-header a').live("click", load_main);
    $('.result-body a').live("click", load_detail);
    // navigation links target:#detail itself
    $('#detail .navigation a').live("click", load_detail);

    // links inside the detail-view (person-links) target:#context-detail
    $('#detail .data-view.full a').live("click", load_context_details);

    $('#context-detail a').live("click", load_in_context_details);

    // customize icons (from generic 
    customizeIcons();

}

//register this on document ready
$(minimal_template_ui_setup); 

/** checks the request params 
   and post-loads detail-view if detail.query is filled
*/
function processParams () {
    
        cr_config.params = $.extend(cr_config.params, currentUrl.query(true));
        console.log("cr_config.params:")
        console.log(cr_config.params);
        
        if (cr_config.params["detail.query"]) {
            
            var detail_params = $.extend({},cr_config.params);
            detail_params["query"] = cr_config.params["detail.query"]; 
            detail_params["x-dataview"] = 'title,full'; //,xmlescaped
           var detail_request = baseurl + '?' + $.param(detail_params);
           console.log("post-loading DETAIL: " + detail_request);
            load_detail_data(detail_request);
         }
         
         if (cr_config.params["debug"]) {
            $(".debug").show();
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
console.log("persistent-link:" + link);
    // FIXME: want to just set the location, but not reload page
    // window.location.href=link;
    $("#persistent-link").val(link);
    return link;    
}

/** generic function for ajax-loading snippets into page
just a wrapper around jQuery.load() to ensure consistent functionality 
*/
function load_(targetContainer, targetRequest, callback) {

console.log("load_: " + targetRequest );
     loading(targetContainer, 'start');
     
     //targetContainer.html('');
     targetContainer.load(targetRequest, function( response, status, xhr ) {
            loading(targetContainer, 'stop');
            //targetContainer.removeClass("cmd_get");
            if (status=='error') { 
            
            targetContainer.append("<p class='error'>Sorry, there was an error!</p>" +
            "<p>calling <a href='" + targetRequest + "' >" + targetRequest + "</a></p>"); }
                else  { if (typeof callback == 'function')  { callback();} }
     });        
     
}

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
                //$(target).prepend("<span class='ui-icon ui-icon-close cmd_close' />");
                $(target).prepend("<span class='fa fa-close' />");
                close_button = $(target).find(".cmd_close");
                close_button.click(function() { target.find('.explain').toggle(); target.find('.scan').toggle(); });                
            }        
        );        
      }
}

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
       load_(target, targetRequest, function() {               
                //$(target).prepend("<span class='ui-icon ui-icon-close cmd_close' />");
                $(target).prepend("<span class='fa fa-close cmd_close' />");                
                close_button = $(target).find(".cmd_close");
                close_button.click(function() { target.toggle(); });
                customizeIcons();

                target.find("ul").treeview({
        			collapsed: true,
        			animated: "medium"
        		});
            }        
       ); 
/*     target.load(targetRequest, function() {target.toggleClass("cmd_get");});        */
     
}


function load_toc(event) {
    event.preventDefault();
    var parentRecord = $(this).parents('div.record');
    var target = parentRecord.find('.context-detail');
    if (target.find('.scan-index-fcs-toc').length > 0)  
       { target.toggle(); }
      else { 
            //var targetRequest = $(this).attr('href') + " ul.resource";
            var targetRequest = $(this).attr('href');
            // a hack to have the correct element as target even though we are stripping the envelope of the response and just retrieve the inner list (ul.resource)    
            //target_wrapper.append("<div class='scan-index-fcs-toc' />");
            //var target = target_wrapper.find('.scan-index-fcs-toc');
    //var detailFragment = targetRequest + ' ' + search_container_selector;
        /*target.append("<div class='scan load-main' />");
        wrap = target.find(".scan");*/        
        load_(target, targetRequest, function() {               
                $(target).prepend("<span class='ui-icon ui-icon-close cmd_close' />");
                close_button = $(target).find(".cmd_close");
                     close_button.click(function() { target.toggle(); });
                     
                 // a hack to remove the top element (Work itself)    
               var ul_resource = target.find('ul.resource');
                target.find('.scan-index-fcs-toc').html('').append(ul_resource);
            }        
        );        
      }
}

/** run query via ajax 
  * read query-param from the form 
 */
function query(event) {
    event.preventDefault();
    var target = $('#main #results');
    
    var query = $(event.target).find("input[name='query']").val();
    var params = {"query":query, "operation": 'searchRetrieve', "x-dataview": 'title,kwic,facets', "x-format":"html" } ; //,xmlescaped
    targetRequest = baseurl + '?' + $.param(params);
    cr_config.params["query"] = query;
    // persistentLink();    
    load_(target, targetRequest + ' .result-header,.result-body', customizeIcons );
}


/**
 * AJAX loading for the main container (middle column) = search
 * expects a searchRetrieve request URL in $this.href  
 * @param {Object} event
 */
function load_main(event) {
    event.preventDefault();
    var target = $('#main #results');
    var targetRequest = baseurl + $(this).attr('href');
    //var detailFragment = targetRequest + ' ' + search_container_selector;
    
    if (targetRequest == undefined) return;
    var parsedUrl = new URI(targetRequest);
    params = parsedUrl.query(true);
    
    cr_config.params["query"] = params["query"];
    
    // set the query into the query input field
    $('#query').val(params["query"]);
    
    // Recreate the x-dataview param from scratch    
    params["x-dataview"] = cr_config.main.dataview; //,xmlescaped
    targetRequest = baseurl + '?' + $.param(params);
    
    load_(target,targetRequest  + ' .result-header,.result-body', customizeIcons );
}

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
        load_detail_data(targetRequest)
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
        var targetRequest = baseurl + '?' + $(this).serialize();
        // + ' #' + loadParentID;
        console.log(targetRequest);
        //loadParent.load(targetRequest,customizeIcons);
        target = loadParent;
        loadParent.load(targetRequest,
            function() {
                $(target).prepend("<span class='ui-icon ui-icon-close cmd_close' />");
                close_button = $(target).find(".cmd_close");
                close_button.click(function() { target.toggle(); });
                customizeIcons();

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
 * On an a-elemet click load details. Use the href attribute but request navigation statements
 * to be generated
 */
function load_detail(event) {
    event.preventDefault();
    targetRequest = baseurl + $(this).attr('href');
    //load_detail_data(detail_tabs.tabs('option', 'selected'));
    load_detail_data(targetRequest);
}

/**
 * Fetches data from fcs but only uses the specified parts (classes)
 * See {@link http://api.jquery.com/load/#loading-page-fragments}
 
 * reverted back the per tab-loading functionality (as introduced in mecmua_template, 
 * because it leads to additional requests (every time a tab is called)
 * moreover, tabs are optional (or completely disabled) 
 */
function load_detail_data(targetRequest) {
    var detail = $('#detail');

    if (targetRequest == undefined) return;
    var parsedUrl = new URI(targetRequest);
    params = parsedUrl.query(true);
    // Recreate the x-dataview param from scratch
    
    params["x-dataview"] = cr_config.detail.dataview; //,xmlescaped
    targetRequest = baseurl + '?' + $.param(params);
    cr_config.params["detail.query"]=params["query"];
    // persistentLink();
    // The detail view is hidden at first
    detail.show();
    var classes_interested_in = " .title, .data-view";
    var detailFragment = targetRequest + classes_interested_in;
    
    loading(detail.find('.detail-header'),"start");
    // clear the current-detail:
//    detail.find(".detail-content").html('');
  //  detail.find('.detail-header').html('').toggleClass("cmd_get cmd");
    
    //console.log("load_detail:" + detailFragment);
    //console.log("load_detail:" + baseurl);
    detail.find(".detail-content").load(detailFragment, function () {
                        loading(detail.find('.detail-header'), "stop");
    //                    detail.find('.detail-header').toggleClass("cmd_get cmd");
                        
                        // activate zoom functionality on the images, expects: jquery.elevateZoom-3.0.8.min.js
                        // deactivated for now
                        //detail.find(".data-view.facs img").each( function() {$(this).attr("data-zoom-image",$(this).attr("src")); });
                        //detail.find(".data-view.facs img").elevateZoom({ zoomType : "lens", lensShape : "round", lensSize : 200 });
                         
                        // move Title and navigation above the content
                        $('.detail-header').html($(this).find(".data-view.navigation")).append($(this).find(".title"));
                        // move cite below the detail content
                        detail.find('.context-detail').html($(this).find(".data-view.cite"));
                        customizeIcons(); 
                        /*
                        var detail_anno = $(this).html();
                        $('#tabs-1').html(detail_anno);
                        // get rid-off the highlighted stuff                        
                        $('#tabs-1').find("span").removeClass("persName bibl placeName");
                        // get rid-off the links
                        $('#tabs-1').find('a').replaceWith(function(){  return $(this).contents();});
                        */
                        
                      });
}

/**
 * Extracts the header of the AJAX request and puts it on top of the detail tabs
 */
function extract_header(){
        $('#detail').find('.navi').toggleClass("cmd_get");
        // move title above the tabbed box
        $('.detail-header').html($(this).find(".title"));
        // move navigation above tabbed box
        $('.detail-header .title').after($(this).find(".navigation"));
        // debug; if released solve differently
        params["x-format"] = "xml";
        $('.detail-header .navigation').after('<a class="navigation" href="' + baseurl + '?' + $.param(params) + '">&nbsp;FCS/XML&nbsp;</a>');
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


function load_context_details(event) {
    var detail = $('#detail');
    event.preventDefault();
    $('#detail a').removeClass("hilight");
    $(this).addClass("hilight");
    var target = $('#context-detail');
    detail.find('.navi').toggleClass("cmd_get");
    targetRequest = baseurl + $(this).attr('href');
    var detailFragment = targetRequest + " .title, .person";

    $(target).load(detailFragment);
}

function load_in_context_details(event) {
    event.preventDefault();
    var target = $(search_container_selector);
    targetRequest = $(this).attr('href');
    var detailFragment = targetRequest + ' ' + search_container_selector;
    $(target).load(detailFragment);
}

function customizeIcons () {
    $('.cmd_prev, .cmd_next, .navigation .prev, .navigation .next').html(""); 
    $('.cmd_prev, .navigation .prev').addClass("fa fa-chevron-left").removeClass("cmd prev cmd_prev");
    $('.cmd_next, .navigation .next').addClass("fa fa-chevron-right").removeClass("cmd next cmd_next");;
}

function loading(targetContainer, startstop) {

if (startstop=='start') {
    targetContainer.prepend("<span class='loading' >loading...</span>");
    var  loading = targetContainer.find(".loading"); 
    loading.modernBlink({duration: '1500'});
   } else {
      var  loading = targetContainer.find(".loading");
      loading.remove();
 }  
}