/** special query-input widgets for CQL-input
  * searchclause-set and cql-parsing input

/** generate cql-search clause */ 
function genCQLInput(key, param_settings) {
    
    // main input for the string-version of the search-clause (probably hidden)
        var new_input = $("<input />");
            new_input.attr("id",key);
            new_input.attr("name",key);
            if (param_settings.size) $(new_input).attr("size",param_settings.size);
        
        
        var query_object = new Query(key, param_settings);
        var new_cql_widget = $("<div id='" + key + "-widget' ></div>");
        
        // link the widget and the query object 
        //new_cql_widget.data("query_object") = query_object;
        new_cql_widget.query_object = query_object;
        console.log("new_cql_widget.query_object:");
        console.log(new_cql_widget.query_object);
        query_object.widget = new_cql_widget;
        query_object.updatedCQL = function() {
            new_input.val(query_object.cql);
        };
        // add first SC 
        query_object.addSearchClause(null,"");
        
        return [new_input, new_cql_widget];
}


/** constructor for a Query-object - bascally a set of search clauses (previously: Searchclauseset */
function Query(key, param_settings) {
    this.key = key;
    this.cql_config = param_settings.cql_config;
    // actual query string in CQL-syntax
    this.cql = param_settings.cql;  
    
    // the parent widget holding the search-clauses;
    this.widget ={};
    
    this.searchclauses = [];
    this.and_divs = [];

    /** event handler for change of CQL */
    this.updatedCQL = function() {
        console.log(this.cql);
    }

    /** add SC relative to an existing one */    
    this.addSearchClause = function(source_clause, rel) {
    
        var add_and = 0;
        // compute the position-index in the search-clauses (and/or-matrix)
        if (source_clause == null || rel=='and') {
        // if no related clause, put at the end
            and_pos = this.searchclauses.length;
            or_pos = 0;
            add_and = 1;
         } else {
            and_pos = source_clause.and_pos;
            or_pos = this.searchclauses[and_pos].length;
         }
        
        console.log (and_pos + '-' + or_pos);
        
        if (add_and==1) {
            this.searchclauses[and_pos] = [];
            var and_div = $("<div class='and_level'>");
            this.widget.append(and_div);
            this.and_divs[and_pos] = and_div; 
        } 
        
        sc = new SearchClause(this, and_pos, or_pos);
        this.searchclauses[and_pos][or_pos] = sc;
        
        if (this.widget) {
            this.and_divs[and_pos].append(sc.widget);
        } 
    }
    
    /** add SC relative to an existing one */    
    this.removeSearchClause = function(source_clause) {
    
        and_pos = source_clause.and_pos;
        or_pos = source_clause.or_pos;
            
        // don't remove the first SC            
        if (!(and_pos==0 && or_pos==0)) {            
            this.searchclauses[and_pos].splice(or_pos,1);
            // if and-array is empty remove it as well
            if (this.searchclauses[and_pos].length == 0) this.searchclauses.splice(and_pos,1);
            source_clause.widget.remove();
         }
    }
    
    // generate CQL string from search clauses
    this.updateCQL = function(){ 
	   var uncompletequery = false;
	   var cqltext= "";
	   
		for (var i = 0; i < this.searchclauses.length; i++) {
			if ( i>0) cqltext = cqltext + " and ";
			if (this.searchclauses.length> 1) cqltext = cqltext + " ( ";
			for (var j = 0; j < this.searchclauses[i].length; j++) {
				if ( j>0) cqltext = cqltext + " or ";
				if (this.searchclauses[i].length > 1) cqltext = cqltext + " ( ";
				ptext = this.searchclauses[i][j].rendered();
				if (ptext.length == 0){
					uncompletequery = true;
				}
				cqltext = cqltext + ptext;
				if (this.searchclauses[i].length > 1) cqltext = cqltext + " ) ";
			}
			if (this.searchclauses.length> 1) cqltext = cqltext + " ) ";
		}
			
		if ((i == 1 && j == 1) && (cqltext.substring (0,6) == '* any ')) {
			cqltext  = cqltext.replace('* any ','');
		}
		if (uncompletequery){
			cqltext = "";
		}
		console.log(cqltext);
		this.cql = cqltext;
		this.updatedCQL(); //call event handler 
        return this.cql;
        
	}
    
}


/** constructor for a SearchClause object */
function SearchClause(query_object, and_pos, or_pos) {
      this.and_pos = and_pos;
      this.or_pos = or_pos;
      this.query_object = query_object;
      this.index = ""
      this.relation = "=";
      this.value = "";
      this.key = query_object.key + '-' + and_pos + '-' + or_pos;

    //make cql_config static to make it accessible from getValues()
    //cql_config = query_object.cql_config;

    /** generate a widget for this SC */
      this.genCQLSearchClauseWidget = function () {
        
         //console.log("genCQLSearchClauseWidget(query_object)");
         //console.log(this.query_object);
        
        var currentSC = this; 
                
         
        var input_index = $("<input />");
            input_index.attr("id","cql-" + this.key + "-index");
            input_index.attr("name","cql-" + this.key  + "-index")
            input_index.data("sc", this);            
            // update the value in data-object; -> but rather on autocompletechange event
            //input_index.change(
                   // function(){ 
                        //$(this).data("sc").index = $(this).val();  
                        //query_object.updateCQL();
                    //    console.log($(this).data("sc").index + '-' + $(this).val()); 
                // });
            
        var select_relation = $("<select class='rel_input'><option value='='>=</option><option value='>'>></option><option value='<'><</option><option value='any'>any</option><option value='contains'>contains</option><option value='all'>all</option></select>");
            select_relation.change(function(){ 
                    currentSC.relation = $(this).val(); 
                    query_object.updateCQL();
                  } );
                  
        var input_value = $("<input />");
            input_value.attr("id","cql-" + this.key + "-value");
            input_value.attr("name","cql-" + this.key + "-value");
    
           input_value.data("sc", this);            
            // update the value in data-object;
           input_value.change(function(){
                    //alternatively: $(this).data("sc")        
                    currentSC.value = $(this).val(); 
                    query_object.updateCQL();
                  } );
            

        var new_widget = $("<div id='widget-" + this.key + "-sc' class='widget-cql-sc'></div>");
            new_widget.append(input_index)
                      .append(select_relation)
                      .append(input_value);
    
    // setup autocompletes 
        if (this.query_object.cql_config) {
            
            // let the autocomplete-select refresh upon loaded index
            this.query_object.cql_config.onLoaded = function(index) {     input_value.autocomplete( "search");
                   console.log("onloaded-index:" + index)};
          
            var indexes =  this.query_object.cql_config.getIndexes();
          //  console.log(indexes);
            
            // setting source on init did not work ??
             //input_index.autocomplete({source: indexes});
             input_index.autocomplete();
             input_index.autocomplete( "option", "source", indexes );
             input_index.on("autocompletechange", 
                        function(){ 
                            currentSC.index = $(this).val();
                            query_object.updateCQL();
                            console.log("autocompletechange: " + currentSC.value + '-' + $(this).val()); 
                });
        //      console.log(input_index.autocomplete( "option", "source" ));
        
             input_value.data("input_index", input_index);
             input_value.autocomplete({ delay: 500, minLength: 2 });
             input_value.autocomplete( "option", "source", this.getValues );
             
/*             input_value.autocomplete( "option", "source", 'http://corpus4.aac.ac.at/exist/apps/cr-xq-mets/abacus/fcs?x-context=&x-format=json&operation=scan&scanClause=persName=');*/
             input_value.on("autocompletechange", 
                        function(){ 
                            currentSC.value = $(this).val();
                            query_object.updateCQL();
                            console.log("autocompletechange: " + $(this).data("sc").index + '-' + $(this).val()); 
                });
        }
        
       new_widget.append(this.genControls()); 
       return new_widget;
    };


    this.getValues = function(request, response) {
            		
            console.log("request_term:" + request.term);
            console.log(this.element.data("sc"));
            var sc = this.element.data("sc")
            values = sc.query_object.cql_config.getValues(sc.index,request.term, response);
            
				/*
            //console.log(values);
            if (values.status == 'loading') { response( ["loading..."]) }
                else  { response(values) };*/
    };

    this.rendered = function(){ 
	if (this.index.trim().length == 0 || this.value.trim().length == 0){
		return "";
	}
	//if (this.is_category){
	//	return "ISOCAT( " + this.category + ") " + this.relation + " " + this.value;
	//}
	return this.index.trim().replace(" ","_") + " " + this.relation + " " + this.value;
};


    this.genControls = function () {
    
        var div_controls = $("<span class='cmd-wrapper controls' />");
        var cmd_del = $("<span class='ui-icon ui-icon-close cmd_sc_delete' />");
        var cmd_and = $("<span class='ui-icon cmd_add_and' >&amp;</span>");
        var cmd_or = $("<span class='ui-icon cmd_add_or' >OR</span>");
        
        div_controls.append(cmd_del).append(cmd_and).append(cmd_or);
        
        var me = this;
        cmd_del.bind("click", function(event) { me.query_object.removeSearchClause(me);  });
        cmd_and.bind("click", function(event) { me.query_object.addSearchClause(me,"and"); });
        cmd_or.bind("click", function(event) { me.query_object.addSearchClause(me,"or"); });
                      
      return div_controls;
    
	}


this.widget = this.genCQLSearchClauseWidget();


} // end SearchClause

