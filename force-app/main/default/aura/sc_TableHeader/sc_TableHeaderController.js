({
	setOrderBy : function(component, event, helper) {
		console.log('setorderby');
        var sortSeq = "";
        if($A.util.hasClass(component.find("arrowUp"), "hiddenIcon")){
            $A.util.removeClass(component.find("arrowUp"), "hiddenIcon");
            $A.util.addClass(component.find("arrowDown"), "hiddenIcon");   
            sortSeq = "down";
        } else {
            $A.util.removeClass(component.find("arrowDown"), "hiddenIcon");
            $A.util.addClass(component.find("arrowUp"), "hiddenIcon");
            sortSeq = "up";
        }
        var compEvent = component.getEvent("clearArrows");
        var payload = {};
        payload.localId = component.getLocalId();
        payload.sortSeq = sortSeq;
		compEvent.setParams({
            "type" : "clear-sorts",
            "payload" : payload
        });
        compEvent.fire();
	}
})