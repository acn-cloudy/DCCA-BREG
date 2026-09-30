({
  validate: function(component) {
    var fields = component.find("field");
    if (fields && !fields.length) {
      fields = [fields];
    }
    if (fields && fields.length) {
      return fields.reduce(function(validSoFar, inputCmp) {
        inputCmp.reportValidity();
        return validSoFar && inputCmp.checkValidity();
      }, true);
    }
  },
  checkAvailability: function(component) {
    var action = component.get("c.getRecord");
    var field = component.get("v.conditionField");
    action.setParams({
      objectName: component.get("v.objectName"),
      recordId: component.get("v.recordId"),
      fields: field
    });
    action.setCallback(this, function(response) {
      if (response.getState() !== "SUCCESS") return;
      var result = JSON.parse(response.getReturnValue())[0];
      if (result[field]) {
        component.set("v.showAll", true);
      }
    });
    $A.enqueueAction(action);
  },
  openDialog: function(component) {
    var listAttributesJson = component.get("v.listAttributes");
    var listAttributes = JSON.parse(listAttributesJson);
    var fieldsList = listAttributes.map(function(item) {
      return item.apiName;
    });
    var action = component.get("c.getRecord");
    action.setParams({
      objectName: component.get("v.objectName"),
      recordId: component.get("v.recordId"),
      fields: fieldsList.join(",")
    });
    action.setCallback(this, function(response) {
      if (response.getState() !== "SUCCESS") return;

      var result = JSON.parse(response.getReturnValue())[0];
      listAttributes.forEach(function(item, index) {
        var key = listAttributes[index].apiName;
        if (result[key] !== undefined) {
          listAttributes[index].value = result[key];
        }
      });
      component.set("v.bodyInputFields", listAttributes);
      component.set("v.hide", false);
    });
    $A.enqueueAction(action);
  }
});