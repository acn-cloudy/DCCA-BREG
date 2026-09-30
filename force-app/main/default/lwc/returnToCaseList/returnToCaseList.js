import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class ReturnToCaseList extends NavigationMixin(LightningElement) {
    @api buttonLabel;

    handleClick() {
        this[NavigationMixin.Navigate](this.newPageRef);
    }

    get newPageRef() {
        return {
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Case',
                actionName: 'list'
            }
        };
    }
}