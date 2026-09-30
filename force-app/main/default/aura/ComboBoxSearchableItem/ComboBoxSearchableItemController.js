({
    select: function (cmp, event) {
        var cb = cmp.get('v.onclick');
        var params = {
            label: cmp.get('v.label'),
            value: cmp.get('v.value')
        };

        cb(params);
    }
})