import { LightningElement, api, track } from "lwc";

export default class JVTable extends LightningElement {
  @api fundsList = [];
  @api recordTypeId;
  @api cutOffDate;
  @api fundType;
  @track defaultExplanation =
    "TO CORRECT THE ACCOUNT FOR BAD CHECKS: \r\n\r\n\r\n\r\n  CC:DCCA/FISCAL";
  get dateValue() {
    let d = new Date();
    const monthStrs = [
      "01",
      "02",
      "03",
      "04",
      "05",
      "06",
      "07",
      "08",
      "09",
      "10",
      "11",
      "12"
    ];
    console.log("cut off date", this.cutOffDate);
    // if (this.cutOffDate) {
    //   const dates = this.cutOffDate.split("-");
    let dayValue = d.getDate() + "";
    if (dayValue.length === 1) {
      dayValue = "0" + dayValue;
    }
    return monthStrs[d.getMonth()] + "/" + dayValue + "/" + d.getFullYear();
    // }
    // return this.cutOffDate;
  }
  get dateValue() {
    console.log("cut off date", this.cutOffDate);
    if (this.cutOffDate) {
      const dates = this.cutOffDate.split("-");
      return dates[1] + "/" + dates[2] + "/" + dates[0];
    }
    return this.cutOffDate;
  }

  get fundsListDisplayed() {
    // create an empty array with length 14

    const emptyFund = {
      indexValue: "",
      tcValue: "",
      fValue: "",
      yrValue: "",
      appValue: "",
      dValue: "",
      alltCatValue: "",
      sourceObjValue: "",
      costCenterValue: "",
      projectNumValue: "",
      projectPhValue: "",
      deptActValue: "",
      gLActValue: "",
      sLActValue: "",
      referenceNumValue: "",
      referenceSFXValue: "",
      jVAmount1: "",
      jVAmount2: "",
      modValue: "",
      revValue: "",
      optionalDepartmentalDate: "",
      remarks: ""
    };

    const res = this.fundsList.map((item) => {
      for (var property in emptyFund) {
        // add not exist key
        if (!item.hasOwnProperty(property)) {
          item[property] = "";
        }
      }
      return item;
    });

    const emptyArr = new Array(14);
    emptyArr.fill(emptyFund);

    return res.concat(emptyArr).slice(0, 14);
  }

  @api getTableData() {
    const allFields = [
      ...this.template.querySelectorAll('[data-type="input"]'),
      ...this.template.querySelectorAll("textarea")
    ];
    const result = allFields.reduce((res, item) => {
      res[item.name] = item.value;
      if (item.name === "explanation" && item.value) {
        res[item.name] = item.value.replace(/\n/g, "<br/>");
      }
      return res;
    }, {});

    // get all funds list data
    const allFundElements = [...this.template.querySelectorAll(".fund")];
    result.funds = allFundElements.reduce((res, item) => {
      const allinputfField = [
        ...item.querySelectorAll("input"),
        ...item.querySelectorAll("lightning-input")
      ];
      const fund = allinputfField.reduce((res, item) => {
        if (item.name === "amount" && !item.value) {
          res[item.name] = 0;
        } else {
          res[item.name] = item.value;
        }
        return res;
      }, {});
      fund.recordId = item.title;
      res.push(fund);
      return res;
    }, []);

    // console.warn('result', JSON.stringify(result));
    return result;
  }
}