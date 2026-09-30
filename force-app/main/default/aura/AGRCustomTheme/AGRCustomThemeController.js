({
	doInit: function(component, event, helper) {
    	var homeURL = "";
    	var pathArray = location.href.split('/');

    	if (location.href.includes('one.app')) {
      		homeURL = pathArray[0] + '//' + pathArray[2] + '/one/one.app?source=aloha#/sObject/';
    	} else if (location.href.includes('/s/')) {
      		homeURL = pathArray[0] + '//' + pathArray[2] + '/' + pathArray[3] + '/';
    	}

    	component.set("v.HomePage", homeURL);
    },
    
    scriptsLoaded: function(component, event, helper) {
        
        setTimeout(function() {
            component.set("v.HidePage", "false");
        }, 1500);
        
    }
})