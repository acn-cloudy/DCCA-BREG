import { LightningElement, wire } from "lwc";
import isHomeWarningBannerEnabled from "@salesforce/apex/BREGPortalUtils.isHomeWarningBannerEnabled";
import BREG_HOME_WARNING_TITLE from "@salesforce/label/c.BREG_Home_Warning_Title";
import BREG_HOME_WARNING_TEMPLATE from "@salesforce/label/c.BREG_Home_Warning_Message";
import BREG_HOME_WARNING_DATE from "@salesforce/label/c.BREG_Home_Warning_Deadline_Date";
import BREG_HOME_WARNING_CONTACT from "@salesforce/label/c.BREG_Home_Warning_Contact_Number";

export default class Breg_Home extends LightningElement {
    warningBannerTitle = BREG_HOME_WARNING_TITLE;

    // Controlled by BREG_Setting__c.Home_Warning_Banner_Enabled__c
    @wire(isHomeWarningBannerEnabled)
    warningBannerEnabled;

    get showWarningBanner() {
        return this.warningBannerEnabled?.data === true;
    }


    get warningBannerMessage() {
        return BREG_HOME_WARNING_TEMPLATE
            .replace("{0}", BREG_HOME_WARNING_DATE) //TODO: add date into custom settings to be managed by admin and replace the hardcoded date with the custom setting value
            .replace("{1}", BREG_HOME_WARNING_CONTACT);
    }

    handleSearch() {
        // Get the search input value
        const searchInput = this.template.querySelector('.search-input');
        const searchValue = searchInput ? searchInput.value.trim() : '';
        
        if (searchValue) {
            // Navigate to search-and-buy page with search term as URL parameter
            const url = `/search-and-buy?searchTerm=${encodeURIComponent(searchValue)}`;
            window.open(url, '_self');
        }
    }

    handleKeyDown(event) {
        if (event.key === 'Enter') {
            this.handleSearch();
        }
    }

    connectedCallback() {
        // Check for redirectAfterLogin URL parameter
        const urlParams = new URLSearchParams(window.location.search);
        const redirectAfterLogin = urlParams.get('redirectAfterLogin');
        // If redirectAfterLogin is true, clear the shopping cart
        if (redirectAfterLogin === 'true') {
            localStorage.removeItem('breg_shopping_cart');
        }
    }
}