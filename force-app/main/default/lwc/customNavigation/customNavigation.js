import { LightningElement ,api, track} from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class CustomNavigation extends NavigationMixin(LightningElement) {
    
    @api recordId;
    @api label;
    @api pageRef;
    @api target = '_blank';

    @track url;

    connectedCallback(){
        if(!this.url){
            this.generateURL();
        }
    }

    generateURL(){
        let _pageRef = this.pageRef ?? {
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.recordId,
                    actionName: 'view',
                }
            };

        this[NavigationMixin.GenerateUrl](_pageRef).then(generatedUrl => {
            this.url = generatedUrl;
        });
    }

    navigateToRecordViewPage = () => {
        if(this.pageRef) {
            this[NavigationMixin.Navigate](this.pageRef);
        } else {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.recordId,
                    actionName: 'view',
                }
            });
        }
    }
}