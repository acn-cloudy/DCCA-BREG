({
  getData: function(component) {
    var action = component.get("c.fetchProfile");
    action.setCallback(this, function(response) {
      var profileName = response.getReturnValue();
      var pNameAttrList = component.get("v.profileList");
      var existsInArray = pNameAttrList.some(function(el) {
        return el === profileName;
      });
      // if (existsInArray) {
      component.set("v.showErrorMessage", false);
      var action = component.get("c.loadBatchClassesAsButtons");
      action.setCallback(this, function(response) {
        var resultData = response.getReturnValue();
        var jobNames = component.get("v.jobNames");
        if (jobNames && jobNames.length) {
          let jobList = jobNames.split(",");
          let jobs = jobList.reduce((result, item) => {
            result[item] = true;
            return result;
          }, {});
          component.set(
            "v.batchList",
            resultData.filter(item => jobs[item.MasterLabel])
          );
        } else {
          component.set("v.batchList", resultData);
        }
      });
      $A.enqueueAction(action);
      // } else {
      //   component.set("v.showErrorMessage", true);
      // }
    });

    $A.enqueueAction(action);
  },
  handleButton: function(component, event) {
    var action = component.get("c.runBatchClass");
    var className = event.getSource().get("v.name");
    action.setParams({ batchsetting: className });
    action.setCallback(this, function(response) {
      var resultData = response.getReturnValue();
      alert("Batch job is succesfully queued. ");
    });
    $A.enqueueAction(action);
  }
});