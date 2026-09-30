({
    initiate: function(component) {
        var _self =this;
        Promise.all([_self.loadCardCaches(component), 
                     _self.initiateCards(component),
                    _self.loadPreDefinedValue(component),
                    _self.initiateFieldFilters(component),
                    _self.loadUserInfo(component)]).then( $A.getCallback(function(responses) {
            var valueRes = responses[0];
            var cardRes = responses[1];
            var preValueRes = responses[2];
            var fieldFilterRes = responses[3];
            var userRes = responses[4];
            if(component.get("v.disableUserPreload")) {
                component.set("v.userRecord", null);
            } else {
                if(userRes.getReturnValue()) {
                    component.set("v.userRecord", JSON.parse(userRes.getReturnValue()));
                }
            }
            _self.setupPreDefinedValues(preValueRes, component);            
            _self.setupCardValues(valueRes, component);
            _self.getFilteredCards(cardRes, component);
            _self.setupFieldFilters(fieldFilterRes, component);

            let currentIndex = component.get("v.currentindex");
            if(currentIndex !== 0) {
                _self.redirect(component, currentIndex, 0);
            } else {
                _self.loadForm(component);
            }
            component.set("v.progress", 0);
        })).catch(ex => {
            console.log("ex", ex);
        });  
    },
    // Runs next actions
    runExtraComp: function(component, nextActions, areas) {
        const valueMap = component.get("v.valueMap");
        const formData = component.get("v.formData");
        const application = component.get("v.application");
        const appId = component.get("v.appId");
        const cardCaches = component.get("v.cardCaches");
        const cmpName = nextActions.name;
        const cardMetaName = component.get("v.cards")[component.get("v.currentindex")].Name;
        const card = component.get("v.cards")[component.get("v.currentindex")]
        // next actions value contains the further definition
        const value = nextActions.value;
        const params = {valueMap, formData, application, appId, card, 
                cardCaches, cardMetaName};
        if(value) {
            params.value = value;
        }
        
        const cmps = [["c:"+ cmpName, params]];
        this.createComponents(cmps).then($A.getCallback(function(results){
            component.set(areas,[]);
            //Set the body
            component.set(areas, results); 
            component.set("v.isLoadingComplete",true);
            component.set("v.stopButtonPressed", false);
            // component.set("v.isLoading", false);
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
    redirect: function(component, index, currentIndex) {
        component.set("v.oldcurrentindex", currentIndex);
        component.set("v.currentindex", index);
    
        const totalc = component.get("v.numcards");
        const tot = Math.round(index / (totalc - 1) * 100);
        
        component.set("v.progress", tot);
        this.loadForm(component);

    },
    loadUserInfo: function(component) {
        var action = component.get("c.getCurrentUserInfo");
       	return this.execute(action);
    },
    setupFieldFilters: function(fieldFilterRes, component) {
        var fieldFilterStr = fieldFilterRes.getReturnValue() || '{}';
        var fieldFilters = JSON.parse(fieldFilterStr);
        component.set("v.fieldFilters", fieldFilters);
    },
    initiateFieldFilters: function (component){
        var _self = this;
        var action = component.get("c.getFieldFilters");
        var applicationName = component.get("v.applicationName");
        action.setParams({"appName": applicationName});
        return _self.execute(action);
    },
    setupPreDefinedValues: function(preValueRes, component){
    	var preValue = preValueRes.getReturnValue();
    	if(preValue !== '' && preValue !== null) {
    		component.set("v.preValueMap", JSON.parse(preValue)); 
		}
	},
    loadPreDefinedValue: function(component) {
        var action = component.get("c.loadPreValues");
        var appCacheName = component.get("v.applicationcacheid");
        action.setParams({
            appCacheName
        });
        return this.execute(action);
    },
    loadCardCaches: function(component) {
        var action = component.get("c.loadCardValues");
        var appCacheName = component.get("v.applicationcacheid");
        action.setParams({
            appCacheName
        });
        return this.execute(action);
    },
    setupCardValues : function(response, component){
        const cardValueStr = response.getReturnValue();
        const cardValues = JSON.parse(cardValueStr);
        const cardCaches = component.get("v.cardCaches") || {};
        const cardFiles = {};
        for (var key in cardValues) {
            var valueStr = cardValues[key].Values__c;
            cardCaches[key] = cardCaches[key] || {};
            cardCaches[key].cacheId = cardValues[key].Id;
            cardCaches[key].cachedValue = valueStr ? JSON.parse(valueStr) : {};
            cardCaches[key].cachedFiles = cardValues[key].Files__c ? JSON.parse(cardValues[key].Files__c) : {};
        }
        
        component.set("v.cardCaches", cardCaches);
        console.log("v.cardCaches on load", cardCaches);
        console.log("v.files on load", cardFiles);
    },
    updateItems: function(component, fieldsToBeUpdated, isUpdate) {
        if(fieldsToBeUpdated.length) {
            var fieldOverriden = {};
            console.log("fieldsToBeUpdated.length", fieldsToBeUpdated.length);
            var fields = {"records": fieldsToBeUpdated};
            fields = this.overrideFieldMetaData(
                fields, component, component.get('v.valueMap'));
            fields.records.forEach(function(fieldRec) {
                fieldOverriden[fieldRec.Name__c] = fieldRec; 
            });
            let valueMap = {};
            component.find("card").get("v.body").forEach(function(field){
                var fName = field.get("v.fieldName");
                if(fieldOverriden[fName]) {
                    var overrideField = fieldOverriden[fName];
                    if( overrideField["Hidden__c"] && field.get("v.fieldType") === "fileupload"){
                        var parentId = field.get("v.parentId");
                        field.deleteFiles(fName, parentId);
                    } else if(overrideField["Hidden__c"] && field.get("v.fieldType") === "picklist") {
                        field.set("v.selectedValue", null);
                        valueMap[fName] = null;
                    } else if( overrideField["Hidden__c"] && field.get("v.fieldType") === "fileupload") {
                        // Not do anything, the file will be not picked if it is hidden.
                    } else if(field.get("v.fieldType") !== "file") {
                        field.set("v.value", "");    
                        valueMap[fName] = null;
                    }
                    
                    if(overrideField["Required__c"] !== undefined) {
                        field.set("v.required", overrideField["Required__c"]);
                    }
                    if(overrideField["Label__c"] !== undefined) {
                        field.set("v.fieldLabel", overrideField["Label__c"]);
                        
                    }
                    if(overrideField["Hidden__c"] !== undefined) {
                        field.set("v.fieldHidden", overrideField["Hidden__c"]);
                    }
                    if(overrideField["Placeholder__c"] !== undefined) {
                        field.set("v.fieldplaceholder", overrideField["Placeholder__c"]);
                    }
                    if(overrideField["Read_Only__c"] !== undefined) {
                        field.set("v.readOnly", overrideField["Read_Only__c"]);
                    }
                    if(overrideField["Popover_Help__c"] !== undefined) {
                        field.set("v.popuphelp", overrideField["Popover_Help__c"]);
                    }
                    if(overrideField["Values__c"] !== undefined) {
                        field.set("v.fieldvalues", overrideField["Values__c"]);
                    }
                }
            });
            if(isUpdate) {
                let values = component.get("v.valueMap");
                Object.keys(valueMap).forEach(key=> {
                    values[key] = valueMap[key];
                });
                component.set("v.valueMap", values);
            }
            
        }
    },
    overrideItems: function(component, fieldName, value) {
        const fieldsToBeUpdated = this.checkInFilters(component, fieldName, value);
        this.updateItems(component, fieldsToBeUpdated, true);
    },
    initiateCards : function(component) {
        var _self = this;
        var appNo = component.get("v.applicationcacheid");
        var action = component.get("c.getCardMetaData"); //Retrieving the getMyObjects controller
        component.set("v.isLoadingComplete", false);
        action.setParams({
            appid: component.get("v.applicationName"),
            appNo: appNo
        });
        return _self.execute(action);
    },
    showToast : function(title, message, type) {
        var toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            "title": title,
            "message": message,
            "type": type
        });
        toastEvent.fire();
    },
    saveData: function(component, event, cIndex) {
        /* save data ***/
        var _self = this;
        var applicationcacheid = component.get("v.applicationcacheid");
        var preValueMap = component.get("v.preValueMap") || {};
        var action1 = component.get("c.saveApplication") ;
        var currentCardName = component.get("v.currentcard");
        const formData = component.get("v.formData");
        const valueMap = component.get("v.valueMap");
        if(valueMap.sameAsMailingAddress == true 
                || valueMap.sameAsMailingAddress === "true") {
            valueMap.mailingCity = valueMap.residenceCity;
            valueMap.mailingState = valueMap.residenceState;
            valueMap.mailingStreet = valueMap.residenceStreet;
            valueMap.mailingZip = valueMap.ResidenceZip;
            valueMap.mailingCountry = valueMap.ResidenceCountry;
        }

        if(applicationcacheid) {
            if(!event) {
                action1 = component.get("c.saveDraftApplication");
            } 
        	action1.setParams({
                appname: component.get("v.applicationName"),
                appid: component.get("v.applicationid"),
                appcacheid: component.get("v.applicationcacheid"),
                cardname: currentCardName,
                cardcacheid: component.get("v.currentcardcacheid"),
                comps: valueMap,
                files: JSON.stringify(component.get("v.files")) 
        	});
        } else {
            action1 = component.get("c.createApplication");
            action1.setParams({
                appId: component.get("v.applicationid"),
                formData,
                cardName: currentCardName,
                comps: valueMap,
                preValue: JSON.stringify(preValueMap),
                files: JSON.stringify(component.get("v.files"))
        	});
        }
        return this.execute(action1).then($A.getCallback(function(response) {
            var valueMap = component.get("v.valueMap");
            var files = component.get("v.files");
            var cardName = component.get("v.currentcard");
            var cardCaches = component.get("v.cardCaches") || {};
            cardCaches[cardName] = cardCaches[cardName] || {};
            cardCaches[cardName].cachedValue = valueMap;
            cardCaches[cardName].cachedFiles = files;
            component.set("v.cardCaches", cardCaches);

            component.set("v.isnew", false);
            var obj = JSON.parse(response.getReturnValue());
            component.set("v.applicationcacheid", obj[0]);
            component.set("v.appId", obj[2]);
            component.set("v.currentcardcacheid", obj[1]);
            _self.cardSubUpdate(component, obj[2], obj[1]);
            _self.attachUploadUrl(component, obj[2]);
            if((event && event.getSource().getLocalId() === 'buttonnext') || 
                (event.getParams().type && event.getParams().type === "continue-with-next") || cIndex !== undefined) {
                _self.afterSave(component, cIndex);    
            } else {
                component.set("v.isLoadingComplete", true);   
                component.set("v.isLoading", false);
                component.set("v.stopButtonPressed", false);
            }               
            return true;
        })).catch(function(error) {
            component.set("v.isLoading", false);
            component.set("v.isLoadingComplete", true);
        }); 
    },
    attachUploadUrl: function(component, recordId) {
        const uploadUrl = component.get("v.uploadUrl");
        if(!uploadUrl || !uploadUrl.length) {
            const action = component.get("c.getFolderURL");
            action.setParams({ recordId });
            this.execute(action).then( $A.getCallback(function(response){
                const url = response.getReturnValue();
                component.set("v.uploadUrl", url);
            })).catch(ex => {
                console.error("error", ex);
            });
        }
    },
    cardSubUpdate: function(component, recordId, cardId) {
        const action = component.get("c.cardUpdate");
        action.setParams({recordId, cardId});
        this.execute(action);
    },
    afterSave: function(component, cIndex) {
        // const hiddenCards = component.get("v.hiddencards");
        // const cards = component.get("v.cards");
        var index = component.get("v.currentindex");
        component.set("v.oldcurrentindex", index);
        try{
            index = parseInt(index);
        }catch(ex) {

        }
        
        index = index + 1;
        if(cIndex !== undefined) {
            index = cIndex
        }
        component.set("v.currentindex", index);
        var totalc = component.get("v.numcards");
        var tot = Math.round(index / (totalc - 1) * 100);
        component.set("v.progress", tot);
        component.set("v.stopButtonPressed", false);
        if(sessionStorage) {
            const currentIndex = component.get("v.currentindex")
            sessionStorage.setItem("sc_Application_ExistingForm_app_no", component.get("v.applicationcacheid"));
            sessionStorage.setItem("sc_Application_ExistingForm_index", currentIndex);
            
        }
        this.loadForm(component);
    },
    checkInFilters: function(component, fieldName, value) {
        const filteredCards = component.get("v.cards");
        const index = filteredCards.findIndex(item=> item.Name == component.get("v.currentcard")) || component.get("v.currentindex");
        if (index == (filteredCards.length - 1)) {
            component.set("v.finalcard", true);
        } else {
            component.set("v.finalcard", false);
        }

        const card = filteredCards.filter(item => item.Name == component.get("v.currentcard"))[0];
        const originalFields = card.Field_Meta_Data1__r;
        
        const fieldFilters = component.get("v.fieldFilters");
        const fieldsToBeUpdated = [];
        const fieldMap = {};
        for (var apiName in fieldFilters) {
			var filterList = fieldFilters[apiName];
            if(filterList) {
                filterList.forEach(function(filters) {
                    filters.forEach(function(filter){
                        if(filter.Controlling_Field_Name__c === fieldName) {
                            fieldMap[apiName] = true;
                        }    
                    });
                    
                });
            }
        }
        
        originalFields.records.forEach(function(record) {
            if(fieldMap[record.Name__c]) {
                fieldsToBeUpdated.push(record);
            }
        });
        return fieldsToBeUpdated;
        
    },
    loadForm: function(component) {
        const _self = this;
        window.scrollTo(0, 0);
        component.set("v.isLoading", true);
        component.set("v.isLoadingComplete", false);
        this.refreshCards(component).then($A.getCallback(function(){
            component.set("v.isLoading", false);
            component.set("v.isLoadingComplete", true); 
            // overrideItems
            const filteredCards = component.get("v.cards");
            const index = filteredCards.findIndex(item=> item.Name == component.get("v.currentcard")) || component.get("v.currentindex");
            if (index == (filteredCards.length - 1)) {
                component.set("v.finalcard", true);
            } else {
                component.set("v.finalcard", false);
            }

            const card = filteredCards.filter(item => item.Name == component.get("v.currentcard"))[0];
            _self.overrideFieldMetaData(card.Field_Meta_Data1__r, component)
            
        })).catch(function(ex) {
            console.error("ex", ex);

        });        
    },
    getFilteredCards: function(response, component) {
        var depcards = component.get("v.hiddencards");
        var index = component.get("v.currentindex");
        var rawRes = JSON.parse(response.getReturnValue()); //gets the value returned from the server, turned into javascript object
        var rawCards = [];
        rawRes.forEach(function(res) {
            var rawCard = res.card;
            rawCard["Field_Meta_Data1__r"] = {"records": res.fields};
			rawCards.push(rawCard);
        });
        
        var decardMap = depcards.reduce(function(map, item) {
            map[item.trim()] = item;
            return map;
        }, {});
        var filteredCards = rawCards.filter(function(card) {
            return decardMap[card.Name.trim()] === undefined;
        });
        if (filteredCards.length > 0) {
            // No cards 
            // 
        }
        index = index || 0;
        component.set("v.currentindex", index);
        component.set("v.numcards", filteredCards.length + 1);
        component.set("v.applicationid", filteredCards[0].Application_Meta_Data__c);
        component.set("v.cards", filteredCards);
        return filteredCards;
    },
    combineAllValues: function(component){
        var cardCaches = component.get("v.cardCaches");
        
        var allCaches = {};
        for(var cardName in  cardCaches){
            if(cardName){
                var valueMap = cardCaches[cardName].cachedValue;
                console.log("cardCaches: ", valueMap);
                for(var key in valueMap) {
                    var value = valueMap[key];
                    allCaches[key] = value
                }
            }
        }
		return allCaches;
    },

    refreshNavigationBars: function(component) {
        const currentIndex = component.get("v.currentindex");
        const navCards = component.find("navCards");
        const vnavCards = component.find("vnavCards");
        if(navCards) {
            navCards.setupIndex(currentIndex);
        }
        if(vnavCards) {
            vnavCards.setupIndex(currentIndex);
        }

    },
    refreshNavigationCards: function(component, cards) {
        const navCards = component.find("navCards");
        const vnavCards = component.find("vnavCards");
        if(navCards) {
            navCards.setupCards(cards);
        }
        if(vnavCards) {
            vnavCards.setupCards(cards);
        }
    },
    refreshCards: function(component) {
        var _self = this;
        const cards = component.get("v.cards");
        const depcards = component.get("v.hiddencards");
        const filteredCards = cards.reduce((result, card) => {
            if(!depcards.includes(card.Label__c)) {
                result.push(card);
            }
            return result;
        }, []);
        // if(filteredCards.length !== cards.length) {
        this.refreshNavigationCards(component, filteredCards);
        // }
        var index = component.get("v.currentindex");
        if (index == (filteredCards.length - 1)) {
            component.set("v.finalcard", true);
        } else {
            component.set("v.finalcard", false);
        }
        var card = filteredCards[index];
        if(!card) {
            return;
        }
        component.set("v.currentcard", card.Name);
        var cardComp = component.find("card");
        var cardCaches = component.get("v.cardCaches") || {} ;
        var cardCache = cardCaches[card.Name];
        var data, files;
        if(cardCache) {
            data = cardCache.cachedValue;
            files = cardCache.cachedFiles;
            const valueMap = cardCache.cachedValue || {};
            component.set("v.valueMap", valueMap);
        }
        component.set("v.files", files);
        data = data || {};
        console.log("data: ", JSON.stringify(data));
        console.log("files: ", JSON.stringify(files));
        var fields = _self.overrideFieldMetaData(card.Field_Meta_Data1__r, component);
        cardComp.set("v.headerLabel", card['Header__c']);
        cardComp.set("v.footerLabel", card['Footer__c']);
        cardComp.set("v.cardname", card.Name);
        cardComp.set("v.fieldjson", fields);
        cardComp.set("v.data", data);
        cardComp.set("v.file", files);
        
        return cardComp.refreshCard();
    },
    nextAction: function(component, event, cIndex) {
        if (component.get("v.stopButtonPressed") || !component.get("v.isLoadingComplete") || component.get("v.isLoading")) {
            return;
        }
        component.set("v.isLoading", true);
        component.set("v.cIndex", cIndex);
        component.set("v.stopButtonPressed", true);
        component.set("v.isLoadingComplete",false); 
        const currentcard = component.get("v.currentcard");
        const isValid = this.validate(component);
        
        if (isValid == true) {
            this.save(component);
            const nextActionStr = component.get("v.cards").filter(item => item.Name == currentcard)[0].NextActions__c;
            if(nextActionStr) {
                
                const nextActions = JSON.parse(nextActionStr);
                if(nextActions.type === "display") {
                    this.runExtraComp(component, nextActions, "v.extraActions");
                }
                return;
            }
            this.saveData(component,event, cIndex);
        } else {
            component.set("v.isLoadingComplete",true);
            component.set("v.stopButtonPressed", false);
            component.set("v.isLoading", false);
            const toastEvent = $A.get("e.force:showToast");
            toastEvent.setParams({
                "title": "Failed",
                "message": "One or more required fields are missing or values are incorrect.",
                "type": "error"
            });
            toastEvent.fire();
        }

    },
    overrideFieldMetaData : function(fields, component, extraValueMap) {
        var _self = this;
        var fieldFilters = component.get("v.fieldFilters") || {};
        var preDefinedValue = component.get("v.preValueMap") || {};
        var existingValueMap = _self.combineAllValues(component);
        if(extraValueMap) {
            for(var key in extraValueMap) {
                existingValueMap[key] = extraValueMap[key];
            }
        }
        var valueMap = existingValueMap;
        fields.records.forEach(function(field) {            
            if(field["Required__original"] !== undefined) {
                field["Required__c"] = field["Required__original"];
            }
            if(field["Label__original"] !== undefined) {
               field["Label__c"] = field["Label__original"]; 
            }
            if(field["Hidden__original"] !== undefined) {
                field["Hidden__c"] = field["Hidden__original"]; 
            }
            if(field["Placeholder__original"] !== undefined) {
                field["Placeholder__c"] = field["Placeholder__original"]; 
            }
            if(field["Read_Only__original"] !== undefined) {
                field["Read_Only__c"] = field["Read_Only__original"]; 
            }
            if(field["Popover_Help__original"] !== undefined) {
                field["Popover_Help__c"] = field["Popover_Help__original"]; 
            }
            if(field["Values__original"] !== undefined) {
                field["Values__c"] = field["Values__original"]; 
            }
            var fieldFilter = fieldFilters[field.Name__c];
            if(fieldFilter){
                fieldFilter.forEach(function(filterList) {
                    // check if need to override field.
                    if(filterList[0] 
                       && _self.checkFieldFilterList(filterList, preDefinedValue, valueMap)) {
                        field = _self.updateField(filterList[0], field);
                    } else {
                        
                        field.forceUpdate = false;
                    }
                });
            }
        });  
        return fields;
    },
    updateField: function(filter, field) {
        var toBeOverriden = filter.Field_attribute_to_be_updated__c;
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
        return field;
    },
    checkFieldFilterList : function(filterList, preDefinedValue, valueMap) {
        var needForUpdate = false;
        var meeAllconditions = true;
        filterList.forEach(function(filter){
            var currentValue;
			var currentFieldValue = preDefinedValue[filter.Controlling_Field_Name__c];
            if(currentFieldValue){
                currentValue = currentFieldValue.value;
            } 
            if(filter.Controlling_Field_Value__c === undefined) {
                filter.Controlling_Field_Value__c = "";
            }
            currentValue = currentValue || valueMap[filter.Controlling_Field_Name__c];
            if(currentValue === undefined || currentValue === null) {
                currentValue = "";
            } else {
                currentValue +="";
            }
            if(currentValue !== undefined && (currentValue + "") === filter.Controlling_Field_Value__c ){
                needForUpdate = true;
            } else {
                meeAllconditions = false;
                needForUpdate = false;
            }
        });
        return meeAllconditions && needForUpdate;
    },
    validate: function(component) {
        const theappid = component.get("v.applicationid");
        let isValid = true;
        if (theappid != null) {
            var depcards = component.get("v.hiddencards");
            if (depcards == null) depcards = [];
            var myvals = component.find("card").get("v.body");
            for (var i = 0; i < myvals.length; i++) {
                var thec = myvals[i];
                
                var inp = myvals[i].find(name);
                var name = thec.get("v.fieldName");
                var req = thec.get("v.required");
                var hidden = thec.get("v.fieldHidden");
                if (hidden || thec.get("v.fieldType") === 'info') {
                    continue;
                }
                let act_value = thec.get("v.value");
                
                if (name == null || name == "") name = "null";
                
                if (thec.get("v.fieldType") === "clm-file" ) {
                    act_value = thec.getVal();
                    if ((!act_value || act_value === '[]') && req ) {
                        thec.set("v.errors", [{message:"This field is mandatory"}]);
                        isValid = false; 
                        continue;
                    } else {
                        thec.set("v.errors", null);
                    }
                }
                if (thec.get("v.fieldType") == 'checkbox' || thec.get("v.fieldType") == 'text') {
                    if(!thec.validate()) {
                        isValid = false; 
                        continue;
                    }
                    component.set("v.hiddencards", depcards);
                }
                if (thec.get("v.fieldType") == 'picklist') {
                    act_value = thec.get("v.selectedValue");
                    if(!thec.validate()) {
                        isValid = false; 
                        continue;
                    }
                    if (req && act_value == '-None-'){   
                        isValid = false; 
                        continue; 
                    }
                }
                if (thec.get("v.fieldType") == 'textarea') {
                    if(!thec.validate()) {
                        isValid = false; 
                        continue;
                    }
                    var pickedTxt = thec.get("v.value");
                    if (req && (pickedTxt == 'undefined' || pickedTxt == '' || pickedTxt == null)) {
                        isValid = false; 
                        continue;
                    }
                    
                }
                if (thec.get("v.fieldType") == 'date') {
                    var datePicked = thec.get("v.value");
                    
                    if (req && (datePicked == 'undefined' || datePicked == '' || datePicked == null)) {
                        thec.set("v.errors", [{message:"This field is mandatory"}]);
                        isValid = false; 
                        continue;
                    } else if(!thec.validate()) {
                        isValid = false; 
                        continue;
                    } else {
                        thec.set("v.errors", null);
                    }
                    
                }
                if (act_value == null || act_value == "") act_value = "null";
                if (req && (act_value == "null" || act_value == "-None-") && !hidden) {
                    var inp = thec;
                    if (inp.get("v.fieldType") == "checkbox") {
                        $A.util.toggleClass(inp, "checkboxError");
                    }
                    
                    if (inp.get("v.fieldType") == "picklist") {
                        if (act_value == null || act_value == "-None-") {
                            $A.util.toggleClass(inp, "checkboxError");
                            $A.util.addClass(inp, "slds-has-error");
                        }
                        isValid = false; 
                        continue;
                    }
                    isValid = false; 
                    continue;
                }
                if (thec.get("v.fieldType") == 'fileupload') {
                    act_value = thec.get("v.files");
                    if (req) {
                        if (thec.find("fileList") === null 
                            || thec.find("fileList").get("v.files") === null 
                            || thec.find("fileList").get("v.files").length === 0) {
                            
                            $A.util.addClass(inp, "slds-has-error");
                            thec.set("v.errorMessage", "This field is mandatory");
                            isValid = false; 
                            continue;
                        }
                    }
                }
                if (thec.get("v.fieldType") == 'file') {
                    if (req) {
                        if (act_value == null || act_value.length === 0) {
                            $A.util.addClass(inp, "slds-has-error");
                            thec.set("v.errorMessage", "This field is mandatory");
                            isValid = false; 
                            continue;
                        }
                    }
                }
                
            }
        }
        return isValid;
                
    },
    save: function(component) {
        /* going to save */
        var theappid = component.get("v.applicationid");
        var valueMap = {};
        var filemap = {};
        if (theappid != null) {
            var depcards = component.get("v.hiddencards");
            if (depcards == null) depcards = [];
            var myvals = component.find("card").get("v.body");
            for (var i = 0; i < myvals.length; i++) {
                var thec = myvals[i];
                var name = thec.get("v.fieldName");
                if (name == null || name == "") name = "null";
                var act_value = thec.get("v.value");

                if (thec.get("v.fieldType") === "clm-file" ) {
                    act_value = thec.getVal();
                }
                
                if (thec.get("v.fieldType") == 'picklist') {
                    act_value = thec.get("v.selectedValue");
                    var fv = thec.get("v.fieldvalues");
                    if(act_value === '-None-') act_value = "";
                    fv = fv || "";
                    valueMap[name] = act_value ;
                }
                if (thec.get("v.fieldType") == 'inputtable') {
                    var rows = thec.get("v.rows");
                    if (rows != null) {
                        var values = name + '';
                        for (var t = 0; t < rows.length; t++) {
                            var thevalues = (rows[t] + '').split(",");
                            for (var x = 0; x < thevalues.length; x++) {
                                values = values + '!=!' + t + '#' + thevalues[x];
                            }
                        }
                        valueMap[name] = values;
                    }
                }
                if(thec.get("v.fieldType") !== 'file'){
                	if (act_value == null || act_value == "") act_value = "";
                }
                if (name === "executionDate") {
                    employEndComp = myvals[i];
                }
                if (thec.get("v.fieldType") != 'info' && thec.get("v.fieldType") != 'picklist'
                    && thec.get("v.fieldType") !== 'fileupload' && thec.get("v.fieldType") !== 'file' && thec.get("v.fieldType") != 'inputtable') {

                    valueMap[name] = act_value ;

                } else if(thec.get("v.fieldType") === 'fileupload'){
                    if(!thec.find("fileList") || thec.find("fileList") === null 
                            || thec.find("fileList").get("v.files") === null 
                            || thec.find("fileList").get("v.files").length === 0){
                        valueMap[name] =  "No File Uploaded";
                    } else {
                        valueMap[name] =  "File Uploaded";
                    }
                                        
                } else if(thec.get("v.fieldType") === 'file'){
                    if(act_value && act_value.length && act_value !== "No File Uploaded"){
                        
                        filemap[name] =  typeof act_value =='string' ?  JSON.parse(act_value): act_value ;
                        valueMap[name] =  "File Uploaded";
                    } else {
                        valueMap[name] =  "No File Uploaded";
                        filemap[name] =  [];
                    }
                }
               

                let depcardval = thec.get("v.carddependentvalue");
                const cardsToHide = thec.get("v.dependentcards");
                if (depcardval != null) {
                    depcardval = depcardval + '';
                    const depCardVals = depcardval.split(';');

                    if (depCardVals.includes(act_value + '') && cardsToHide != null) {
                        for (var ii = 0; ii < cardsToHide.length; ii++) {
                            if (!depcards.includes(cardsToHide[ii].trim())) depcards.push(cardsToHide[ii].trim());
                        }
                    } else {
                        const depcardsMap = cardsToHide.reduce((result, item) => {
                            result[item.trim()] = true;
                            return result;
                        }, {});
                        depcards = depcards.reduce((result, card) => {
                            if(!depcardsMap[card]) {
                                result.push(card);
                            }
                            return result;
                        }, []);
                    }
                    component.set("v.hiddencards", depcards);
                }
            }
            
            component.set("v.valueMap", valueMap);
            component.set("v.files", filemap);
        }
        /* end saving */
    },
    convertToDate: function(str) {
        var formatDate = str.replace("/", "").replace("/", "").replace("-", "").replace("-", "").replace(" ", "").replace(" ", "");
        var isnum = /^\d+$/.test(formatDate);
        if (isnum) {
            var month = formatDate.slice(2, 4);
            var year = formatDate.slice(4, str.length);
            var date = formatDate.slice(0, 2);
            var dateV = new Date(`${month}\/${date}\/${year}`);
        } else {
            var dateV = new Date(formatDate);
        }
        return dateV;
    },
    getEstimatedTime: function(component, appNo) {
        var _self = this;
        var action = component.get("c.getEstimatedTimeframe");
        action.setParams({
            "appNo": appNo,
        });
        return _self.execute(action);
    },
    finalSubmitHelper: function(component) {
        const _self = this;
        component.set("v.hidesummarymodal", true);
        component.set("v.isLoadingComplete", false);
        var actionA = component.get("c.submit");
        actionA.setParams({
            appName: component.get("v.applicationcacheid")
        });
        _self.execute(actionA).then( $A.getCallback(function(response){
            const appRecordJSON = response.getReturnValue();
            const appRecord = JSON.parse(appRecordJSON);
            component.set("v.application", appRecord);
            if(sessionStorage) {
                sessionStorage.removeItem("sc_Application_ExistingForm_app_no");
                sessionStorage.removeItem("sc_Application_ExistingForm_index");
            }
            
            const currentcard = component.get("v.currentcard");
            const nextActionStr = component.get("v.cards").filter(item => item.Name == currentcard)[0].NextActions__c;

            if(nextActionStr) {
                const nextActions = JSON.parse(nextActionStr);
                if(nextActions.type === "review") {
                    _self.runExtraComp(component, nextActions, "v.extraActions");
                } 
            } else {
                component.set("v.isLoadingComplete", true);
                component.set('v.submitted', true);
                var mesg = component.get("v.message") || "";
                component.set("v.message", mesg);
                var mpage = component.find("messagepage");
                $A.util.removeClass(mpage, "slds-hide");
            }

        })).catch(function(errors){
            component.set("v.isLoadingComplete", true);
            var page = component.find("summarypage");
            $A.util.toggleClass(page, "hidemodal");
            var errorMessage = errors.getError()[0].message
            var mesg = component.get("v.message");
            var custmessage = component.get("v.submissionmessage");
            if (component.get("v.debugmode")) mesg = "Submission failed. " + custmessage + "  Quote the following reference number: " + component.get("v.applicationcacheid") + " Error: " + errorMessage;
            else mesg = "Submission failed. " + custmessage + "  Quote the following reference number: " + component.get("v.applicationcacheid");
            component.set("v.message", mesg);
            var toastEvent = $A.get("e.force:showToast");
            toastEvent.setParams({
                "title": "Failed",
                "message": mesg,
                "type": "error"
            });
            toastEvent.fire();
        });
    },
    showToast: function(title, message, type) {
        var toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            "title": title,
            "message": message,
            "type": type
        });
        toastEvent.fire();
    }
})