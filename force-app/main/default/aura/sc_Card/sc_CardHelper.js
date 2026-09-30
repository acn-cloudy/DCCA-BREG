({
    buildcardcomponents : function(cmp, event) {
        var _self = this;
        var cacheid, previousData, previousFile;
        var cardBody = [];
        
        previousData = previousData || {};
        // Prepare the cached data from server
        
        previousData = cmp.get("v.data");
        previousFile = cmp.get("v.file") || {};
        console.log("previousData", JSON.stringify(previousData));
        console.log("previousData files", JSON.stringify(cmp.get("v.file")));
        if(previousData === null){
            previousData = {};
        }
        
        cmp.set("v.completed", true);
        var fieldJSON = cmp.get("v.fieldjson") || {};
        var fields = fieldJSON.records;
        
        cacheid = cmp.get("v.applicationcacheid");
        fields.forEach(function(field) {
            cardBody.push(_self.updateField(field, cmp, cacheid, previousData, previousFile));
            
        });
        
        //make the data retreival read only
        return this.createComponents(cardBody).then($A.getCallback(function(results){
            cmp.set("v.body",[]);
            cmp.set("v.body", results); 
            cmp.set("v.completed", true);
        }));
        
    },
    initiateDefaultField: function(defaultValueField, component) {
        var defaultValue;
        var userRecord = component.get("v.userRecord");
        if(userRecord && defaultValueField && defaultValueField.split(".").length >1) {
            var objectName = defaultValueField.split(".")[0];
            var fieldName = defaultValueField.split(".")[1];
            if(objectName === "User") {
            	
                defaultValue = userRecord[fieldName];
            }
        }
        return defaultValue;
    },
    updateField : function(field, cmp, cacheid, previousData, previousFile) {
        var _self= this;
        var payAuthority = cmp.get("v.showPaymentAuth");
        field = this.recalculate(cmp, field);
        var fieldMetaData = {
            "dateValidation": field['Validation_Date__c'],
            "fieldName": field['Name__c'],
            "dependField": field['DependField__c'],
            "dependValue": field['DependValue__c'],
            "dependAction": field['DependAction__c'],
            "originalHidden": field['Hidden__c'],
            "dependentValueToSet": field['Dependent_Value_to_be_set__c'],
            "validationRegression": field['Validation_Regression__c'],
            "fieldInfo": field,
            "fieldLabel": field['Label__c'], // Set fieldLabel to Label__c
            "fieldType": field['Type__c'], // Set fieldType to Type__c
            "fieldplaceholder": field['Placeholder__c'], // Set fieldplaceholder to Placeholder__c
            "readOnly": field['Read_Only__c'],
            "numericonly": field['Validation_Numeric_Only__c'],
            "required": field['Required__c'],
            "fieldlength": field['Validation_Length__c'],
            "fieldminlength": field['Validation_Min_Length__c'],
            "specialcharacters": field['Validation_Special_Chars__c'],
            "emailonly": field['Validation_Email_Only__c'],
            "Phoneonly": field['Validation_Phone_Only__c'],
            "NoSpace": field['Validation_No_Space__c'],
            "NonZeroNumeric": field['Validation_Numeric_greater_than_zero__c'],
            "inlinelabel": field['Inline_Label__c'],
            "popuphelp": field['Popover_Help__c'],
            "carddependentvalue": field['Card_Dependend_Value__c'],
            "carddependentaction": field['Card_Dependent_Action__c'],
            "aura:id": field['Name__c'],
            "cardname": cmp.get("v.cardname")
        };

        var defaultValue = field.Default_Value__c;
        var apiName = field.Name__c;
        var hidden = field.Hidden__c;
        var fieldType = field.Type__c;
        var defaultValueField = field.Default_value_field__c;
        var cachedValueCom = previousData[apiName];
        var cachedFileCom = previousFile[apiName];
        var cachedValue;
        defaultValue = _self.initiateDefaultField(defaultValueField, cmp);
        
        if(cachedValueCom && cachedValueCom.length) {
            cachedValue = cachedValueCom;
        }
        if (fieldType === "checkbox") {
            cachedValue = cachedValueCom;
        }
        
        if (fieldType === "file") {
            if(cachedFileCom && cachedFileCom.length){
	            cachedValue = cachedFileCom;
            } else {
                cachedValue = undefined;
            }
        }
        
         
        if (fieldType === "inputtable" || fieldType === "table") {
            var loadedvals = [];
            var rowload = [];
            var currentline=0;
            cachedValue = cachedValue || "";
            var valueload = cachedValue.split("!=!");
            for (var j = 1; j < valueload.length; j++) {
                var lineitem = valueload[j].split("#");
                var linenum = lineitem[0];
                if (lineitem[1] == 'true') {
                    loadedvals.push(true);
                } else if (lineitem[1] == 'false') {
                    loadedvals.push(false);
                } else {
                    loadedvals.push(lineitem[1]);
                }
                if (currentline + '' != linenum) {
                    loadedvals.pop();
                    rowload.push(loadedvals);
                    currentline++;
                    loadedvals = [];
                    if (lineitem[1] == 'true') {
                        loadedvals.push(true);
                    } else if (lineitem[1] == 'false') {
                        loadedvals.push(false);
                    } else {
                        loadedvals.push(lineitem[1]);
                    }
                }
                if (j >= valueload.length - 1) {
                    rowload.push(loadedvals);
                }
            }
            fieldMetaData["columns"] = field['input_table_cols__c'];
            fieldMetaData["rows"] = rowload;
            fieldMetaData["fieldtypes"] = field['input_table_field_types__c'];
        }
        var depcards = [];
        var dependentCards = field.DependendCards__c;
        if (dependentCards && dependentCards !== null) {
            depcards = dependentCards.split(",")
        }
        var preDefinedValue = cachedValue || defaultValue;
        console.log("field.Values__c: ", field.Values__c);
        if (field['Type__c'] === 'info') {
            fieldMetaData["value"] = field.Values__c;
            fieldMetaData["fieldvalues"] = field.Values__c;
        }
        if (payAuthority !== "true" && field['Name__c'] == 'Payment Authority') {
            hidden = false;
        }
        if(fieldType === "multiPicklist") {
            var optionList = field.Values__c;
            var options = [];
            optionList.split(',').forEach(function(option) {
                options.push({"value": option, "label":option});
            });
            fieldMetaData["options"] = options;
            fieldMetaData["selectedValue"] = preDefinedValue;            
        }
        if(fieldType === "picklist") {
            fieldMetaData["fieldvalues"] = field.Use_Picklist_Values_From_SF__c ? field.PicklistValues__c : field.Values__c;
            fieldMetaData["selectedValue"] = preDefinedValue;
        }
        if(fieldType === "fileupload") {
            fieldMetaData["parentId"] = cmp.get("v.applicationcacheid");
        }
        var cmps;
        if(preDefinedValue === "null" || preDefinedValue === null) {
            preDefinedValue = ""
        }
        fieldMetaData["value"] = preDefinedValue;
        fieldMetaData["dependentcards"] = depcards;
        if(field.forceUpdate) {
            fieldMetaData["fieldHidden"] = field.Hidden__c;
        } else {
            fieldMetaData["fieldHidden"] = hidden;
        }
        
        
        fieldMetaData["hideonload"] = hidden;
        fieldMetaData["cardcacheid"] = cacheid;    
        fieldMetaData["appId"] = cmp.get("v.appId");
        

        if (fieldType === "multicheckbox" || fieldType == "multiPicklist" || fieldType === "file" || fieldType === "clm-file" 
            || fieldType == "radio" || fieldType == "text" || fieldType == "rich text" || fieldType == "checkbox" 
            || fieldType == "date" || fieldType == "datetime" || fieldType == "decimal" || fieldType === "info") {
            fieldMetaData.uploadUrl = cmp.get("v.uploadUrl");
            cmps = ["c:sc_FormField", fieldMetaData];
        } else if (fieldType === "picklist") {
            cmps = ["c:sc_FormSelectField", fieldMetaData];
        } else if (fieldType === "textarea") {
            cmps = ["c:sc_FormTextAreaField", fieldMetaData];
        } else if (fieldType === "fileupload") {
            // cmps = ["c:sc_UploadFileContainer", fieldMetaData];
        } else if (fieldType === "inputtable") {
            cmps = ["c:sc_FormMultiLineInput", fieldMetaData];
        } else if (fieldType === "table") {
            fieldMetaData["sobjectType"] = field["Object__c"];
            cmps = ["c:sc_FormTableInput", fieldMetaData];
        }
        return cmps;
    },
    handleCardComponents : function (impcmps,cmp){
        var isReadOnly = cmp.get("v.isDoneDataRetrieve")
        var impcmps1 = [];
        for (var xx=0;xx<impcmps.length;xx++){ // make the components readonly
            var comp = impcmps[xx];
            if (comp!=null && comp.length>1){
                comp[1]['readOnly']=isReadOnly;
                if(!isReadOnly){
                    if(comp[1]['fieldName'] !='Data retrieval readonly note'){
                        impcmps1.push(comp);
                    }
                }else{
                    impcmps1.push(comp);
                }
            }
        }
        return this.createComponents(impcmps1).then($A.getCallback(function(results){
            cmp.set("v.body",[]);
            //Set the body
            cmp.set("v.body", results); 
            cmp.set("v.completed", true);
        }));
    },
    createComponents: function(body) {
        return new Promise(function(resolve, reject) {
            $A.createComponents(body,function(results, status, errorMessage){
            if (status === "SUCCESS") {
                return resolve(results);
            } else {
                return reject(errorMessage);
            } 
        	}); 
        }) ;
    },
    recalc_depend : function (component, event)
    {
        
        var myc = component.get("v.body");
        console.log("recalc depend = " +myc);
        if (myc.length>0)
        {
            console.log("1st if = ");
            
            var myvals = myc;
            
            for (var i=0;i<myvals.length;i++)
            {
                console.log("inside for");
                var thec = myvals[i];
                
                console.log("THECONTROL FOR CHCKING = "+thec);
                
                var name = thec.get("v.fieldName");
                var thefield = thec.get("v.dependField")+'';
                var theaction = thec.get("v.dependAction");
                var dvalue = thec.get("v.dependValue");
                
                if (thefield!=null)
                {
                    console.log('FINDING ['+thefield+']');
                    
                    var one = component.get("v.body");
                    for (var t=0;t<one.length;t++)
                    {
                        var two = one[t].find(thefield);
                        
                        var inp =  two;
                        var currval = thec.get("v.value");
                        
                        if (inp!=null)
                        {
                            if (thec.get("v.fieldType")=='picklist')
                            {
                                var dvalues = dvalue.split(",");
                                for (var xx=0;xx<dvalues.length;xx++)
                                {
                                    if (dvalues[xx]==thec.get("v.selectedValue"))
                                    {
                                        inp.set("v.fieldHidden",false);
                                        break;
                                    }
                                }
                            }
                            else
                            {
                                if (dvalue == currval)
                                {
                                    inp.set("v.fieldHidden",false);
                                }
                            }
                        }
                        
                    }
                    
                }
            }
        }        
        
    },
    financialStartYear : function() {
        var date = new Date();
        var calendarStartYear = date.getFullYear();
        var month = date.getMonth();
        if(month < 6) {
            calendarStartYear --;
        }
        return calendarStartYear ;
    },
    recalculate: function(component, field) {
        const _self = this;
        const apiName = field.Name__c;
        const valueMap = this.convertToValueMap(component);
        const fieldFilters = component.get("v.fieldFilters");
        const filterList = fieldFilters[apiName];
        
        if(filterList) {
            filterList.forEach(function(filters) {
                filters.forEach(function(filter){
                    if(filter.Controlling_Field_Name__c 
                            && valueMap[filter.Controlling_Field_Name__c] === filter.Controlling_Field_Value__c) {
                        field = _self.updateFieldFilter(filter, field, valueMap);
                    }
                });
            });
        }
        return field;
    },
    convertToValueMap: function(component) {
        const cardCaches = component.get("v.cardCaches");
        const valueMap = {};
        for(let cardName in cardCaches) {
            const { cachedValue } = cardCaches[cardName];
            for(let fieldName in cachedValue) {
                valueMap[fieldName] = cachedValue[fieldName];
            }
        }
        return valueMap;
    },
    updateFieldFilter: function(filter, field, valueMap) {
        const fieldFilters = filter.Field_Filters__r;
        let isMatching = true;
        if(fieldFilters && fieldFilters.records && fieldFilters.records.length) {
            fieldFilters.records.forEach(item => {
                if(valueMap[item.Controlling_Field_Name__c] !== item.Controlling_Field_Value__c) {
                    isMatching = false;
                }
            });
        }

        const toBeOverriden = filter.Field_attribute_to_be_updated__c;
        if(toBeOverriden && isMatching) {
            toBeOverriden.split(";").forEach(function(attribute){
                if(field[attribute + "__original"] === undefined)  {
                    field[attribute + "__original"] = field[attribute + "__c"];
                }
                if(attribute === "Popover_Help" && !filter[attribute+"__c"]) {
                    field[attribute + "__c"] = "";
                } else {
                    field[attribute + "__c"] = filter[attribute+"__c"];
                }
                if(attribute === "Hidden") {
                    field.forceUpdate = true;
                }
            });
        }
        
        return field;
    },
})