({
    gotoURL : function(component, event, helper) {
        var eUrl= $A.get("e.force:navigateToURL");
        eUrl.setParams({
            "url": '/apex/dsfs__CreateEnvelopeFromAccount?SourceID=00135000008JtAYAA0&CCRM=Decision Maker~Signer 1&CCTM=Decision Maker~Signer&DST=a2e2cd02-f11e-4c8c-a830-c9f2b6564a9e&LA=0&LF=0&OCO=Tag'
        });
        eUrl.fire();      
    }
})