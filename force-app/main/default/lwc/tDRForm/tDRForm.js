import {LightningElement, api, track, wire} from "lwc";
import {getRecord} from "lightning/uiRecordApi";
import UserId from "@salesforce/user/Id";
import UserFullName from "@salesforce/schema/User.Name";
import search from "@salesforce/apex/TDRFormController.searchData";
import submit from "@salesforce/apex/TDRFormController.submitForFile";
import generateFile from "@salesforce/apex/TDRFormController.saveAsFile";
import getDepositOptions from "@salesforce/apex/TDRFormController.getTdrDepositOptions";
import {NavigationMixin} from "lightning/navigation";
import {ShowToastEvent} from "lightning/platformShowToastEvent";

export default class TDRForm extends NavigationMixin(LightningElement) {
    @api recordId;
    @api recordTypeId;
    detailFund;
    displayItems;
    paymentType;
    fundType;
    fundTypeUpper;
    showLoading;
    tDRTableFundsList = [[]];
    userName;
    error;
    division = 'DCCA';
    isSpecial = false;
    isTrust = false;
    isCreditCard = false;
    fundAccounts;
    selectedDeposits;
    tempSpecialOptions = {
        'S-302': 'S-302 - CABLE TELEVISION DIVISION',
        'S-303': 'S-303 - CONSUMER ADVOCACY',
        'S-305': 'S-305 - PROFESSIONAL & VOCATIONAL LICENSING CRF',
        'S-306': 'S-306 - BUSINESS REGISTRATION - CRF',
        'S-307': 'S-307 - POST SECONDARY EDUCATION',
        'S-309': 'S-309 - DRIVERS EDUCATION FUND',
        'S-310': 'S-310 - ADMINISTRATION',
        'S-312': 'S-312 - COMPLIANCE RESOLUTION FUNDS - RICO',
        'S-313': 'S-313 - INSURANCE REGULATION FUND',
        'S-316': 'S-316 - MORTGAGE FORECLOSURE DISPUTE RESOLUTION',
        'S-317': 'S-317 - CAPTIVE INSURANCE',
        'S-320': 'S-320 - FINANCIAL INSTITUTIONS DIVISION',
        'S-323': 'S-323 - COMPLIANCE RESOLUTION FUNDS - OCP'
    };
    pucSpecialOptions = {
        'S-340': 'S-340'
    };
    tempGeneralOptions = {'G-000': 'G-000 - GENERAL FUND REVENUES'};
    tempTrustOptions = {
        'T-902': 'T-902',
        'T-904': 'T-904',
        'T-905': 'T-905',
        'T-906': 'T-906',
        'T-907': 'T-907',
        'T-908': 'T-908',
        'T-909': 'T-909',
        'T-915': 'T-915',
        'T-916': 'T-916',
        'T-917': 'T-917',
        'T-919': 'T-919',
        'T-920': 'T-920',
        'T-921': 'T-921',
        'T-922': 'T-922',
        'T-925': 'T-925',
        'T-927': 'T-927',
        'T-928': 'T-928',
        'T-930': 'T-930',
        'T-931': 'T-931'
    }
    depositOptions = [{'test':'test'}];

    cutOffDate;
    startDate;

    fundTypeOptions = [];

    regularFundTypeOptions = [
        {value: '', label: 'None'},
        {label: 'General', value: 'General'},
        {label: 'Special', value: 'Special'},
        {label: 'Trust', value: 'Trust'}
    ];

    pucFundTypeOptions = [
        {label: 'Special', value: 'Special'}
    ];

    ptOptions = [];

    pucPaymentTypeOptions = [
        {label: "Credit Card", value: "Credit Card"},
    ];

    regularPaymentTypeOptions = [
        {value: "", label: "None"},
        {label: "Credit Card", value: "Credit Card"},
        {label: "Cash", value: "Cash"},
        {label: "EFT", value: "EFT"}
    ];

    divisionOptions = [
        {value: 'DCCA', label: 'DCCA'},
        {value: 'PUC', label: 'PUC'}
    ];

    @wire(getRecord, {recordId: UserId, fields: [UserFullName]})
    userDetails({error, data}) {
        if (error) {
            this.error = error;
        } else if (data) {
            if (data.fields.Name.value != null) {
                this.userName = data.fields.Name.value;
            }
        }
    }

    @wire(getDepositOptions)
    wiredDepositOptions({error, data}) {
        if (error) {
            this.error = error;
        } else if (data) {
          this.depositOptions = data;
        }
    }

    get fundAccountOptions() {
        let tempFundAccountOptions, result = [];
        if (this.fundType === 'General') {
            tempFundAccountOptions = this.tempGeneralOptions;
        }

        if (this.fundType === 'Special') {
            tempFundAccountOptions = this.tempSpecialOptions;
            if (this.division === 'PUC') {
                tempFundAccountOptions = this.pucSpecialOptions;
            }
        }

        if (this.fundType === 'Trust') {
            tempFundAccountOptions = this.tempTrustOptions;
        }

        for (const key in tempFundAccountOptions) {
            if (tempFundAccountOptions.hasOwnProperty(key)) {
                let fundAccountOption = {label: tempFundAccountOptions[key], value: key};
                result.push(fundAccountOption);
            }
        }

        return result;
    }

    formatFundsList(fundsList) {
        const res = [];
        const chunk = 14;
        for (let i = 0; i < fundsList.length; i += chunk) {
            res.push(fundsList.slice(i, i + chunk));
        }
        return res;
    }

    connectedCallback() {
        //this.division = 'DCCA';
        this.fundTypeOptions = this.regularFundTypeOptions;
        this.ptOptions = this.regularPaymentTypeOptions;
    }

    handleFundType(e) {
        this.fundType = e.currentTarget.value;
        this.isSpecial = this.fundType === 'Special' || this.fundType === 'General';
        this.isTrust = this.fundType === 'Trust';
    }

    handleDepositsChange(e) {
        const tempVal = e.detail.value;
        this.selectedDeposits = Array.isArray(tempVal) ? JSON.stringify(tempVal) : tempVal;
    }

    handleFundAccountChange(e) {
        const tempVal = e.detail.value
        this.fundAccounts = Array.isArray(tempVal) ? JSON.stringify(tempVal) : tempVal;
    }

    handlePT(e) {
        this.paymentType = e.currentTarget.value;
        let dateOptions = this.template.querySelectorAll('[data-role="dateOptions"]');
        this.isCreditCard = this.paymentType === 'Credit Card';
        if (this.isCreditCard) {
            this.startDate = null;
            this.cutOffDate = null;
        }
    }

    handleDivisions(e) {
        this.division = e.currentTarget.value;

        if (this.division === 'PUC') {
            this.fundTypeOptions = this.pucFundTypeOptions;
            this.fundType = 'Special'
            this.handleFundType({currentTarget: {value: 'Special'}});
            this.fundAccounts = 'S-340';
            this.ptOptions = this.pucPaymentTypeOptions;
            this.paymentType = 'Credit Card';

            let __self = this;
            setTimeout(() => {
                __self.template.querySelector('[data-role="fundTypeOptions"]').style.display = "none";
                let fundAccountOptionsSpecial = __self.template.querySelector('[data-role="fundAccountOptionsSpecial"]');
                if (fundAccountOptionsSpecial) {
                    fundAccountOptionsSpecial.style.display = "none";
                }
                __self.template.querySelector('[data-role="paymentTypeOptions"]').style.display = "none";
            }, 100);

        } else {
            this.fundTypeOptions = this.regularFundTypeOptions;
            this.fundType = '';
            this.fundAccounts = '';
            this.handleFundType({currentTarget: {value: ''}});
            this.ptOptions = this.regularPaymentTypeOptions;
            this.paymentType = '';
            let __self = this;
            setTimeout(() => {
                __self.template.querySelector('[data-role="fundTypeOptions"]').style.display = "";
                let fundAccountOptionsSpecial = __self.template.querySelector('[data-role="fundAccountOptionsSpecial"]');
                if (fundAccountOptionsSpecial) {
                    fundAccountOptionsSpecial.style.display = "";
                }
                __self.template.querySelector('[data-role="paymentTypeOptions"]').style.display = "";
            }, 100);
        }
    }

    handleSearch() {
        this.tDRTableFundsList = [];
        const {fundType, paymentType, cutOffDate, startDate, fundAccounts, division, selectedDeposits} = this;
        if (fundType) {
            this.fundTypeUpper = fundType.toUpperCase();
        }

        if (!this.isCreditCard && (!startDate || !cutOffDate)) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Error",
                    message: "Start Date and Cut Off Date are required.",
                    variant: "error"
                })
            );
            return;
        }

        if (!this.isCreditCard && (startDate > cutOffDate)) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Error",
                    message: "Start Date must be prior to Cut Off Date.",
                    variant: "error"
                })
            );
            return;
        }

        if (this.isCreditCard && !this.selectedDeposits) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Error",
                    message: "Please select at least one deposit.",
                    variant: "error"
                })
            );
            return;
        }

        this.showLoading = true;

        const searchFeed = {
            fundType,
            paymentType,
            cutOffDate,
            startDate,
            fundAccounts,
            division,
            selectedDeposits
        };

        if (this.fundAccounts && this.fundAccounts.length) {
            let tempFundType = fundType.toLowerCase();
            let tempOptions = (this.division === 'PUC') ? this.pucSpecialOptions : this.tempSpecialOptions;
            if (tempFundType === 'general' || tempFundType === 'special') {
                tempOptions = (tempFundType === 'general') ? this.tempGeneralOptions : tempOptions;
                if (this.fundAccounts) {
                    this.detailFund = tempOptions[this.fundAccounts].substring(8);
                }
            }

            if (tempFundType === 'trust' && this.fundAccounts) {
                let selectedFundAccounts = JSON.parse(this.fundAccounts);
                let tempDetailFund = [];
                tempDetailFund.push(selectedFundAccounts.shift());
                selectedFundAccounts.forEach((val) => {
                    tempDetailFund.push(val.substring(2));
                });
                this.detailFund = tempDetailFund.join();
            }
        }

        if (!fundType) this.fundType = "";
        const feedStr = JSON.stringify(searchFeed);
        search({feedStr}).then((response) => {
            this.tDRTableFundsList = this.formatFundsList(JSON.parse(response));
            if (this.tDRTableFundsList.length) {
                this.displayItems = true;
            } else {
                this.displayItems = false;
            }
            this.showLoading = false;
            const tableElements = this.template.querySelectorAll("c-t-d-r-table");
            tableElements.forEach(function (item) {
                item.refreshTable();
            });
        });
    }

    retrieveTablesData() {
        const tableData = [];
        const tableElements = this.template.querySelectorAll("c-t-d-r-table");
        tableElements.forEach(function (item) {
            tableData.push(item.getTableData());
        });
        return tableData;
    }

    handleSubmit(e) {
        const {
            recordTypeId,
            recordId,
            fundType,
            paymentType,
            cutOffDate,
            startDate,
            division
        } = this;
        const searchFeed = {
            fundType,
            paymentType,
            cutOffDate,
            startDate,
            division
        };

        this.showLoading = true;
        const tableData = this.retrieveTablesData();
        const str = JSON.stringify(tableData);

        const feedStr = JSON.stringify(searchFeed);

        submit({str, recordTypeId, feedStr, recordId}).then((recordId) => {
            this.recordId = recordId;
            generateFile({recordId}).then(() => {
                this.showLoading = false;
                const pageRef = {
                    type: "standard__recordPage",
                    attributes: {
                        recordId: recordId,
                        objectApiName: "CollectionsAllocation__c",
                        actionName: "view"
                    }
                };
                this.clearData();
                this[NavigationMixin.Navigate](pageRef);
            });
        });
    }

    handleStartDate(e) {
        this.startDate = e.currentTarget.value;
    }

    handleCutOffDate(e) {
        this.cutOffDate = e.currentTarget.value;
    }

    handleNewPage(e) {
        let tempFundList = this.tDRTableFundsList;
        this.tDRTableFundsList = [[]];
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
            elemKey: Math.random().toString(36).substring(2, 9)
        };
        tempFundList.push([emptyFund]);
        this.tDRTableFundsList = tempFundList;
    }

    @api clearData() {
        this.detailFund = undefined;
        this.displayItems = undefined;
        this.paymentType = undefined;
        this.fundType = undefined;
        this.showLoading = undefined;
        this.division = undefined;
        this.cutOffDate = undefined;
        this.startDate = undefined;
        this.recordId = undefined;
        this.tDRTableFundsList = [[]];
    }
}