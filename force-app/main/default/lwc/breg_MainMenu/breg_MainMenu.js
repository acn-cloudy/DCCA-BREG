import { api, LightningElement, wire } from "lwc";
import { publish, MessageContext } from "lightning/messageService";
import { MESSAGE_TYPE_SECTION_CHANGE } from "c/breg_constants";
import MESSAGE_CHANNEL from "@salesforce/messageChannel/breg_MessageChannel__c";
import { navigateToPage } from "c/utils";

const CRA_SECTION_NAME = "commercial_agent";
const CRA_FORM_SUFFIX = "X-11";

export default class Breg_MainMenu extends LightningElement {
    @api isNotGuest;
    @wire(MessageContext)
    messageContext;
    openDropdown = false;

    connectedCallback() {
        if (window.innerWidth > 768) {
            this.openDropdown = true;
        }
    }

    handleMenuClick(event) {
        const section = event.currentTarget.dataset.param;

        if (section === CRA_SECTION_NAME) {
            navigateToPage("/manage", {
                section: "change",
                formSuffix: CRA_FORM_SUFFIX
            });
        }

        const page = section === "search-and-buy" ? "search-and-buy" : "manage";
        const message = {
            type: MESSAGE_TYPE_SECTION_CHANGE,
            section: section,
            page: page
        };
        publish(this.messageContext, MESSAGE_CHANNEL, message);

        this.handleMobileMenuClick(event);
    }

    handleMobileMenuClick(event) {
        if (window.innerWidth <= 768) {
            const type = event.currentTarget.dataset.type;

            if (type === "link") {
                this.dispatchEvent(new CustomEvent("closemenu", { bubbles: true, composed: true }));
            }
        }
    }

    toggleDropdown(event) {
        if (window.innerWidth <= 768) {
            event.stopPropagation();
            this.openDropdown = !this.openDropdown;
        }
    }
}