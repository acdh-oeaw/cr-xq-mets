!function module($, js_url) {
    // url is: "A simple, lightweight url parser for JavaScript (~1.7 Kb minified, ~0.7Kb gzipped)."
    // Problem is: The Documentation was also sacrificed to lightweight. Demo/Doc: https://websanova.com/plugins/url
    //             It favors magic string commands over function/method names.
    // Replacement for readability: URI.js: has docs, favors function/method names over magic string commands.
    var m = {};
    m.fcsEndpoint = {
        url: "fcs",
        version: "1.2"
    }; 
    m.searchRetrieve = {
        operation: "searchRetrieve",
        format: "html"
    }      
          
//    m.dv = {};

function msg( head, content ) {
    return '<div class="col-lg-5 col-lg-offset-3"><div class="panel panel-default"><div class="panel-heading">' + head + '</div><div class="panel-body">' + content + '</div></div>'};


$(document).ready(function(){
    m.queryForm = $('#queryForm'),
    m.resultsContainer = $('#resultsContainer'),
    m.detailContainer = $('#detailContainer'),
    m.resultsNavigation = $('#resultsNavigation'),
    m.sidebar = $("#sidebar");
    
    m.detailContainer.parents(".label").hide();
    
    m.queryForm.submit(function(e){
        e.preventDefault();
        m.queryForm.find("input[name=startRecord]").val(1);
        var form = $(this),
            action = form[0].action,
            query = m.queryForm.find("input[name=query]").val();
        if ((query.indexOf(' ') > -1) && 
            (query.indexOf('.') > -1) &&
            (query.indexOf('"') == -1)) {
            m.queryForm.find("input[name=query]").val('"'+query+'"');
        }
        var params = $(form).serialize(),
            url = action + "?" + params;
        m.queryForm.find("input[name=query]").val(query);
        return populateResultsContainer(url)
    });
    
    m.detailContainer.on("click", ".data-view.navigation a", function(e){
        e.preventDefault();
        var hrefParamsObject = js_url('?', this.href);
        var record = $(this).parents(".data-view");
        
        var context = record.attr("data-x-context"),
            resource = record.attr("data-resource-pid"),
            query = hrefParamsObject['query'];
        
        return loadDetail(this.href, context, resource, query)
    });
    
    m.resultsNavigation.on("click", "a", function(e){
        e.preventDefault();
        var url = this.href;
        populateResultsContainer(url);
    });
    
    m.resultsContainer.on("click", ".searchresults a.value-caller, .searchresults a.internal", function(e){
        e.preventDefault();
        m.detailContainer.parents(".panel").fadeIn();
        var hrefParamsObject = js_url('?', this.href);
        var record = $(this).parents(".record-top");
        
        var context = record.attr("data-x-context"),
            resource = record.attr("data-resource-pid"),
            resourceFragment = record.attr("data-resourcefragment-pid"),
            query = "fcs.rf='" + resourceFragment + "'";
        if (context === undefined) context = hrefParamsObject['x-context'];
        if (resourceFragment === undefined) query = hrefParamsObject['query'];
        
        return loadDetail(this.href, context, resource, query)
    });
    
    m.sidebar.on("click", ".scan-index-fcs-toc .value-caller", function(e){
        e.preventDefault();
        m.detailContainer.parents(".panel").fadeIn();
        var hrefParamsObject = js_url('?', this.href);
        console.log(hrefParamsObject);
        var context = hrefParamsObject['x-context'],
            resource = undefined,
            query = hrefParamsObject['query']//.replace(/(^fcs\.rf=")|("$)/g, "")
        // console.log(context);
        // console.log(resourceFragment);
        return loadDetail(this.href, context, resource, query)
    });
    
    $(".context-detail").on("click", ".context-detail-close a", function(e){
        $(this).parents(".context-detail").empty()
    });
    
    m.sidebar.on("click", "a.toc", function(e){
        e.preventDefault();
        var url = this.href.replace(/^http:|https:/g), // this is a hack to not break things when reverse-proxying with a https address.
            container = $(this).parents(".record.resource").find(".context-detail");
        populateTOC(url, container);
    });
    
    $("#navigation a.link-info").on('click', function (e){
        toggle_navigation_data_views(this, event, 'info');
    });
});
    
    function fetch(conf, callback){
        $.ajax(m.fcsEndpoint.url, {
            data: conf,
            method: "GET",
            success: function(data, textStatus, jqXHR){
//                console.log(this.url);
//                console.log(data);
                callback(conf["x-dataview"], data);
            },
            error: function(e) {
                console.log(e);
            }
        })
    };

    function appenddv(dv, data){
        var result = $(data).find('.data-view.' + dv);
        var dvContainer = m.detailContainer.find('.dataview[data-dataview=' + dv + ']');
        console.log("dataview "+dv);
//        console.log(dvContainer);
//        console.log(result);
        dvContainer.parents(".panel").fadeIn();
        dvContainer.empty().html(result);
    };
    
    function loadDetail(ref, context, resource, query) {
        var hrefParamsObject = js_url('?', ref);
        
        for (i = 0; i < m.detailContainer.find(".dataview").length; i++){
            var dv = $(m.detailContainer.find(".dataview")[i]).attr("data-dataview"),
                conf = {
                    'x-context' : hrefParamsObject["x-context"],
                    //'resource' : resource, 
                    // 'resourceFragment' : resourceFragment,
                    'x-highlight' : hrefParamsObject["x-highlight"],
                    version : m.fcsEndpoint.version,
                    operation : m.searchRetrieve.operation,
                    'x-format' : m.searchRetrieve.format,
                    'x-dataview' : dv,
                    query : query//"fcs.rf='" + resourceFragment + "'"
                }
            fetch(conf, appenddv); 
        }
    };

    function populateResultsContainer (url){
        $.ajax(url, {
            method: "GET",
            
            beforeSend : function(){
                m.resultsContainer.parents(".panel").fadeIn();
                m.resultsContainer.html('<div class="col-lg-12"><i class="fa fa-spinner fa-spin"></i></div>');
                /*empty all data views*/
                m.detailContainer.find('.dataview').empty();
            },
            
            success: gotSearchResults,
            
            error: function(data, textStatus, jqXHR){
                var data = '<h4>An error occured.</h4><p>Status: ' + data.status + '</p><pre>' + data.responseText + '</pre>';
                return m.resultsContainer.html(data)  
            } 
        })
    };

    function gotSearchResults(data, textStatus, jqXHR){
        var numberOfRecords = parseInt($(data).find('.result-header').attr('data-numberOfRecords'));
        data = numberOfRecords === 0 ? '<p>No Records found.</p>' : data;

        var ajaxCallContext = this; // Beware: this in JS can be anything, only as a $ajax succes callback this is true.
                                    // Also note that this has this.url which is used first when url() is called.
        var paramsObject = js_url('?', ajaxCallContext.url);
        var maxRecords = parseInt(paramsObject['maximumRecords']);
        var startRecord = parseInt(paramsObject['startRecord']) > 1 ? parseInt(paramsObject['startRecord']) : 1;
        var startRecordField = m.queryForm.find('input[name=startRecord]');
        startRecordField.length === 0 ? m.queryForm.append("<input name='startRecord' type='hidden' value='1'/>") : undefined ;
        var pagination =  '';
        var numberOfPages = Math.round(numberOfRecords / maxRecords);
        console.log(numberOfPages);
        for (i = 0; i < numberOfPages; i++){
            var pageNum = i + 1
                minRecOnPage = i * maxRecords + 1,
                maxRecOnPage = minRecOnPage + maxRecords;
            var active = (startRecord >= minRecOnPage) && ((startRecord + maxRecords) <= maxRecOnPage);
            console.log("pageNum "+pageNum+" active "+active+" minRecOnPage "+minRecOnPage+" maxRecOnPage "+maxRecOnPage);
            startRecordField.val(minRecOnPage);
            var url = m.queryForm[0].action + "?" + m.queryForm.serialize(),
            activeClass = active ? ' class="active" ' : '';
            pagination = pagination + '\n<li' + activeClass + '><a href="' + url + '">' + pageNum + '</a></li>'
        } 
        m.resultsContainer.html(data);
        m.resultsNavigation.find('.pagination').empty().html(pagination);
    }
    
    function populateTOC (url, target){
        $.ajax(url, {
            method: "GET",
            
            beforeSend : function(){
                target.empty();
            },
            
            success: function(data, textStatus, jqXHR){
                target.html('<div class="context-detail-close"><a href="#"><i class="fa fa-times"></i></a></div>' + data);
            },
            
            error : function(data, textStatus, jqXHR){
                var data = '<h4>An error occured.</h4><p>Status: ' + data.status + '</p><pre>' + data.responseText + '</pre>';
                return target.html(data)  
            } 
        })
    };
        
    function toggle_navigation_data_views(context,event, type) {
        event.preventDefault();
        var data_view = {};
        data_view['info'] = $(context).parents(".record").find('.data-view.metadata, .data-view.image, .data-view.cite');
        
        // first check for current status
        var hidden = data_view[type].is(":hidden");
        // then hide all
        $(context).parents(".record").find('.data-view').hide();
        // then open the requested view it was closed
        if (hidden) data_view[type].show();
    };

}(jQuery, url);