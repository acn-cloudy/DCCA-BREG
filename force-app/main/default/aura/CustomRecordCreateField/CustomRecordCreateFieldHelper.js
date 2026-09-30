({
  emailIsValid: function (email) {
    var re = new RegExp(
      '^(([^<>()[\\]\\\\.,;:\\s@\\"]+(\\.[^<>()[\\]\\\\.,;:\\s@\\"]+)*)|(\\".+\\"))@((\\[[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\])|(([a-zA-Z\\-0-9]+\\.)+[a-zA-Z]{2,}))$'
    );
    return re.test(email);
  },

  phoneIsValid: function (phone) {
    var re = new RegExp(
      "^([\\(]{1}[0-9]{3}[\\)]{1}[\\.| |\\-]{0,1}|^[0-9]{3}[\\.|\\-| ]?)?[0-9]{3}(\\.|\\-| )?[0-9]{4}$"
    );
    return re.test(phone);
  },

  showToastMessage: function (type, title, message, mode) {
    var toastEvent = $A.get("e.force:showToast");
    toastEvent.setParams({
      type: type,
      title: title,
      message: message,
      mode: mode
    });
    toastEvent.fire();
  },
  validateTheDateFormat: function (dateString) {
    if (dateString === undefined || dateString.length === 0) {
      return true;
    }
    var regExpression =
      "^(((((0[1-9]|1[0-9]|2[0-8])(/|-| )?((0[1-9])|(1[0-2])|(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|January|February|March|April|May|June|July|August|September|October|November|December)))|((29|30|31)(/|-| )?((0[13578])|(1[02])|(Jan|Mar|May|Jul|Aug|Oct|Dec|January|March|May|July|Augus|October|December))(/|-| )?)|((29|30)(/|-| )?((0[469])|11|(Apr|Jun|Sep|Nov|April|June|September|November))))(/|-| )?(([0-9][0-9])?[0-9][0-9]))|(29(/|-| )?(02|Feb|February)(/|-| )?(([0-9][0-9])?(00|04|08|12|16|20|24|28|32|36|40|44|48|52|56|60|64|68|72|76|80|84|88|92|96))))$";
    if (dateString.indexOf("/") !== -1 && dateString.indexOf("/") !== 2) {
      return false;
    }
    if (dateString.indexOf("-") !== -1 && dateString.indexOf("-") !== 2) {
      return false;
    }
    if (dateString.indexOf(" ") !== -1 && dateString.indexOf(" ") !== 2) {
      return false;
    }
    if (dateString.match(/[a-z]|[A-Z]/i)) {
      return false;
    }
    var re = new RegExp(regExpression, "i");
    return re.test(dateString);
  }
});