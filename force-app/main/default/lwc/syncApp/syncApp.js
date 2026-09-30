import { LightningElement, api } from 'lwc';
import updateApplication from "@salesforce/apex/DraftApplicationService.updateApplication";

export default class SyncApp extends LightningElement {
    @api recordId;
    @api cardStr;
    @api cardMetaName;
    connectedCallback() {
        const { recordId, cardStr, cardMetaName } = this;
        if(recordId) {
            updateApplication({recordId, cardStr, cardMetaName}).then( res => {
                console.log("res", res);
            });
        }
    }


}