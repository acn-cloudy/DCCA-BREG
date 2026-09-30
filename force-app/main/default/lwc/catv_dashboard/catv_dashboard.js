import { LightningElement, track, wire } from 'lwc';
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import CONTACT_ID from "@salesforce/schema/User.ContactId";
import ACCOUNT_ID from "@salesforce/schema/User.AccountId";
import CONTACT_TYPE from "@salesforce/schema/User.Contact.Type__c";
import CatvDashboardMessage from '@salesforce/label/c.Catv_DashboardMessage';

// this gets you the logged in user
import USER_ID from "@salesforce/user/Id";
export default class Catv_dashboard extends LightningElement {
    contact;
    account;
    @track showRequestorTab = false;
    @track showProviderTab = false;
    message = CatvDashboardMessage;
    

    @wire(getRecord, { recordId: USER_ID, fields: [CONTACT_ID, ACCOUNT_ID, CONTACT_TYPE] })
    wiredRecord({ data}) {
        if (data) {
            this.contact = getFieldValue(data, CONTACT_ID); 
            this.account = getFieldValue(data, ACCOUNT_ID); 
            let contactType = getFieldValue(data, CONTACT_TYPE); 
            if(contactType == 'Requestor'){
                this.showRequestorTab = true;
            }else if(contactType == 'Provider'){
                this.showProviderTab = true;
            }
        } 
    }
}