import { LightningElement, api, track, wire} from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import CONTACT_ID from "@salesforce/schema/User.ContactId";
import CONTACT_TYPE from "@salesforce/schema/User.Contact.Type__c";
import USER_ID from "@salesforce/user/Id";

export default class Catv_inetRequestData extends NavigationMixin(LightningElement) {
	@api item;
	showQuoteSubType = false;
	showRequestDate =  true;
	communicationHistoryButtonAriaLabel;
	@track showRequestorDetails = false;
    @track showProviderDetails = false;

	@wire(getRecord, { recordId: USER_ID, fields: [CONTACT_ID, CONTACT_TYPE] })
    wiredRecord({ data}) {
        if (data) {
            let contactType = getFieldValue(data, CONTACT_TYPE); 
			if(contactType == 'Requestor'  && this.item.Provider_Contact_Name__c != null){
                this.showProviderDetails = true;
            }else if(contactType == 'Provider'){
				this.showRequestorDetails = true;
            }
        } 
    }

	connectedCallback() {
		if (this.item.Status__c == 'Draft') {
			this.showRequestDate = false;
		} 
		if (this.item.Status__c == 'Quote') {
			this.showQuoteSubType = true;
		} else {
			this.showQuoteSubType = false;
		}
        this.communicationHistoryButtonAriaLabel = 'Communication History Button ' + this.item.IROC_Id__c
	}

	handleClick(event){
		let state = {
			recordId : this.item.Id
		}
		this.navigateToNamePage('Communications__c', state);
	}

	navigateToNamePage(pageName, pageState){
        this[NavigationMixin.GenerateUrl]({
            type: 'comm__namedPage',
            attributes: {
                name: pageName
            },
            state : pageState
        }).then(url => {
            window.open(url, "_self");
        });
    }

	get providerName(){
		return this.item.Provider_Contact_Name__c && this.item.Provider_Contact_Name__r.Name  ? this.item.Provider_Contact_Name__r.Name  : '';
	}
	get providerEmail(){
		return this.item.Provider_Contact_Name__c && this.item.Provider_Contact_Name__r.Email  ? this.item.Provider_Contact_Name__r.Email  : '';
	}
	get providerPhone(){
		return this.item.Provider_Contact_Name__c && this.item.Provider_Contact_Name__r.Phone  ? this.item.Provider_Contact_Name__r.Phone  : '';
	}

	get requestor(){
		return this.item.Requestor__c && this.item.Requestor__r.Name? this.item.Requestor__r.Name  : '';
	}
	get requestorName(){
		return this.item.Requestor__c && this.item.Requestor_Contact_Name__r.Name? this.item.Requestor_Contact_Name__r.Name  : '';
	}
	get requestorEmail(){
		return this.item.Requestor_Contact_Name__c && this.item.Requestor_Contact_Name__r.Email? this.item.Requestor_Contact_Name__r.Email  : '';
	}
	get requestorPhone(){
		return this.item.Requestor_Contact_Name__c && this.item.Requestor_Contact_Name__r.Phone? this.item.Requestor_Contact_Name__r.Phone  : '';
	}
}