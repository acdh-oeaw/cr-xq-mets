describe("Virtual-Keyboard tests:", function() {
    beforeEach(function(){
        this.cql_config = new CQLConfig( {"base_url": "fcs" });
    });
    
    afterEach(function(){});
    
    describe("Prerequisites:", function() {
//        xit("should not run ;-)", function() {
//           expect(true).toBeFalsy(); 
//        });
        it("should have access to its URI dependency", function() {
            expect(URI).toBeDefined();
        });
        it("should have access to its jquery.selection dependency", function() {
            expect($.fn.selection).toBeDefined();
        });
        it("should have access to virtual keyboard and that should be in a working condistion", function() {
            expect(VirtualKeyboard).toBeDefined();
            expect(VirtualKeyboard.failed).toBeFalsy();
        });
        it("should loaded as a jQuery plugin", function() {
            expect($.fn.QueryInput).toBeDefined();
        });
    });

    simpleFixtureSetup = function() {
        loadFixtures("query-input.html");
        this.sthToBeReplaced = $("#qi");
        expect(this.sthToBeReplaced).toBeInDOM();
        this.randomId = SpecHelper.generateUUID();
        this.sthToBeReplaced.attr('id', this.randomId);
    };

    randomizeFirstInputId = function() {
        var randomId = SpecHelper.generateUUID();
        $(".virtual-keyboard-input#sth-unique").attr('id', randomId);
        return $(".virtual-keyboard-input#"+randomId);
    };

    addAnotherTestInput = function() {
        appendLoadFixtures("virtual-keyboard-input.html");
        var randomId = SpecHelper.generateUUID();
        $(".virtual-keyboard-input#sth-unique").attr('id', randomId);
        return $(".virtual-keyboard-input#"+randomId);
    };

    describe("Replacing dummy input", function() {
        beforeEach(simpleFixtureSetup);
        describe("one input:", function() {
            it("should replace the contents of the specified tag with sth. generated", function() {
                // initialize query input
                $('#' + this.randomId).QueryInput({
                    params: {
                        query: {label: "", value: "", widget: "cql", cql_config: this.cql_config},
                        submit: {label: "", value: "suchen", widget: "submit"}
                    },
                    onValueChanged: function (v) {
                        console.log(this, v);
                    }
                });
                expect($("#input-query")).toBeInDOM();
                expect($("#input-query")).toHaveClass('type-cql');
                expect($("#query-widget")).toBeInDOM();                
                expect($(".cmd-wrapper")).toBeInDOM();                               
                expect($(".search-clauses-table")).toBeInDOM();                
                expect($("#input-submit")).toBeInDOM();
                expect($("#input-submit")).toHaveClass('type-submit');
            });
            it("should be able to create a text input and a submit button", function() {
                // initialize query input
                $('#' + this.randomId).QueryInput({
                    params: {
                        query: {label: "", value: "", widget: "text", size: 10},
                        submit: {label: "", value: "suchen", widget: "submit"}
                    },
                    onValueChanged: function (v) {
                        console.log(this, v);
                    }
                });
                expect($("#input-query")).toBeInDOM();               
                expect($("#input-query")).toHaveClass('type-text');                              
                expect($("#input-query")).toHaveAttr('size', '10');
                expect($("#input-submit")).toBeInDOM();
                expect($("#input-submit")).toHaveClass('type-submit');                
            });
            it("should be able to create a text input, a checkbox and a submit button", function() {
                // initialize query input
                $('#' + this.randomId).QueryInput({
                    params: {
                        query: {label: "", value: "", widget: "text"},
                        vkbtoggle: {label: "äöü", label_after_input: true, checked: "checked", widget: "checkbox"},
                        submit: {label: "", value: "suchen", widget: "submit"}
                    },
                    onValueChanged: function (v) {
                        console.log(this, v);
                    }
                });
                expect($("#input-query")).toBeInDOM();               
                expect($("#input-query")).toHaveClass('type-text');                              
                expect($("#input-query")).not.toHaveAttr('size');
                expect($("#input-vkbtoggle")).toBeInDOM();               
                expect($("#input-vkbtoggle")).toHaveClass('type-checkbox');                              
                expect($("#input-vkbtoggle")).toHaveAttr('checked');
                expect($("#input-vkbtoggle + label")).toBeInDOM();
                expect($("#input-vkbtoggle + label")).toHaveAttr('for', 'input-vkbtoggle'); 
                expect($("#input-submit")).toBeInDOM();
                expect($("#input-submit")).toHaveClass('type-submit');                
            });
            it("should be able to create a checkbox and a label for that with addional css classes", function() {
                // initialize query input
                $('#' + this.randomId).QueryInput({
                    params: {
                        vkbtoggle: {
                            label: "äöü",
                            additional_classes: 'virtual-keyboard-toggle sth else',
                            additional_label_classes: 'sth else',
                            checked: "",
                            widget: "checkbox"
                        },
                    },
                    onValueChanged: function (v) {
                        console.log(this, v);
                    }
                });
                expect($("#input-vkbtoggle")).toBeInDOM();               
                expect($("#input-vkbtoggle")).toHaveClass('type-checkbox');                               
                expect($("#input-vkbtoggle")).toHaveClass('virtual-keyboard-toggle');                               
                expect($("#input-vkbtoggle")).toHaveClass('sth');                               
                expect($("#input-vkbtoggle")).toHaveClass('else');
                expect($("#input-vkbtoggle")).toHaveAttr('checked');
                expect($("label + #input-vkbtoggle")).toBeInDOM();
                expect($("label")).toHaveAttr('for', 'input-vkbtoggle');                               
                expect($("label")).toHaveClass('sth');                               
                expect($("label")).toHaveClass('else'); 
            });
            it("should be able to replace the contents of the specified tag with a virtual keyboard combo", function() {
                // initialize query input
                $('#' + this.randomId).QueryInput({
                    params: {
                        query: {label: "", value: "", widget: "vkb-cql", cql_config: this.cql_config},
                        submit: {label: "", value: "suchen", widget: "submit"}
                    },
                    onValueChanged: function (v) {
                        console.log(this, v);
                    }
                });
                expect($("#input-query")).toBeInDOM();               
                expect($("#input-query")).toHaveClass('type-vkb-cql');
                expect($("#input-submit")).toBeInDOM();
                expect($("#input-submit")).toHaveClass('type-submit');
            });
            xit("should check many more things", function(){
                
            });
        });

        xdescribe("many inputs", function() {
            beforeEach(function(){
                this.firstInput = randomizeFirstInputId();
            });
            it("should work with any number of inputs on the same page", function() {
                for (var i = 0; i < 9; i++) {
                    addAnotherTestInput();
                }
                VirtualKeyboard.attachKeyboards();
                expect($(".virtual-keyboard").length).toEqual(10);
                $(".virtual-keyboard").each(function(unused, element) {
                    var element = $(element);
                    expect(element).toHaveData('linked_input');
                    expect($("#" + element.data('linked_input'))).toBeInDOM();
                });
            });
            it("should be able to only attach keyboards to new inputs", function() {
                VirtualKeyboard.attachKeyboards();
                for (var i = 0; i < 3; i++) {
                    addAnotherTestInput();
                    VirtualKeyboard.attachKeyboards();
                }
                expect($(".virtual-keyboard").length).toEqual(4);
                $(".virtual-keyboard-input").each(function(unused, element) {
                    var id = $(element).attr("id");
                    expect($(".virtual-keyboard-input#" + id + "~.virtual-keyboard")).toHaveData('linked_input', id);
                });
            });
            it("should attach the keyboard according to the context context attribute", function(){
                for (var i = 0; i < 3; i++) {
                    var currentInput = addAnotherTestInput();
                    // data() only pulls the data-* attribute on first access, never changes it.
                    currentInput.attr('data-context', 'mecmua');
                }
                expect($('.virtual-keyboard-input[data-context="mecmua"]')).toBeInDOM();
                expect($('.virtual-keyboard-input[data-context="arz_eng_006"]')).toBeInDOM();
                VirtualKeyboard.attachKeyboards();
                expect($('.virtual-keyboard[data-context="mecmua"]')).toBeInDOM();
                expect($('.virtual-keyboard[data-context="arz_eng_006"]')).toBeInDOM();            });
        });
    });

    xdescribe("Manipulating inputs:", function() {
        beforeEach(simpleFixtureSetup);
        describe("many inputs", function() {
            beforeEach(randomizeFirstInputId);
            it("should insert a character into the text control it's attached to", function() {
                for (var i = 0; i < 2; i++) {
                    addAnotherTestInput();
                    VirtualKeyboard.attachKeyboards();
                }
                $(".virtual-keyboard").each(function(unused, element) {
                    var linked_input = $('#' + $(element).data('linked_input'));
                    $(element).children().each(function(unused, element) {
                        var text_before = linked_input.val();
                        $(element).trigger("click");
                        var text_after = linked_input.val();
                        expect(text_after.length > text_before.length).toBeTruthy();
                        expect(linked_input.val()).toEqual(text_before + $(element).text());
                    });
                });
            });
        });
        describe("one input", function() {
            describe("insertion tests", function() {
                beforeEach(function() {
                    this.testVal = 'test';
                    this.insertPoint = Math.round(this.testVal.length / 2);
                    this.testStart = this.testVal.slice(0, this.insertPoint);
                    this.testEnd = this.testVal.slice(this.insertPoint);
                    VirtualKeyboard.attachKeyboards();
                    $('#sth-unique').val(this.testVal);
                });
                it("should insert the character at the current position", function() {
                    // caret is not at the end in FF or IE!
                    // for e.g. chrome:
                    if (navigator.userAgent.indexOf("Chrome") > 0) {
                        expect($('#sth-unique').selection('getPos').start).toEqual(this.testVal.length);
                        expect($('#sth-unique').selection('getPos').end).toEqual(this.testVal.length);
                    } else {
                    // for FF, IE, ??
                        expect($('#sth-unique').selection('getPos').start).toEqual(0);                        
                        expect($('#sth-unique').selection('getPos').end).toEqual(0);
                    }
                    $('#sth-unique').selection('setPos', {start: this.insertPoint, end: this.insertPoint});
                    var keyboard = $('#sth-unique + .virtual-keyboard');
                    var testData = this;
                    $(keyboard).children().each(function(unused, element) {
                        var key = $(element);
                        key.trigger("click");
                        testData.testStart += key.text();
                    });
                    this.testVal = this.testStart + this.testEnd;
                    expect($('#sth-unique').val()).toEqual(this.testVal);
                });
                it("should replace the selection with the clicked character", function() {
                    $('#sth-unique').selection('setPos', {start: this.insertPoint - 1, end: this.insertPoint + 1});
                    var keyboard = $('#sth-unique ~ .virtual-keyboard');
                    this.testStart = this.testStart.slice(0, -1);
                    var testData = this;
                    $(keyboard).children().each(function(unused, element) {
                        var key = $(element);
                        key.trigger("click");
                        testData.testStart += key.text();
                    });
                    this.testVal = this.testStart + this.testEnd.slice(1);
                    expect($('#sth-unique').val()).toEqual(this.testVal);
                });
            });
        });
    });
//    xdescribe("End (deacitvated)", function() {
//        xit("the end", function(){});
//    });
});

