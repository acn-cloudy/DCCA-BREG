({
	execute : function(action) {
        return new Promise(function(resolve, reject) {
            action.setCallback(this, function(response) {
                var state = response.getState();
                if (state === "SUCCESS") {
                    resolve(response);
                }else if (state === "ERROR") {
                    reject(response);
                }
            });
            $A.enqueueAction(action);
        });
    },
    getJsonFromUrl : function() {
        var query = location.search.substr(1);
        var result = {};
        var _super = this;
        query.split("&").forEach(function(part) {
            var item = part.split("=");
            if(item && item.length > 1)
	            result[_super.replaceAll(item[0], '+',' ')] 
                	= decodeURIComponent(_super.replaceAll(item[1], '+',' '));
        });
        return result;
    },
    replaceAll : function(str, find, replace) {
    	return str.split(find).join(replace)
	},
    checkIsList : function(input) {
        return Object.prototype.toString.call(input) !== '[object Array]';
    }
})