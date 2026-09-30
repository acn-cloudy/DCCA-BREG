import { LightningElement, api } from 'lwc';
import backupApp from '@salesforce/apex/sc_AppMetaDataManagement.backupApp';
export default class Sc_appBackup extends LightningElement {
    @api recordIdList;
    connectedCallback() {
        if(this.recordIdList) {
            const recordIds = this.recordIdList.split(",");
            recordIds.map(this.backupAppRecord);
        }
    }

    async backupAppRecord(recordId) {
        if(recordId) {
            const isSucceed = await backupApp({recordId});
            console.log("isSucceed", isSucceed);
        }   
    }
}