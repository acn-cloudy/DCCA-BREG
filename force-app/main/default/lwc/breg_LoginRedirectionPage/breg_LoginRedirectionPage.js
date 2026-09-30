import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getSSOUrl from '@salesforce/apex/BREGPortalUtils.getSSOUrl';

export default class Breg_LoginRedirectionPage extends NavigationMixin(LightningElement) {
    async handleLoginClick() {
        const ssoUrl = await getSSOUrl();
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: ssoUrl,
                target: '_self'
            }
        });
    }
}