({
    doInit: function (component, event, helper) {
        helper.getData(component);
    },
    handleClick: function (component, event, helper) {
        event.getSource().set("v.disabled", true);
        helper.handleButton(component, event);
    },
    showAttestMailing: function (cmp) {
        cmp.set('v.showAttestSpinner', true);
        let overlayLib = cmp.find('overlayLib');
        $A.createComponent('c:attestToMailingNotices', {
            oncancel: cmp.getReference('c.cancelAttestMailing'),
            onconfirm: cmp.getReference('c.confirmAttestMailing')
        }, (content, status) => {
            if (status === 'SUCCESS') {
                let modalBody = content;
                overlayLib.showCustomModal({
                    header: 'Attest to Mailing Notices',
                    body: content,
                    cssClass: 'slds-modal_small',
                    showCloseButton: false
                }).then(overlay => {
                    cmp.__overLay = overlay;
                });
            }
            cmp.set('v.showAttestSpinner', false);
        });
    },
    cancelAttestMailing: function (cmp, event) {
        cmp.__overLay.close();
    },
    confirmAttestMailing: function (cmp) {
        cmp.__overLay.close();
        alert("Batch job is succesfully queued.");
    }
})