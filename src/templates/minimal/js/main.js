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


var currentUrl = $.url();


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
var baseurl = currentUrl.attr("base") + currentUrl.attr("directory") + "fcs";

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

    // handle loading to main (scan -> search)
    $("#navigation .load-main a").live('click', load_main);
    
    // handle link to toggle info
    $("#navigation a.link-info").live('click', toggle_info);
    $("#navigation .data-view.metadata, #navigation .data-view.image").hide();
    
    // handle link to explain
    $("#navigation a.link-explain").live('click', load_explain);
    $("#navigation .indexInfo a").live('click', load_scan);
    
    //
    $("#navigation a.toc").live('click', load_toc);
    
    $("#navigation .toc a").live('click', handle_toc);
    $("#navigation .scan-index-fcs-toc a").live('click', handle_toc);
    
    $("#navigation .load-detail a").live('click', load_detail);
    
    // register filter
    $("#navigation form").live('submit', filter_default_nav_results);
    
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



function load_explain(event) {
    event.preventDefault();
    var target = $(this).parents('.links');
    
    if (target.find('.explain').length > 0)  
       { target.find('.explain').toggle(); }
      else { 
        var targetRequest = $(this).attr('href');
    //var detailFragment = targetRequest + ' ' + search_container_selector;
        
        $.get(targetRequest,function(data) {
                target.append(data);
                target.append("<div class='scan load-main' />");
                $(target).prepend("<span class='ui-icon ui-icon-close cmd_close' />");
                close_button = $(target).find(".cmd_close");
                close_button.click(function() { target.find('.explain').toggle(); });                
            }        
        );        
      }
}

function load_scan(event) {
    event.preventDefault();
    var target = $(this).parents('.record').find(".scan");
    
     var targetRequest = $(this).attr('href');
    //var detailFragment = targetRequest + ' ' + search_container_selector;

        console.log("targetRequest");
        console.log(target);
     target.load(targetRequest);        
     
}



function load_toc(event) {
    event.preventDefault();
    var parentRecord = $(this).parents('div.record');
    var target = parentRecord.find('.context-detail');
    if (target.find('.scan-index-fcs-toc').length > 0)  
       { target.toggle(); }
      else { 
            var targetRequest = $(this).attr('href');
    //var detailFragment = targetRequest + ' ' + search_container_selector;
        
        $(target).load(targetRequest,function() {
                $(target).prepend("<span class='ui-icon ui-icon-close cmd_close' />");
                close_button = $(target).find(".cmd_close");
                close_button.click(function() { target.toggle(); });                
            }        
        );        
      }
}

/**
 * AJAX loading for the main container (middle column) 
 * @param {Object} event
 */
function load_main(event) {
    event.preventDefault();
    var target = $('#main #results');
    var targetRequest = baseurl + $(this).attr('href');
    //var detailFragment = targetRequest + ' ' + search_container_selector;
    
    if (targetRequest == undefined) return;
    var parsedUrl = $.url(targetRequest);
    params = parsedUrl.param();
    // Recreate the x-dataview param from scratch
    
    params["x-dataview"] = 'title,kwic,facets'; //,xmlescaped
    targetRequest = baseurl + '?' + $.param(params);
    
        
    $(target).load(targetRequest);
}

function toggle_info(event) {
    event.preventDefault();
    console.log("Info:");
    var data_view = $(this).parents(".record").find('.data-view.metadata, .data-view.image');
    data_view.toggle();
}


/** handles interactions with the full toc
resource level toggles the nested levels, 
click in nested levels loads in detail
*/
function handle_toc(event) {
    event.preventDefault();
    var parent_span = $(this).parent('span')
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
        loadParent.load(targetRequest);
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
    var parsedUrl = $.url(targetRequest);
    params = parsedUrl.param();
    // Recreate the x-dataview param from scratch
    
    params["x-dataview"] = cr_config.dataview; //,xmlescaped
    targetRequest = baseurl + '?' + $.param(params);
    
    // The detail view is hidden at first
    detail.show();
    var classes_interested_in = " .title, .data-view, .navigation";
    var detailFragment = targetRequest + classes_interested_in;
    
    // clear the current-detail:
    detail.find(".detail-content").html('');
    detail.find('.detail-header').html('').toggleClass("cmd_get cmd");
    
    console.log("load_detail:" + detailFragment);
    detail.find(".detail-content").load(detailFragment, function () {
                        
                        detail.find('.detail-header').toggleClass("cmd_get cmd");
                        // move Title and navigation above the tabs
                        $('.detail-header').html($(this).find(".navigation")).append($(this).find(".title"));
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
    /*switch (selected) {
    case 0:
    $('#tabs-1').load(detailFragment, function() {
        extract_header.call(this);
        create_unannotated_text_in.call(this, $('#tabs-1'));
    });
    break;
    case 1:
    $('#tabs-2').load(detailFragment, extract_header);
    break;
    case 2:
    $('#tabs-3').load(detailFragment, extract_header);
    break;
    case 3:
    $('#tabs-4').load(detailFragment, function() {
        extract_header.call(this);
        // Create a CodeMirror viewer using the provided textarea.
        xmlViewer = CodeMirror.fromTextArea($('#tabs-4 textarea').get()[0], {
            mode : "xml",
            readOnly : true
        });
    });
    break;
    }*/
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
    $('.cmd_prev, .navigation .prev').addClass("ui-icon ui-icon-circle-triangle-w").removeClass("cmd prev cmd_prev");
    $('.cmd_next, .navigation .next').addClass("ui-icon ui-icon-circle-triangle-e").removeClass("cmd next cmd_next");;
}