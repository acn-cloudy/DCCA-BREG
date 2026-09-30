import { LightningElement, api, wire } from "lwc";
import { Labels } from "./labels";
import { setPageUrlParams, formatCurrency } from "c/utils";
import { NavigationMixin } from "lightning/navigation";
import getRecordForNotifications from "@salesforce/apex/BREGSearchAndBuyController.getRecordForNotificationsByIds";
import getNotificationCategoryPrices from "@salesforce/apex/BREGNotificationsHandler.getNotificationCategoryPrices";
import getAvailableCategoriesByObject from "@salesforce/apex/BREGNotificationsHandler.getAvailableCategoriesByObject";

export default class Breg_SendToNotifications extends NavigationMixin(LightningElement) {
    labels = Labels;
    @api selectedItems;
    @api category;
    get recordIds() {
        const ids = this.chosenNotifications?.map((item) => item.recordId) || [];
        return [...new Set(ids)];
    }
    @api chosenNotifications;
    selectedItemsArr;
    data;
    entityName;
    chosenNotificationPackages;
    isLoadedData = false;

    tradeColumns = [
        { label: "Description", fieldName: "description" },
        { label: "File/Cert Number", fieldName: "fileCertNumber" },
        { label: "Cost", fieldName: "cost" },
        {
            label: "Email",
            type: "customSelect",
            typeAttributes: {
                id: { fieldName: "id" },
                checked: { fieldName: "selected" },
                disabledItem: { fieldName: "disabledItem" },
                checkedItem: { fieldName: "checkedItem" }
            }
        }
    ];

    businessColumns = [
        { label: "Description", fieldName: "description" },
        { label: "File Number", fieldName: "fileNumber" },
        { label: "Cost (per year)", fieldName: "cost" },
        {
            label: "Email",
            type: "customSelect",
            typeAttributes: {
                id: { fieldName: "id" },
                checked: { fieldName: "selected" },
                disabledItem: { fieldName: "disabledItem" },
                checkedItem: { fieldName: "checkedItem" }
            }
        }
    ];

    @wire(getRecordForNotifications, {
        recordIds: "$recordIds"
    })
    async wiredRecord({ error, data }) {
        if (data) {
            this.data = data;
            const entityIdToObjectType = {};
            const entityIdToTypeField = {};
            this.data.forEach((item) => {
                entityIdToObjectType[item.recordId] = item.sourceObject;
                if (item.sourceObject === "breg_TN_TM_SM__c") {
                    entityIdToTypeField[item.recordId] = item.type;
                }
            });

            try {
                const jsonInput = JSON.stringify({
                    entityIdToObjectType,
                    entityIdToTypeField
                });

                const [categoryAccess, categoryPrices] = await Promise.all([
                    getAvailableCategoriesByObject({ jsonInput }),
                    getNotificationCategoryPrices()
                ]);

                this.categoryAccess = categoryAccess;
                this.categoryPrices = categoryPrices;

                this.businessData = this.data
                    .filter((item) => item.sourceObject === "Account")
                    .map((biz) => ({
                        ...biz,
                        notifications: this.getDynamicNotifications(biz)
                    }));

                this.tnData = this.data
                    .filter((item) => item.sourceObject === "breg_TN_TM_SM__c")
                    .map((tn) => ({
                        ...tn,
                        notifications: this.getDynamicNotifications(tn)
                    }));

                this.isLoadedData = true;
            } catch (e) {
                console.error("Error retrieving categories or prices:", e);
            }
        } else if (error) {
            this.error = error;
            console.error("Error retrieving record data: ", error);
        }
    }

    getDynamicNotifications(entity) {
        const recordId = entity.recordId;
        const categories = this.categoryAccess?.[recordId] || [];
        const allowedRowIds = this.chosenNotifications?.filter((item) => item.recordId === recordId).map((item) => item.rowId) || [];

        return categories
            .filter((category) => allowedRowIds.includes(category))
            .map((category) => {
                const cost = this.categoryPrices?.[category] || 0;
                const formattedCost = `${formatCurrency(cost)}`;

                return {
                    id: category,
                    action: category === "My Business Alerts",
                    description: category.includes("Trade") ? `${entity.type} Reminder` : category,
                    fileNumber: entity.fileNumber,
                    expirationDate: entity.expirationDate,
                    fileCertNumber: `${entity.fileNumber}/${entity.certificationNumber}`,
                    cost: formattedCost,
                    recordId: recordId,
                    checkedItem: true,
                    disabledItem: true
                };
            });
    }

    handleCancel() {
        this[NavigationMixin.Navigate]({
            type: "comm__namedPage",
            attributes: {
                name: "Home"
            }
        });
    }

    handlePrev() {
        this.chosenNotificationPackages = [];
        setPageUrlParams({
            section: "notifications",
            page: this.category === "" ? "select" : "search",
            category: this.category
        });
        this.dispatchEvent(new CustomEvent("previous"));
    }

    handleNext() {
        setPageUrlParams({
            section: "notifications",
            page: "review",
            category: this.category
        });
        this.dispatchEvent(new CustomEvent("next"));
    }

    handleSearchAgain() {
        this.chosenNotificationPackages = [];
        setPageUrlParams({
            section: "notifications",
            page: "search",
            category: this.category
        });
        this.dispatchEvent(new CustomEvent("searchagain"));
    }
}