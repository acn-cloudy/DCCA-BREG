({
    afterRender: function (cmp) {
        this.superAfterRender();
        cmp.set('v.isDoneInitialRender', true);
    }
})