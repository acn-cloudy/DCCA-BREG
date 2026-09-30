import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import EXTERNAL_URL_FIELD from '@salesforce/schema/UJET__UJET_Action__c.UJET__Short_Description__c';

export default class CallCenterAudioPlayer extends LightningElement {
    @api recordId;

    @wire(getRecord, { recordId: '$recordId', fields: [EXTERNAL_URL_FIELD] })
    voiceCall;

    get audioUrl() {
        const fullString = getFieldValue(this.voiceCall.data, EXTERNAL_URL_FIELD);
        const prefix = 'External storage link: ';
        if (fullString && fullString.startsWith(prefix)) {
            return fullString.substring(prefix.length);
        }
        return null;
    }
}