import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import { FlowNavigationFinishEvent } from 'lightning/flowSupport';


export default class Breg_NavigateEverywhere extends NavigationMixin(LightningElement) {

    @api destinationURL
    @api availableActions = []

    connectedCallback() {
        this.navigate()

        if (this.availableActions.includes("FINISH")) {
            this.dispatchEvent(new FlowNavigationFinishEvent())
        }
        else {
            this.dispatchEvent(new CloseActionScreenEvent());
        }
    }

    navigate() {
        window.open(this.destinationURL, "_self")
        // this[NavigationMixin.GenerateUrl]({
        //     type: 'standard__webPage',
        //     attributes: {
        //         url: 'https://salesforce.com'//this.destinationURL,
        //     }
        // }).then(url => {
        //     window.open(url, "_blank")
        // })
    }

}