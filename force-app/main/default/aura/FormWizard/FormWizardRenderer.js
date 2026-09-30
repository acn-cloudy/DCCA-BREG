({
    afterRender: function (cmp, helper) {
        this.superAfterRender();
        helper.toggleSections(cmp);
    }
})