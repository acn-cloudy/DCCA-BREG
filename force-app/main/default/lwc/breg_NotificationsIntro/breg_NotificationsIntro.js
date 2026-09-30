import { LightningElement, api } from "lwc";
import { Labels } from "./labels";

export default class Breg_NotificationsIntro extends LightningElement {
    @api isDashboardContext = false;
    @api hideIntroTitle = false;

    labels = Labels;

    get introText() {
        return `${this.hideIntroTitle ? "" : this.labels.BREG_Notif_IntroTitle + "<br/><br/>"}
                ${this.labels.BREG_Notif_IntroText}`;
    }

    annualReportPrice = (Math.round(2.5 * 100) / 100).toFixed(2);
    tnPrice = (Math.round(2.5 * 100) / 100).toFixed(2);
    myBusinessAlertsPrice = (Math.round(25 * 100) / 100).toFixed(2);
    
    get Annual_PriceFormatted() {
        return this.labels.BREG_Notif_Annual_Price.replace("{1}", this.annualReportPrice);
    }
    
    get TN_PriceFormatted() {
        return this.labels.BREG_Notif_TN_Price.replace("{1}", this.tnPrice);
    }
    
    get Alerts_PriceFormatted() {
        return this.labels.BREG_Notif_Alerts_Price.replace("{1}", this.myBusinessAlertsPrice);
    }

    get cards() {
        return [
            {
                key: "annual",
                title: this.labels.BREG_Notif_Annual_Title,
                price: this.Annual_PriceFormatted,
                description: this.labels.BREG_Notif_Annual_Desc,
                note: this.labels.BREG_Notif_Annual_Note,
                category: "annual"
            },
            {
                key: "tn",
                title: this.labels.BREG_Notif_TN_Title,
                price: this.TN_PriceFormatted,
                description: this.labels.BREG_Notif_TN_Desc,
                note: this.labels.BREG_Notif_TN_Note,
                category: "tn"
            },
            {
                key: "business",
                title: this.labels.BREG_Notif_Alerts_Title,
                price: this.Alerts_PriceFormatted,
                description: this.labels.BREG_Notif_Alerts_Desc,
                category: "business"
            }
        ];
    }

    handleSignUp(event) {
        const category = event.target.dataset.category;
        window.location.href = `/manage?section=notifications&page=search&category=${category}`;
    }
}