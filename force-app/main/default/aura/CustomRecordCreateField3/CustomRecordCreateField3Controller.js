({
	doInit : function(component, event, helper) 
	{
		var fld = component.get('v.field');
		
		/*
		address, anytype, base64, Combobox, DataCategoryGroupReference, EncryptedString, ID, MultiPicklist, Reference
		Boolean
		Time
		 */
		
		var cType = 'READONLY';
		if (fld.fieldIsCreatable) 
		{
			if (fld.fieldType == 'EMAIL' || fld.fieldType == 'PHONE' || fld.fieldType == 'STRING' || fld.fieldType == 'URL') {
				cType = 'STRING';
			}
			if (fld.fieldType == 'CURRENCY' || fld.fieldType == 'DOUBLE' || fld.fieldType == 'INTEGER' || fld.fieldType == 'PERCENT') {
				cType = 'NUMBER';
			}
			if (fld.fieldType == 'TEXTAREA') {
				cType = 'TEXTAREA';
			}
			if (fld.fieldType == 'PICKLIST') {
				cType = 'PICKLIST';
			}
			if (fld.fieldType == 'DATETIME') {
				cType = 'DATETIME';
			}
			if (fld.fieldType == 'DATE') {
				cType = 'DATE';
			}
			if (fld.fieldType == 'BOOLEAN') {
				cType = 'BOOLEAN';
			}
			if (fld.fieldType == 'REFERENCE') {
				cType = 'REFERENCE';
			}
		}
		
		var sObj = component.get('v.sObj');
		var readOnly = component.get('v.readOnly');

		// make the lookup readOnly per user's request
		if(cType == 'REFERENCE' && readOnly == true)
		{
			component.set('v.ctrlType', 'REFERENCE-ReadOnly');
		}
		// make the lookup readOnly because the field isn't updateable (ex. master detail reparenting isn't allowed)
		else if(cType == 'REFERENCE' && fld.isUpdateable == false && sObj[fld.fieldAPIName] != null)
		{
			component.set('v.ctrlType', 'REFERENCE-ReadOnly');
		}
		else if(readOnly == true)
		{
			component.set('v.ctrlType', 'READONLY');
		}
		else
		{
			component.set('v.ctrlType', cType);
		}
        
        helper.filterDependentPicklists(component, event, helper);

		if(component.get('v.getDefaultValue') == true)
		{ 
			component.set('v.value', fld.defaultValue);
		}
		else if(sObj)
		{
			component.set('v.value', sObj[fld.fieldAPIName]);
		}

		helper.showContent(component, event, helper);
	},

	changedRelatedListValues : function(component, event, helper) 
	{
        helper.filterDependentPicklists(component, event, helper);
        
		helper.showContent(component, event, helper);
	},

	valueChanged : function(component, event, helper) {
		var val = component.get('v.value');
		var sObj = component.get('v.sObj');
		var fld = component.get('v.field');

		if(sObj)
		{ 
			sObj[fld.fieldAPIName] = val;		
			component.set('v.sObj', sObj);

			var appEvent = $A.get("e.c:ValueChangedEvent");
			appEvent.setParams({
	            "valueChanged" : true });
	        appEvent.fire();
		}
	},
	
	dateValueChanged : function(component, event, helper) {
		var val = component.get('v.value');
		var sObj = component.get('v.sObj');
		var fld = component.get('v.field');
		
		if(sObj)
		{
			sObj[fld.fieldAPIName] = new Date(val);
			
			component.set('v.sObj', sObj);
		}
	}
})