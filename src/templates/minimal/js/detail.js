
$(function(){

var search_container_selector = '#search-result';

//// loading the data 
		
// static search-result
    //var result_href = "http://localhost:8681/exist/cr/?x-format=htmldetail&x-context=clarin.at%3Aicltt%3Acr%3Astb&query=montirt&startRecord=1&maximumRecords=10&x-dataview=full&x-dataview=kwic";
var baseurl = "fcs";
// load detail
    $('.result-body a').live("click", loadDetail);
    
    function loadDetail(event) {
         event.preventDefault();
         targetRequest = baseurl + $(this).attr('href');
/*         + "&x-dataview=navigation";*/
         loadDetailData(targetRequest);
        /*var detail = $('#detail');
            detail.show();
            detail.load(targetRequest + " .title, .data-view");*/
    }
    
    function loadDetailData(targetRequest) {         
         var detail = $('#detail');
         detail.show();         
         var detailFragment = targetRequest + " .title, .data-view, .navigation";
         detail.find('.navi').toggleClass("cmd_get");
         // console.log("loaddetail: " + detailFragment);
         $('#tabs-1').load(detailFragment, function () {
                        
                        $('#detail').find('.navi').toggleClass("cmd_get");
                        // move Title and navigation above the tabs
                        $('.detail-header').html($(this).find(".title, .navigation"));
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
    $('#detail .navigation a').live("click", loadDetail);
    
      
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
				
});   