({
  doInit: function (component, event, helper) {
    var pageReference = {
      type: "standard__component",
      attributes: {
        componentName: "c__tdrFilters"
      },
      state: {
        c__recordId: component.get("v.recordId")
      }
    };
    var navService = component.find("navService");
    navService.navigate(pageReference);
  }
});