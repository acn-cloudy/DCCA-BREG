({
	recordDate : function() {
		var date = new Date();
        var month = date.getMonth();
        month ++;
        month = month + "";
        var dat = date.getDate() + "";
        
        if(dat.length == 1) {
            dat = "0" + dat;
        }
        
        if(month.length == 1) {
            month = "0" + month;
        }
        return dat + "/"+ month + "/"+ date.getFullYear();
	}
})