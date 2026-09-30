({
  initRecordTypes: function (component) {
    // clear all the data
    component.set("v.recordType", null);
    component.set("v.recordTypeId", null);
    const params = window.location.search
      .substring(1)
      .split("&")
      .reduce((results, item) => {
        results[item.split("=")[0]] = item.split("=")[1];
        return results;
      }, {});
    const { recordTypeId } = params;
    component.set("v.recordTypeId", recordTypeId);
    const action = component.get("c.getRecordType");
    action.setParams({ recordTypeId });
    this.execute(action).then((response) => {
      const recordTypeName = response.getReturnValue();
      component.set("v.recordType", recordTypeName);
    });
  }
});