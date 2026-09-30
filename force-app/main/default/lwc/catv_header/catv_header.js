/**
 * @description       : 
 * @author            : Gaurav Agarwal
 * @group             : 
 * @last modified on  : 05-13-2025
 * @last modified by  : Gaurav Agarwal
**/
import { LightningElement, track, wire } from 'lwc';
import MDS_Style from '@salesforce/resourceUrl/MDS_Style'; 
import USER_ID from '@salesforce/user/Id';
import NAME_FIELD from '@salesforce/schema/User.Name';
import { getRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { NavigationMixin, CurrentPageReference } from "lightning/navigation";
import getParentId from '@salesforce/apex/CATV_WithoutSharingUtility.getParentId';

export default class Catv_header extends NavigationMixin(LightningElement) {
    mdsLogo = MDS_Style + '/media/images/dcca-logo-white.png';
    // profileImage = MDS_Style + '/media/images/profileImg.svg';
    profileImage = MDS_Style + '/media/images/profile_avatar.svg';

    @track loggedInUserName;
    @track showLogoutConfirmationModal = false;
    @track currentIntake;
    @wire(CurrentPageReference) pageRef;
    feedItemId;
    parentId;

    @wire(getRecord, {
        recordId: USER_ID,
        fields: [NAME_FIELD]
    }) wireuser({
        error,
        data
    }) {
        if (error) {
            this.handleError(error);
        } else if (data) {
            this.loggedInUserName = data.fields.Name.value;
        }
    }

    connectedCallback(){
        this.currentIntake = this.pageRef.attributes.name;
        // Get the full URL
        const currentUrl = window.location.href;
        
        // Extract path after `/detail/`
        const match = currentUrl.match(/\/detail\/([a-zA-Z0-9]{15,18})/);
        
        if (match && match[1]) {
            this.feedItemId = match[1];
            if (this.feedItemId) {
                getParentId({ feedItemId: this.feedItemId })
                    .then(result => {
                        this.parentId = result;
                        let state = {
                            recordId : this.parentId
                        }
                        this.navigateToNamePage('Communications__c', state);
                    })
                    .catch(error => {
                        console.error('Error fetching parentId', error);
                    });
            }
            
        } else {
            console.error('FeedItem Id not found in URL');
        }
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

    handleLogout(){
        this.showLogoutConfirmationModal = true;
    }

    handleConfirmLogout() {
        sessionStorage.clear();
        window.open("../secur/logout.jsp", '_self');
    }

    closeLogoutConfirmationModal() {
        this.showLogoutConfirmationModal = false;
    }

    handleHome(){
        this[NavigationMixin.GenerateUrl]({
            type: "standard__namedPage",
            attributes: {
                pageName: 'home'
            }
        }).then(url => {
            window.open(url, "_self");
        });
    }

    handleError(error) {
        let errorMessage = 'Something went wrong!!';
        if (error?.body?.message) {
            errorMessage = error.message || error.body.message;
        }
        this.showToast("Error", errorMessage, "error");
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }

    get showSubHeader(){
        return this.currentIntake == 'Communications__c';
    }
}