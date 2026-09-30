import { LightningElement, wire } from "lwc";
import { NavigationMixin, CurrentPageReference } from "lightning/navigation";
import { getObjectInfo } from "lightning/uiObjectInfoApi";
import CASE_OBJECT from "@salesforce/schema/Case";
import warningLabel from "@salesforce/label/c.BREG_Case_RefundRequest_Warning";
import returnToCasesLabel from "@salesforce/label/c.BREG_Case_RefundRequest_ReturnToCases";

const BREG_CASE_RT_NAME = "BREG Case";
const BREG_REFUND_REQUEST_RT_NAME = "BREG Refund Request Case";
const BREG_MANUAL_FILING_FLOW_API_NAME = "BREG_Manual_Filing";

export default class Breg_newCaseButton extends NavigationMixin(LightningElement) {
    isLoading = true;
    isRefundBlocked = false;
    _selectedRecordTypeId;
    _objectInfoData;
    _objectInfoResolved = false;
    _pageRefResolved = false;

    labels = {
        warning: warningLabel,
        returnToCases: returnToCasesLabel
    };

    @wire(CurrentPageReference)
    handlePageReference(pageRef) {
        this._selectedRecordTypeId = pageRef?.state?.recordTypeId;
        this._pageRefResolved = true;
        this._processData();
    }

    @wire(getObjectInfo, { objectApiName: CASE_OBJECT })
    handleObjectInfo({ error, data }) {
        if (data) {
            this._objectInfoData = data;
            this._objectInfoResolved = true;
        }

        this._processData();
    }

    _processData() {
        if (!this._pageRefResolved || !this._objectInfoResolved) {
            return;
        }

        if (this._objectInfoData && this._selectedRecordTypeId) {
            const recordTypeInfos = this._objectInfoData.recordTypeInfos;
            const selectedType = recordTypeInfos[this._selectedRecordTypeId];
            const rtName = selectedType?.name;
            console.log("Selected Record Type Name:", rtName);
            if (rtName === BREG_REFUND_REQUEST_RT_NAME) {
                this.isRefundBlocked = true;
                this.isLoading = false;
                return;
            }

            if (rtName === BREG_CASE_RT_NAME) {
                this.navigateToManualFilingFlow();
                return;
            }
        }

        this.navigateToNewCase();
    }

    navigateToManualFilingFlow() {
        this[NavigationMixin.Navigate]({
            type: "standard__webPage",
            attributes: {
                url: `/flow/${BREG_MANUAL_FILING_FLOW_API_NAME}`
            }
        });
    }

    navigateToNewCase() {
        const state = { nooverride: "1" };
        if (this._selectedRecordTypeId) {
            state.recordTypeId = this._selectedRecordTypeId;
        }
        this[NavigationMixin.Navigate]({
            type: "standard__objectPage",
            attributes: {
                objectApiName: "Case",
                actionName: "new"
            },
            state
        });
    }

    handleReturnToCases() {
        this[NavigationMixin.Navigate]({
            type: "standard__objectPage",
            attributes: {
                objectApiName: "Case",
                actionName: "list"
            },
            state: {
                filterName: "Recent"
            }
        });
    }
}