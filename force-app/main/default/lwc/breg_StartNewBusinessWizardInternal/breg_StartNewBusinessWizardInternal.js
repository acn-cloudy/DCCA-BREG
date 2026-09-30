import { LightningElement } from 'lwc';
import { loadStyle } from "lightning/platformResourceLoader";
import BREG_PORTAL_RESOURCES from "@salesforce/resourceUrl/BREG_portalResources";

export default class Breg_StartNewBusinessWizardInternal extends LightningElement {

    connectedCallback() {
        this.loadInternalStyles();
    }

    loadInternalStyles() {
        loadStyle(this, BREG_PORTAL_RESOURCES + '/css/BREG_internalStyles.css')
        .then(() => {
            this.internalStylesLoaded = true;
            console.log('** BREG internal styles loaded successfully');
        })
        .catch(error => {
            console.error('** Error loading BREG internal styles:', error);
        });
    }
}