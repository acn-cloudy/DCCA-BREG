({
  doInit: function (component, event, helper) {
    helper.initRecordTypes(component);
  },
  clearData: function (component, event, helper) {
    component.find("form").clearData();
    helper.initRecordTypes(component);
  }
});