import { LightningElement, api, track } from "lwc";
import search from "@salesforce/apex/FiscalFormsController.searchJVData";
import submit from "@salesforce/apex/FiscalFormsController.submitForFile";
import generateFile from "@salesforce/apex/FiscalFormsController.saveJVFile";
import { NavigationMixin } from "lightning/navigation";
export default class JVForm extends NavigationMixin(LightningElement) {
  @api recordTypeId;
  @api recordId;
  @track displayItems;
  @track paymentType;
  @track fundType;
  @track showLoading;
  @track tDRTableFundsList = [[]];

  @track division;
  @track startDate;
  @track cutOffDate;
  @track fundTypeOptions = [
    { value: "", label: "None" },
    {
      label: "General",
      value: "General"
    },
    {
      label: "Special",
      value: "Special"
    },
    {
      label: "Trust",
      value: "Trust"
    }
  ];
  divisionOptions = [
    { value: "", label: "None" },
    { value: "BREG", label: "BREG" },
    { value: "CAP", label: "CAP" },
    { value: "CATV", label: "CATV" },
    { value: "DFI", label: "DFI" },
    { value: "General", label: "General" },
    { value: "HPEAP", label: "HPEAP" },
    { value: "Insurance", label: "Insurance" },
    { value: "OAH", label: "OAH" },
    { value: "OCP", label: "OCP" },
    { value: "PUC", label: "PUC" },
    { value: "PVL", label: "PVL" },
    { value: "PVL Real Estate", label: "PVL Real Estate" },
    { value: "RICO", label: "RICO" }
  ];
  ptOptions = [
    { value: "", label: "None" },
    {
      label: "Credit Card",
      value: "Credit Card"
    },
    {
      label: "Cash",
      value: "Cash"
    },
    {
      label: "EFT",
      value: "EFT"
    }
  ];

  formatFundsList(fundsList) {
    fundsList.forEach((fund) => {
      if (fund.jVAmount2 !== null) {
        fund.jVAmount2 += "";
        if (fund.jVAmount2.length === 1) {
          fund.jVAmount2 = fund.jVAmount2 + "0";
        }
      }
    });
    const res = [];
    const chunk = 14;
    for (let i = 0; i < fundsList.length; i += chunk) {
      res.push(fundsList.slice(i, i + chunk));
    }
    return res;
  }

  handleFundType(e) {
    console.log("e", e);
    this.fundType = e.currentTarget.value;
  }
  handlePT(e) {
    console.log("e", e);
    this.paymentType = e.currentTarget.value;
  }
  handleDivisions(e) {
    console.log("e", e);
    this.division = e.currentTarget.value;
  }
  handleSearch() {
    const { fundType, paymentType, cutOffDate, startDate, division } = this;
    if (!fundType) this.fundType = "";
    console.log("startDate", startDate);
    console.log("cutOffDate", cutOffDate);
    if (!startDate || !cutOffDate) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: "Start Date and Cut Off Date is required!",
          variant: "error"
        })
      );
      return;
    }
    if (startDate > cutOffDate) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: "Start Date must be in prior to Cut Off Date!",
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
      division
    };
    const feedStr = JSON.stringify(searchFeed);
    search({ feedStr }).then((response) => {
      console.log("response", response);

      if (JSON.parse(response).length > 0) {
        this.displayItems = true;
      } else {
        this.displayItems = false;
      }
      this.tDRTableFundsList = this.formatFundsList(JSON.parse(response));

      this.showLoading = false;
    });
    this.paymentType;
  }

  retrieveTablesData() {
    const tableData = [];
    const tableElements = this.template.querySelectorAll("c-j-v-table");
    tableElements.forEach(function (item) {
      tableData.push(item.getTableData());
    });
    return tableData;
  }

  handleSubmit(e) {
    this.showLoading = true;
    const tableData = this.retrieveTablesData();
    console.warn("tableData", JSON.stringify(tableData));

    const str = JSON.stringify(tableData);
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
    const feedStr = JSON.stringify(searchFeed);
    submit({ str, recordId, recordTypeId, feedStr }).then((recordId) => {
      console.log("recordId", recordId);
      generateFile({ recordId }).then(() => {
        console.log("success");
        this.showLoading = false;
        this.clearData();
        const pageRef = {
          type: "standard__recordPage",
          attributes: {
            recordId: recordId,
            objectApiName: "CollectionsAllocation__c",
            actionName: "view"
          }
        };
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