({
    updateTransaction: function (component) {
        const action = component.get("c.updateTempPayment");
        const paymentType = component.get("v.paymentType");
        const memo = component.get("v.memo");
        const recordId = component.get("v.recordId");
        action.setParams({ recordId, paymentType, memo });
        action.setCallback(this, function (res) { console.log("res", res.getState()) });
        $A.enqueueAction(action);
    },
})