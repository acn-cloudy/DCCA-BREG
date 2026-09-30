import {LightningElement, api, track} from "lwc";

export default class TDRTable extends LightningElement {
    @api fundsList = [];
    @api paymentType;
    @api cutOffDate;
    @api fundType;
    @api detailFund;
    @api userName;
    tableFundData;
    totalDepositUpdated = false;
    calculatedAmount;

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

    get isCreditCard() {
        return this.paymentType && this.paymentType.toLowerCase() === 'credit card';
    }

    @api getTableData() {
        const allFields = [
            ...this.template.querySelectorAll('[data-type="input"]'),
        ];
        const result = allFields.reduce((res, item) => {
            res[item.name] = item.value;
            return res;
        }, {});

        // get all funds list data
        const allFundElements = [...this.template.querySelectorAll(".fund")];
        result.funds = allFundElements.reduce((res, item) => {
            const allinputfField = [
                ...item.querySelectorAll('input'),
                ...item.querySelectorAll('lightning-input'),
                ...item.querySelectorAll('c-t-d-r-amount-input')
            ];
            const fund = allinputfField.reduce((res, item) => {
                if (item.name === "amount" && !item.value && item.value !== "0") {
                    res[item.name] = null;
                } else {
                    res[item.name] = item.value;
                }
                return res;
            }, {});
            res.push(fund);
            return res;
        }, []);

        // console.warn('result', JSON.stringify(result));
        return result;
    }

    connectedCallback() {
        this.refreshTable();
    }

    @api refreshTable() {
        this.tableFundData = [];
        this.tableFundData = this.fundsListDisplayed();
    }

    fundsListDisplayed() {
        // create an empty array with length 14
        const emptyArr = new Array(14);
        const emptyFund = {
            indexValue: "",
            tcValue: "",
            sValue: "",
            yrValue: "",
            appValue: "",
            dValue: "",
            sourceObjValue: "",
            costCenterValue: "",
            projectNumValue: "",
            projectPhValue: "",
            deptActValue: "",
            gLActValue: "",
            sLActValue: "",
            venterNumValue: "",
            venterSFXValue: "",
            amount: "",
            elemKey: ""
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

        emptyArr.fill(emptyFund);
        emptyArr.forEach(item => {
            item['elemKey'] = Math.random().toString(36).substring(2, 9);
        });
        return res.concat(emptyArr).slice(0, 14);
    }

    handleRowAmountChange(e) {
        this.totalDepositUpdated = true;
        const allRowAmounts = [...this.template.querySelectorAll('[data-role="depositAmount"]')];
        this.calculatedAmount = allRowAmounts.reduce((res, item) => {
            if (!isNaN(parseFloat(item.value))) {
                res += parseFloat(parseFloat(item.value).toFixed(2));
            }

            return res;
        }, 0);
    }

    get totalDeposit() {
        let tempResult =  this.totalDepositUpdated ? this.calculatedAmount.toFixed(2) : this.fundsList.reduce((total, item) => {
            if (item.amount) total += parseFloat(item.amount);
            return total;
        }, 0);

        if (tempResult && !isNaN(tempResult)) {
            if (typeof tempResult === 'string') {
                tempResult = parseFloat(tempResult);
            }

            tempResult = tempResult.toFixed(2);
        }

        return tempResult;
    }
}