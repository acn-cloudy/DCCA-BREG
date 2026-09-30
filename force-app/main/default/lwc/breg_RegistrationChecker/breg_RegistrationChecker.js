import { LightningElement, wire } from "lwc";
import { NavigationMixin, CurrentPageReference } from "lightning/navigation";
import needsProfileCompletion from "@salesforce/apex/BREGPortalUtils.needsProfileCompletion";

const ACCOUNT_SETTINGS_PAGE = "BREG_Account_Settings__c";

export default class Breg_RegistrationChecker extends NavigationMixin(LightningElement) {
    @wire(CurrentPageReference)
    async wiredPageRef(pageRef) {
        if (!pageRef) return;

        const isPreview = window.location.href.includes("live-preview.salesforce-experience.com");
        if (isPreview) return;

        // Already on Account Settings — skip to avoid redirect loop
        if (pageRef.attributes?.name === ACCOUNT_SETTINGS_PAGE) return;

        try {
            const needs = await needsProfileCompletion();
            if (needs) {
                this[NavigationMixin.Navigate]({
                    type: "comm__namedPage",
                    attributes: { name: ACCOUNT_SETTINGS_PAGE }
                });
            }
        } catch (e) {
            console.error("Error checking profile completion:", e);
        }
    }
}