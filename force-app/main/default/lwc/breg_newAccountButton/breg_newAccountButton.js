import { LightningElement, wire } from "lwc";
import { NavigationMixin, CurrentPageReference } from "lightning/navigation";
import { getObjectInfo } from "lightning/uiObjectInfoApi";
import ACCOUNT_OBJECT from "@salesforce/schema/Account";
import errorLabel from "@salesforce/label/c.BREG_Account_AccessDenied_Error";
import messageLabel from "@salesforce/label/c.BREG_Account_AccessDenied_Message";
import returnToAccountsLabel from "@salesforce/label/c.BREG_Account_AccessDenied_ReturnToAccounts";

const MEMBER_RECORD_TYPE_NAME = "BREG Member Account";
const BREG_ACCOUNT_RECORD_TYPE_NAME = "BREG Account";
export default class Breg_newAccountButton extends NavigationMixin(LightningElement) {
    isLoading = true;
    isBregAccountType = false;
    _selectedRecordTypeId;
    _objectInfoData;
    _objectInfoResolved = false;
    _pageRefResolved = false;

    labels = {
        error: errorLabel,
        message: messageLabel,
        returnToAccounts: returnToAccountsLabel
    };

    get isBlocked() {
        return this.isBregAccountType;
    }

    @wire(CurrentPageReference)
    handlePageReference(pageRef) {
        this._selectedRecordTypeId = pageRef?.state?.recordTypeId;
        this._pageRefResolved = true;
        this._processData();
    }

    @wire(getObjectInfo, { objectApiName: ACCOUNT_OBJECT })
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
            if (selectedType?.name === BREG_ACCOUNT_RECORD_TYPE_NAME || selectedType?.name === MEMBER_RECORD_TYPE_NAME) {
                this.isBregAccountType = true;
            }
        }

        this.isLoading = false;
        if (!this.isBregAccountType) {
            this.navigateToNewAccount();
        }
    }

    navigateToNewAccount() {
        const state = { nooverride: "1" };
        if (this._selectedRecordTypeId) {
            state.recordTypeId = this._selectedRecordTypeId;
        }
        this[NavigationMixin.Navigate]({
            type: "standard__objectPage",
            attributes: {
                objectApiName: "Account",
                actionName: "new"
            },
            state
        });
    }

    handleReturnToAccounts() {
        this[NavigationMixin.Navigate]({
            type: "standard__objectPage",
            attributes: {
                objectApiName: "Account",
                actionName: "list"
            },
            state: {
                filterName: "Recent"
            }
        });
    }
}