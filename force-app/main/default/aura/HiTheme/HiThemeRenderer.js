({

    // Your renderer method overrides go here
    render : function(cmp, helper) {
        var ret = this.superRender();
        if( window.location.pathname == '/catv/s/error' || window.location.pathname == '/catv/s/registration'){
            cmp.set("v.headerHide",false);
        }
        return ret;
    },
})