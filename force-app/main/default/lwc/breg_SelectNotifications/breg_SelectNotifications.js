import { LightningElement, api, wire, track } from "lwc";
import { Labels } from "./labels";
import { setPageUrlParams, formatCurrency } from "c/utils";
import { NavigationMixin } from "lightning/navigation";
import getRecordForNotifications from "@salesforce/apex/BREGSearchAndBuyController.getRecordForNotificationsByIds";
import checkNotificationsForEntitiesAndCategories from "@salesforce/apex/BREGNotificationsHandler.checkNotificationsForEntitiesAndCategories";
import getNotificationCategoryPrices from "@salesforce/apex/BREGNotificationsHandler.getNotificationCategoryPrices";
import getAvailableCategoriesByObject from "@salesforce/apex/BREGNotificationsHandler.getAvailableCategoriesByObject";

export default class Breg_SelectNotifications extends NavigationMixin(LightningElement) {
    @api recordIds;
    @api sourceObject;
    labels = Labels;
    data;
    entityName;
    tnName;
    businessData = [];
    tnData = [];
    @track entityIdToObjectType = {};
    @track entityIdToTypeField = {};
    @api chosenCategory = "";
    get categoryIsChosen() {
        return this.chosenCategory !== "";
    }
    @api category;
    @track notificationsAccessability;
    @track chosenNotificationPackages = [];
    get disableNext() {
        return this.chosenNotificationPackages.length === 0;
    }

    connectedCallback() {
        if (this.categoryIsChosen) {
            this.recordIds.forEach((recordId) => {
                let rowId;
                if (recordId.startsWith("001") && this.entityIdToTypeField[recordId] === "Publicit Rigths Name") {
                    rowId = "Publicity Rights Name Renewal Reminder";
                } else {
                    rowId = this.chosenCategory;
                }
                this.chosenNotificationPackages.push({ rowId, recordId });
            });
            this.handleNext();
        }
    }

    handleCancel() {
        this[NavigationMixin.Navigate]({
            type: "comm__namedPage",
            attributes: {
                name: "Home"
            }
        });
    }
    get isTnTmSM() {
        return this.sourceObject === "breg_TN_TM_SM__c";
    }
    isLoadedData = false;
    handlePrev() {
        this.chosenNotificationPackages = [];
        setPageUrlParams({
            section: "notifications",
            page: "search",
            category: this.category
        });
        this.dispatchEvent(new CustomEvent("previous"));
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

    handleNext() {
        setPageUrlParams({
            section: "notifications",
            page: "send",
            category: this.category
        });
        this.dispatchEvent(
            new CustomEvent("gotosend", {
                detail: {
                    chosenNotifications: this.chosenNotificationPackages
                }
            })
        );
    }

    tradeColumns = [
        { label: "Description", fieldName: "description" },
        { label: "Expiration Date", fieldName: "expirationDate", type: "date", typeAttributes: {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
            timeZone: 'UTC'
        } },
        { label: "File/Cert Number", fieldName: "fileCertNumber" },
        { label: "Cost", fieldName: "cost" },
        {
            label: "Action",
            type: "customSelect",
            typeAttributes: {
                id: { fieldName: "id" },
                recordId: { fieldName: "recordId" },
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
            label: "Action",
            type: "customSelect",
            typeAttributes: {
                id: { fieldName: "id" },
                recordId: { fieldName: "recordId" },
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
            this.data.forEach((item) => {
                this.entityIdToObjectType[item.recordId] = item.sourceObject;
                if (item.sourceObject === "breg_TN_TM_SM__c") {
                    this.entityIdToTypeField[item.recordId] = item.type;
                }
            });

            try {
                const jsonInput = JSON.stringify({
                    entityIdToObjectType: this.entityIdToObjectType,
                    entityIdToTypeField: this.entityIdToTypeField
                });
                const [categoryAccess, categoryPrices] = await Promise.all([
                    getAvailableCategoriesByObject({ jsonInput }),
                    getNotificationCategoryPrices()
                ]);
                let inputs = Object.entries(categoryAccess).flatMap(([recordId, categories]) =>
                    categories.map((category) => ({
                        entityId: recordId,
                        categoryName: category
                    }))
                );

                this.notificationsAccessability = await checkNotificationsForEntitiesAndCategories({
                    jsonInput: JSON.stringify(inputs)
                });

                this.categoryPrices = categoryPrices;
                this.categoryAccess = categoryAccess;

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
                console.error("Error retrieveing categories or prices:", e);
            }
        } else if (error) {
            this.error = error;
            console.error("Error retrieving record data: ", error);
        }
    }

    getDynamicNotifications(entity) {
        const recordId = entity.recordId;
        const entityResult = this.notificationsAccessability?.[recordId] || {};
        const categories = this.categoryAccess?.[recordId] || [];

        return categories.map((category) => {
            const cost = this.categoryPrices?.[category] || 0;
            const formattedCost = `${formatCurrency(cost)}`;

            return {
                id: category,
                action: category === "MyBusiness Alerts",
                description: category.includes("Trade") ? `${entity.type} Reminder` : category,
                fileNumber: entity.fileNumber,
                expirationDate: entity.expirationDate,
                fileCertNumber: `${entity.fileNumber}/${entity.certificationNumber}`,
                cost: formattedCost,
                recordId: recordId,
                ...(entityResult[category] ? { disabledItem: true, checkedItem: true } : {})
            };
        });
    }

    handleCustomSelectRowClicked(event) {
        const { rowId, recordId, checked } = event.detail;
        if (checked) {
            const alreadyExists = this.chosenNotificationPackages.some((item) => item.rowId === rowId && item.recordId === recordId);
            if (!alreadyExists) {
                this.chosenNotificationPackages.push({ rowId, recordId });
            }
        } else {
            this.chosenNotificationPackages = this.chosenNotificationPackages.filter((item) => !(item.rowId === rowId && item.recordId === recordId));
        }
    }
}