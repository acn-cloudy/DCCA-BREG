import { LightningElement, api } from 'lwc';
import { ShowToastEvent,  } from 'lightning/platformShowToastEvent'
import { subscribe, unsubscribe, onError } from 'lightning/empApi';


export default class pptToastListener extends LightningElement {
    @api recordId; 
    channelName = '/event/ppt_Toast__e';

    subscription = {};


    connectedCallback() {
        subscribe(this.channelName, -1, this.handleMessage.bind(this)).then(response => {
            this.subscription = response;
        })
        onError((error) => console.error(error))
    }
    disconnectedCallback() {
        unsubscribe(this.subscription)
    }

    handleMessage(message){
        let toast = message.data.payload;
        toast = new ToastPE(toast);
        if(toast instanceof ToastPE && toast.RecordId__c === this.recordId){
            this.dispatchEvent(new ShowToastEvent({
                message: toast.Message__c,
                title: toast.Title__c,
                variant: toast.Variant__c,
                mode: toast.Mode__c
            }))
        }
    }
}

class ToastPE {

    VARIANTS = ['info', 'success', 'warning', 'error'];
    MODES = ['dismissible', 'pester', 'sticky'];

    RecordId__c;
    Message__c;
    Title__c;
    Variant__c;
    Mode__c;

    constructor({RecordId__c, Message__c, Title__c, Variant__c, Mode__c}){
        this.RecordId__c = RecordId__c;
        this.Message__c = Message__c;
        this.Title__c = Title__c;
        this.Variant__c = this.VARIANTS.includes(Variant__c.toLowerCase()) ? Variant__c.toLowerCase() : this.VARIANTS[0]; 
        this.Mode__c = this.MODES.includes(Mode__c.toLowerCase()) ? Mode__c.toLowerCase() : this.MODES[0]; 
    }
}