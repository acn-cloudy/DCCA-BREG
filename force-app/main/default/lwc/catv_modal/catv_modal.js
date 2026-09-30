/**
 * @description       : 
 * @author            : Gaurav Agarwal
 * @group             : 
 * @last modified on  : 05-13-2025
 * @last modified by  : Gaurav Agarwal
**/
import { LightningElement, api} from 'lwc';
import { focusFirstEle } from "c/mdsUtility";

export default class Catv_modal extends LightningElement {
	@api hideHeader = false;
	@api headerTitle;

	connectedCallback() {
		setTimeout(() => {
            focusFirstEle(this);
        }, 500);
	}

	closeModal(event) {
		const closeEvent = new CustomEvent('close');
		this.dispatchEvent(closeEvent);
	}

	handleKey(event) {
		if(event.code == 'Escape') {
            const closeEvent = new CustomEvent('close');
			this.dispatchEvent(closeEvent);
        }
	}
}