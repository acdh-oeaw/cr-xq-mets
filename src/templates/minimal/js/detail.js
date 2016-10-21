
!function($, MinimalTemplateMain){

var m = {},
    search_container_selector = MinimalTemplateMain.getSearchContainerSelector(),
    baseurl = MinimalTemplateMain.getBaseURL(),
    cr_config = MinimalTemplateMain.getCrConfig();
    
//export

this.MinimalTemplateDetail = m;

//// loading the data 
		
// static search-result
    //var result_href = "http://localhost:8681/exist/cr/?x-format=htmldetail&x-context=clarin.at%3Aicltt%3Acr%3Astb&query=montirt&startRecord=1&maximumRecords=10&x-dataview=full&x-dataview=kwic";


function minimal_template_ui_setup() {
// load detail
    $('.result-body a').live("click", load_detail);
        
    $("#navigation .load-detail a").live('click', load_detail);
    $('.result-body a').live("click", load_detail);
    // navigation links target:#detail itself
    $('#detail .navigation a').live("click", load_detail);	   
                      
// links inside the detail-view (person-links) target:#context-detail    
    $('#detail .data-view.full a').live("click", function (event) {
        var detail = $('#detail');
        event.preventDefault();
         $('#detail a').removeClass("hilight");
         $(this).addClass("hilight");
         var target = $('#context-detail');
         detail.find('.navi').toggleClass("cmd_get");
         targetRequest = baseurl + $(this).attr('href');
         var detailFragment = targetRequest + " .title,.person";
         
         $(target).load(detailFragment);         
      });

// navigation links target:#detail itself
    $('#detail .navigation a').live("click", load_detail);
    
      
      $('#context-detail a').live("click", function (event) {         
         event.preventDefault();
         var target = $(search_container_selector);
         targetRequest = $(this).attr('href');
         var detailFragment = targetRequest + ' ' + search_container_selector;
         
         $(target).load(detailFragment);         
      });
        
// register filter
        $("#left form").live('submit', function(event) {           
           console.log ( $(this));
           var loadParent = $(this).parents('div.module');           
           var  loadParentID = loadParent.attr('id');
           // special hack, to only apply on index-scans
           console.log(loadParent);
           if (loadParentID != 'fcs-query') {
            event.preventDefault();
            var targetRequest = baseurl + '?'+$(this).serialize(); // + ' #' + loadParentID;             
            console.log(targetRequest);
            loadParent.load(targetRequest);            
           }
         } );

// register to search
    $("#left a").live('click', function(event) {
         event.preventDefault();
         var target = $('#main');
         targetRequest = $(this).attr('href');
         var detailFragment = targetRequest + ' ' + search_container_selector;         
         $(target).load(detailFragment);
         
    });    
}

$(minimal_template_ui_setup);
    
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

MinimalTemplateMain.doLoadDetail = load_detail;

m.onDetailDataLoaded = function(){};

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
    
    MinimalTemplateMain.loading(detail.find('.detail-header'),"start");
    // clear the current-detail:
//    detail.find(".detail-content").html('');
  //  detail.find('.detail-header').html('').toggleClass("cmd_get cmd");
    
    //console.log("load_detail:" + detailFragment);
    //console.log("load_detail:" + baseurl);
    detail.find(".detail-content").load(detailFragment, function () {
                        MinimalTemplateMain.loading(detail.find('.detail-header'), "stop");
    //                    detail.find('.detail-header').toggleClass("cmd_get cmd");
                        
                        // activate zoom functionality on the images, expects: jquery.elevateZoom-3.0.8.min.js
                        // deactivated for now
                        //detail.find(".data-view.facs img").each( function() {$(this).attr("data-zoom-image",$(this).attr("src")); });
                        //detail.find(".data-view.facs img").elevateZoom({ zoomType : "lens", lensShape : "round", lensSize : 200 });
                         
                        // move Title and navigation above the content
                        $('.detail-header').html($(this).find(".data-view.navigation")).append($(this).find(".title"));
                        // move cite below the detail content
                        detail.find('.context-detail').html($(this).find(".data-view.cite"));
                        MinimalTemplateMain.customizeIcons(); 
                        /*
                        var detail_anno = $(this).html();
                        $('#tabs-1').html(detail_anno);
                        // get rid-off the highlighted stuff                        
                        $('#tabs-1').find("span").removeClass("persName bibl placeName");
                        // get rid-off the links
                        $('#tabs-1').find('a').replaceWith(function(){  return $(this).contents();});
                        */
                        m.onDetailDataLoaded();                        
                      });
}

MinimalTemplateMain.doLoadDetailData = load_detail_data;

				// Accordion
				$("#accordion").accordion({ header: "h3", autoHeight: false, active: 0  });
	
				// Tabs
				$('#tabs').tabs();
	

				// Dialog			
				$('#dialog').dialog({
					autoOpen: false,
					width: 600,
					buttons: {
						"Ok": function() { 
							$(this).dialog("close"); 
						}, 
						"Cancel": function() { 
							$(this).dialog("close"); 
						} 
					}
				});
				
				// Dialog Link
				$('#dialog_link').click(function(){
					$('#dialog').dialog('open');
					return false;
				});

				// Datepicker
				$('#datepicker').datepicker({
					inline: true,
					firstDay: 1,
					changeYear: true,
					dateFormat: 'yy-mm-dd',
					yearRange: '1875:1931',
					minDate:  new Date(1875, 10, 23),
					maxDate: new Date(1931, 10, 19),
					defaultDate: new Date(1900, 1, 1),
					 onSelect: function(dateText, inst) {
					       console.log(dateText);
					   // http://localhost:8681/exist/rest/db/sade/projects/stb/stb.xql?operation=searchRetrieve&query=resourcefragment-pid=%221903-01-20%22&x-dataview=full&x-context=clarin.at:icltt:cr:stb&x-format=html           
					       targetRequest = baseurl + "?operation=searchRetrieve&x-dataview=full&x-dataview=navigation&x-context=clarin.at:icltt:cr:stb&x-format=html&query=resourcefragment-pid=%22" + dateText + "%22";
					       loadDetailData(targetRequest);					       
					       }
				});
				
}(jQuery, MinimalTemplateMain);   