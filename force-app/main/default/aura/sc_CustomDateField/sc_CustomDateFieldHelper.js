({
	validateTheDateFormat : function(dateString) {
        if(dateString === undefined || dateString.length === 0){
            return true;
        }
        var regExpression = "^(((((0[1-9]|1[0-9]|2[0-8])(/|-| )?((0[1-9])|(1[0-2])|(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|January|February|March|April|May|June|July|August|September|October|November|December)))|((29|30|31)(/|-| )?((0[13578])|(1[02])|(Jan|Mar|May|Jul|Aug|Oct|Dec|January|March|May|July|Augus|October|December))(/|-| )?)|((29|30)(/|-| )?((0[469])|11|(Apr|Jun|Sep|Nov|April|June|September|November))))(/|-| )?(([0-9][0-9])?[0-9][0-9]))|(29(/|-| )?(02|Feb|February)(/|-| )?(([0-9][0-9])?(00|04|08|12|16|20|24|28|32|36|40|44|48|52|56|60|64|68|72|76|80|84|88|92|96))))$";
        if(dateString.indexOf("/") !== -1 && dateString.indexOf("/") !== 2){
            return false;
        }
        if(dateString.indexOf("-") !== -1 && dateString.indexOf("-") !== 2){
            return false;
        }
        if(dateString.indexOf(" ") !== -1 && dateString.indexOf(" ") !== 2){
            return false;
        }
        if(dateString.match(/[a-z]|[A-Z]/i)){
            return false;
        }
        var re = new RegExp(regExpression, "i");
        return re.test(dateString);
	},
    calculateFinancialStartDate: function(){
        var date = new Date();
        var calendarStartYear = date.getFullYear();
        var month = date.getMonth();
        if(month < 6) {
			calendarStartYear --;
        }
        return new Date("01/Jul/"+calendarStartYear);
    },
    calculateFinancialEndDate: function(){
        var date = new Date();
        var calendarStartYear = date.getFullYear();
        var month = date.getMonth();
        if(month >= 6) {
			calendarStartYear ++;
        }
        return new Date("30/Jun/"+calendarStartYear);
    },
    validateFinancialDate: function(str){
        var dateValue = this.convertToDate(str);
        var calendarStartDate = this.calculateFinancialStartDate();
        var calendarEndDate = this.calculateFinancialEndDate();
        if(dateValue < calendarStartDate || dateValue > calendarEndDate){
            return false;
        } else {
            return true;
        }
        
	},
    convertToDate : function(str){
        var formatDate = str.replace("/","")
        	.replace("/","").replace("-","")
        	.replace("-","").replace(" ","").replace(" ","");
        
        var isnum = /^\d+$/.test(formatDate);
        if(isnum) {
            var month = formatDate.slice(2,4);
            var year = formatDate.slice(4,str.length);
            var date = formatDate.slice(0,2);
            var dateV = new Date(`${month}\/${date}\/${year}`);
        } else {
            var dateV = new Date(formatDate);
        }
        return dateV;
    },
    convertToFormat: function(d) {
        const offset = d.getTimezoneOffset();
        d = new Date(d.getTime() - (offset*60*1000));
        return d.toISOString().split('T')[0];
    }
})