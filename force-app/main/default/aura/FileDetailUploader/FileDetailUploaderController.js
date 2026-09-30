({
    handleLoad: function (cmp) {
        cmp.set('v.showSpinner', false);
    },

    handleSubmit: function (cmp) {
        cmp.set('v.disabled', true);
        cmp.set('v.showSpinner', true);
    },

    handleError: function (cmp) {
        // errors are handled by lightning:inputField and lightning:nessages
        // so this just hides the spinnet
        cmp.set('v.showSpinner', false);
    },

    handleSuccess: function (cmp, event) {
        var params = event.getParams();
        cmp.set('v.recordId', params.response.id);
        cmp.set('v.showSpinner', false);

        var navigate = cmp.get('v.navigateFlow');
        navigate("NEXT");
    }
})