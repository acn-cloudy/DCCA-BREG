import { LightningElement, api, wire, track } from "lwc";
import { Labels } from "./labels";
import { setPageUrlParams, formatCurrency } from "c/utils";
import { NavigationMixin } from "lightning/navigation";
import getRecordForNotifications from "@salesforce/apex/BREGSearchAndBuyController.getRecordForNotificationsByIds";
import createNotifications from "@salesforce/apex/BREGNotificationsHandler.createNotifications";
import getCurrentUserEmail from "@salesforce/apex/BREGNotificationsHandler.getCurrentUserEmail";
import getNotificationCategoryPrices from "@salesforce/apex/BREGNotificationsHandler.getNotificationCategoryPrices";
import getAvailableCategoriesByObject from "@salesforce/apex/BREGNotificationsHandler.getAvailableCategoriesByObject";

export default class Breg_ReviewNotifications extends NavigationMixin(LightningElement) {
    CART_STORAGE_KEY = "breg_shopping_cart";
    labels = Labels;

    @api chosenNotifications;
    @api category;

    @track currentUserEmail;
    @track businessData;
    @track tnData;
    data;
    entityName;
    chosenNotificationPackages;
    acknoledgementChecked = false;
    isLoadedData = false;
    disableNext = true;

    get recordIds() {
        const ids = this.chosenNotifications?.map((item) => item.recordId) || [];
        return [...new Set(ids)];
    }

    get totalCost() {
        const businessSum = (this.businessData || [])
            .flatMap((biz) => biz.notifications || [])
            .reduce((sum, notif) => {
                const numericCost = parseFloat(notif.cost?.replace("$", "") || "0");
                return sum + numericCost;
            }, 0);

        const tnSum = (this.tnData || [])
            .flatMap((tn) => tn.notifications || [])
            .reduce((sum, notif) => {
                const numericCost = parseFloat(notif.cost?.replace("$", "") || "0");
                return sum + numericCost;
            }, 0);

        return (businessSum + tnSum).toFixed(2);
    }

    tradeColumns = [
        { label: "Description", fieldName: "description" },
        { label: "File/Cert Number", fieldName: "fileCertNumber" },
        { label: "Send To", fieldName: "sendTo" },
        { label: "Cost", fieldName: "cost" },
        {
            type: "button",
            label: "Action",
            cellAttributes: {
                class: "slds-text-color_error"
            },
            typeAttributes: {
                label: "Remove",
                name: "removeFromCart",
                title: "Remove",
                variant: "base"
            }
        }
    ];

    businessColumns = [
        { label: "Description", fieldName: "description" },
        { label: "File Number", fieldName: "fileNumber" },
        { label: "Send To", fieldName: "sendTo" },
        { label: "Cost (per year)", fieldName: "cost" },
        {
            type: "button",
            label: "Action",
            cellAttributes: {
                class: "slds-text-color_error"
            },
            typeAttributes: {
                label: "Remove",
                name: "removeFromCart",
                title: "Remove",
                variant: "base"
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
                const email = await getCurrentUserEmail();
                this.currentUserEmail = email;

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
                const formattedCost = formatCurrency(cost);

                const base = {
                    id: category,
                    description: category.includes("Trade") ? `${entity.type} Reminder` : category,
                    recordId: recordId,
                    cost: formattedCost,
                    sendTo: this.currentUserEmail,
                    checkedItem: true,
                    disabledItem: true
                };

                if (entity.sourceObject === "Account") {
                    base.fileNumber = entity.fileNumber;
                    base.available = false;
                } else if (entity.sourceObject === "breg_TN_TM_SM__c") {
                    base.expirationDate = entity.expirationDate;
                    base.fileCertNumber = `${entity.fileNumber}/${entity.certificationNumber}`;
                }

                return base;
            });
    }

    handleAcknowledgementChange(event) {
        this.acknoledgementChecked = !this.acknoledgementChecked;
        this.disableNext = !this.acknoledgementChecked;
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        switch (actionName) {
            case "removeFromCart":
                const { recordId, id: rowId } = row;

                this.businessData = (this.businessData || [])
                    .map((entry) => {
                        if (entry.recordId !== recordId) return entry;
                        const updatedNotifications = (entry.notifications || []).filter((n) => n.id !== rowId);
                        return { ...entry, notifications: updatedNotifications };
                    })
                    .filter((entry) => entry.notifications.length > 0);

                this.tnData = (this.tnData || [])
                    .map((entry) => {
                        if (entry.recordId !== recordId) return entry;
                        const updatedNotifications = (entry.notifications || []).filter((n) => n.id !== rowId);
                        return { ...entry, notifications: updatedNotifications };
                    })
                    .filter((entry) => entry.notifications.length > 0);

                break;
            default:
                console.log("wrong action name");
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

    handlePrev() {
        this.chosenNotificationPackages = [];
        setPageUrlParams({
            section: "notifications",
            page: "send",
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

    handleAddToCart() {
        const mergedData = [...this.businessData, ...this.tnData];
        const jsonString = JSON.stringify(mergedData);
        createNotifications({ jsonInput: jsonString, isFree: false })
            .then(() => {
                console.log("Notifications created");
            })
            .catch((error) => {
                console.error("Error:", error);
            });
        this.addItemsToCart(this.getCartJSON());
        this.dispatchEvent(new CustomEvent("addtocart"));
    }

    addItemsToCart(newItems) {
        try {
            // Get existing cart items from localStorage
            const existingCartJson = localStorage.getItem(this.CART_STORAGE_KEY);
            let existingCart = [];

            if (existingCartJson) {
                existingCart = JSON.parse(existingCartJson);
            }

            // Filter out items that already exist in cart (check by item ID)
            const existingIds = existingCart.map((item) => item.id);
            const itemsToAdd = newItems.filter((item) => !existingIds.includes(item.id));

            // Add only new items to existing cart
            const updatedCart = [...existingCart, ...itemsToAdd];

            // Save updated cart back to localStorage
            localStorage.setItem(this.CART_STORAGE_KEY, JSON.stringify(updatedCart));

            // Dispatch event to notify parent components that cart was updated
            this.dispatchEvent(
                new CustomEvent("itemsaddedtocart", {
                    bubbles: true,
                    composed: true,
                    detail: {
                        itemsAdded: itemsToAdd.length,
                        cartTotal: updatedCart.length
                    }
                })
            );
        } catch (error) {
            console.error("Error adding items to cart:", error);
        }
    }

    getCartJSON() {
        const today = new Date();
        const formattedDate = today.toISOString().split("T")[0];

        const sharedFields = {
            documentDate: formattedDate,
            format: "Digital (Email)",
            formatIcon: "standard:email",
            quantity: 1,
            certifyPrice: 0,
            isCertified: false,
            isQuantityDisabled: true,
            type: "Notification"
        };

        const parseCost = (cost) => parseFloat((cost || "").replace(/[^0-9.]/g, ""));

        const fromBusiness = (this.businessData || []).flatMap((entry) =>
            (entry.notifications || []).map((notif) => {
                const numericCost = parseCost(notif.cost);
                return {
                    id: `${entry.recordId}-${notif.id}`,
                    companyName: entry.businessName,
                    companyUrl: entry.recordId ? '/search-and-buy?entityId=' + entry.recordId : '#',
                    documentType: notif.description,
                    price: numericCost,
                    unitPrice: numericCost,
                    ...sharedFields
                };
            })
        );

        const fromTN = (this.tnData || []).flatMap((entry) =>
            (entry.notifications || []).map((notif) => {
                const numericCost = parseCost(notif.cost);
                return {
                    id: `${entry.recordId}-${notif.id}`,
                    companyName: entry.businessName,
                    companyUrl: entry.recordId ? '/search-and-buy?entityId=' + entry.recordId : '#',
                    documentType: notif.description,
                    price: numericCost,
                    unitPrice: numericCost,
                    ...sharedFields
                };
            })
        );

        return [...fromBusiness, ...fromTN];
    }
}