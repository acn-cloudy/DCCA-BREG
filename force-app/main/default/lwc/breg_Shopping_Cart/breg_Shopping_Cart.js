import { LightningElement, track, api } from "lwc";
import { Labels } from "./labels";
import isExpeditedProcessingDisabled from "@salesforce/apex/BREGPaymentController.isExpeditedProcessingDisabled";

export default class Breg_Shopping_Cart extends LightningElement {
    // Labels for localization
    labels = Labels;

    // Cart data loaded from localStorage
    @track cartItems = [];

    // Loading state for checkout
    @track isLoading = false;

    // Local storage key for cart items
    CART_STORAGE_KEY = "breg_shopping_cart";

    // State for expedited processing availability
    @track showExpeditedDisabledModal = false;

    // Lifecycle methods
    connectedCallback() {
        this.loadCartFromStorage();
    }

    // Local storage methods
    loadCartFromStorage() {
        try {
            const storedCart = localStorage.getItem(this.CART_STORAGE_KEY);
            if (storedCart && JSON.parse(storedCart) !== "[]") {
                this.cartItems = this.normalizeCartForExpedite(JSON.parse(storedCart));
                this.saveCartToStorage(this.CART_STORAGE_KEY, this.cartItems);
            } else {
                this.cartItems = [];
            }
        } catch (error) {
            console.error("Error loading cart from localStorage:", error);
            this.cartItems = [];
        }
    }

    normalizeCartForExpedite(items) {
        let normalizedItems = (items || []).map((item) => ({
            ...item,
            displayPrice: item.displayPrice === undefined ? true : item.displayPrice
        }));

        //const parentItems = normalizedItems.filter((item) => !item.parentItemId && !item.isExpediteFee && item.expediteFeeId);
        const parentItems = normalizedItems.filter((item) => item.isAvailableToCertify);

        parentItems.forEach((parentItem) => {
            const existingExpediteItem = normalizedItems.find((item) => item.parentItemId === parentItem.id && item.isExpediteFee);
            const legacyExpediteItem = normalizedItems.find(
                (item) =>
                    !item.parentItemId &&
                    !item.isExpediteFee &&
                    item.documentType?.includes("Expedite Fee") &&
                    this.isLegacyExpediteForParent(item, parentItem)
            );

            const expediteFeeId = existingExpediteItem?.feeId || parentItem.expediteFeeId || legacyExpediteItem?.feeId;
            const expeditePrice = existingExpediteItem?.unitPrice || parentItem.expeditePrice || legacyExpediteItem?.unitPrice || 0;

            if (!expediteFeeId && !expeditePrice) {
                return;
            }

            const isSelected = existingExpediteItem ? existingExpediteItem.quantity > 0 : Boolean(parentItem.isExpediteSelected || legacyExpediteItem);

            const normalizedExpediteItem = this.buildExpediteFeeItem(parentItem, {
                id: existingExpediteItem?.id || `exp-fee-${parentItem.id}`,
                feeId: expediteFeeId,
                unitPrice: expeditePrice,
                isSelected
            });

            normalizedItems = normalizedItems.map((item) => {
                if (item.id === parentItem.id) {
                    return {
                        ...item,
                        expediteFeeId,
                        expeditePrice,
                        isExpediteSelected: isSelected
                    };
                }

                if (existingExpediteItem && item.id === existingExpediteItem.id) {
                    return {
                        ...item,
                        ...normalizedExpediteItem
                    };
                }

                return item;
            });

            if (!existingExpediteItem) {
                normalizedItems.push(normalizedExpediteItem);
            }

            if (legacyExpediteItem) {
                normalizedItems = normalizedItems.filter((item) => item.id !== legacyExpediteItem.id);
            }
        });

        return normalizedItems;
    }

    buildExpediteFeeItem(parentItem, config) {
        const parentPrefix = this.getParentDocumentPrefix(parentItem.documentType);
        const expediteDocumentType = parentPrefix ? `${parentPrefix} - Expedite Fee` : "Expedite Fee";
        const quantity = config.isSelected ? parentItem.quantity : 0;

        return {
            id: config.id,
            documentType: expediteDocumentType,
            documentDate: parentItem.documentDate,
            caseId: parentItem.caseId,
            type: parentItem.type,
            quantity,
            companyName: parentItem.companyName,
            companyUrl: parentItem.companyUrl,
            unitPrice: config.unitPrice,
            price: config.unitPrice * quantity,
            isCertified: false,
            isExpediteFee: true,
            isExpediteAvailable: true,
            expeditedReviewAction: config.isSelected ? "Delete Expedite fee" : "Add Expedite fee",
            hasTooltip: true,
            showTooltip: false,
            tooltipText: "More info",
            tooltipHeader: "Expedited Info",
            tooltipBody: this.labels.expediteTooltipText,
            parentItemId: parentItem.id,
            parentItemKey: parentItem.key,
            isDeleteDisabled: true,
            isQuantityDisabled: true,
            feeId: config.feeId,
            key: parentItem.key,
            displayPrice: config.isSelected
        };
    }

    getParentDocumentPrefix(documentType) {
        return documentType?.replace(/\s*filing with DCCA$/i, "").trim();
    }

    isLegacyExpediteForParent(expediteItem, parentItem) {
        const parentPrefix = this.getParentDocumentPrefix(parentItem.documentType);
        const expediteType = expediteItem.documentType?.trim();

        if (!expediteType) {
            return false;
        }

        if (!parentPrefix) {
            return expediteType === "Expedite Fee";
        }

        return expediteType.startsWith(parentPrefix) && expediteType.includes("Expedite Fee");
    }

    @api saveCartToStorage(CART_STORAGE_KEY, cartItems) {
        try {
            localStorage.setItem(CART_STORAGE_KEY, JSON.stringify(cartItems));
        } catch (error) {
            console.error("Error saving cart to localStorage:", error);
        }
    }

    // Public method to refresh cart from localStorage
    @api
    refreshCart() {
        this.loadCartFromStorage();
    }

    // Computed properties
    get hasItems() {
        return this.cartItems && this.cartItems.length > 0;
    }

    get totalQuantity() {
        return this.cartItems.length > 0 ? this.cartItems.reduce((total, item) => total + item.quantity, 0) : 0;
    }

    get totalPrice() {
        return this.cartItems.length > 0 ? this.cartItems.reduce((total, item) => total + item.price, 0) : 0;
    }

    handleExpeditedDisabledModalClose() {
        this.showExpeditedDisabledModal = false;
    }

    handleContinueShopping() {
        // Only go back in history when on the cart page
        if (window.location.pathname.includes("/cart")) {
            window.history.back();
        }
        // Dispatch custom event to notify parent component to navigate to previous page
        this.dispatchEvent(new CustomEvent("continueshopping", {}));
    }

    handleRemoveItem(event) {
        const itemId = event.currentTarget.dataset.itemId;

        // Find the item being removed
        const itemToRemove = this.cartItems.find((item) => item.id === itemId);

        // If removing a certified copy fee, restore the parent item's certify button
        if (itemToRemove && itemToRemove.parentItemId && itemToRemove.documentType?.includes("Certified Copy Fee")) {
            this.cartItems = this.cartItems.map((item) => {
                if (item.id === itemToRemove.parentItemId) {
                    return {
                        ...item,
                        isAvailableToCertify: true
                    };
                }
                return item;
            });
            this.cartItems = this.cartItems.filter((item) => item.id !== itemId);
        } else if (itemToRemove && itemToRemove.isPrimaryItem) {
            // Check if the item is a primary item (triggers group removal)
            const itemKey = itemToRemove.key;

            // Remove the item and all items with the same key
            if (itemKey) {
                this.cartItems = this.cartItems.filter((item) => item.key !== itemKey && item.parentItemKey !== itemKey);
            } else {
                this.cartItems = this.cartItems.filter((item) => item.id !== itemId && item.parentItemId !== itemId);
            }
        } else {
            // For other items, just remove the single item
            this.cartItems = this.cartItems.filter((item) => item.id !== itemId && item.parentItemId !== itemId);
        }

        // Save updated cart to localStorage
        this.saveCartToStorage(this.CART_STORAGE_KEY, this.cartItems);

        // Dispatch custom event to notify parent components
        this.dispatchEvent(new CustomEvent("cartupdated", {}));
    }

    handleQuantityChange(event) {
        const itemId = event.target.dataset.itemId;
        const inputValue = event.target.value;
        const newQuantity = parseInt(inputValue);

        // Validate input - must be a positive integer
        if (isNaN(newQuantity) || newQuantity <= 0 || inputValue === "" || inputValue === null) {
            // Reset to minimum value of 1
            event.target.value = "1";
            this.updateItemQuantity(itemId, 1);
            return;
        }

        // Update item with valid quantity
        this.updateItemQuantity(itemId, newQuantity);
    }

    // Helper method to update item quantity and price
    updateItemQuantity(itemId, quantity) {
        this.cartItems = this.cartItems.map((item) => {
            if (item.id === itemId) {
                return {
                    ...item,
                    quantity: quantity,
                    price: item.unitPrice * quantity
                };
            }
            // Sync quantity on child Certified Copy Fee items
            if (item.parentItemId === itemId && item.documentType?.includes("Certified Copy Fee")) {
                return {
                    ...item,
                    quantity: quantity,
                    price: item.unitPrice * quantity
                };
            }
            // Sync quantity on selected child Expedite Fee items
            if (item.parentItemId === itemId && item.isExpediteFee) {
                const isExpediteSelected = item.quantity > 0;
                return {
                    ...item,
                    quantity: isExpediteSelected ? quantity : 0,
                    price: isExpediteSelected ? item.unitPrice * quantity : 0,
                    displayPrice: isExpediteSelected
                };
            }
            return item;
        });

        // Save updated cart to localStorage
        this.saveCartToStorage(this.CART_STORAGE_KEY, this.cartItems);

        // Dispatch custom event to notify parent components
        this.dispatchEvent(new CustomEvent("cartupdated", {}));
    }

    handleCertifyClick(event) {
        const itemId = event.currentTarget.dataset.itemId;
        // Find the item to certify
        const itemToCertify = this.cartItems.find((item) => item.id === itemId);
        if (itemToCertify && !itemToCertify.isCertified) {
            if (itemToCertify.certifyFeeId) {
                // Update the original item - hide certify button
                this.cartItems = this.cartItems.map((item) => {
                    if (item.id === itemId) {
                        return {
                            ...item,
                            isAvailableToCertify: false
                        };
                    }
                    return item;
                });

                // Create new "Certified Copy Fee" item (quantity always mirrors the parent)
                const certifiedCopyFeeItem = {
                    id: `cert-fee-${itemId}-${Date.now()}`,
                    documentType: itemToCertify.documentType.replace(/Filing with DCCA$/i, "") + " - Certified Copy Fee",
                    documentDate: itemToCertify.documentDate,
                    caseId: itemToCertify.caseId,
                    type: itemToCertify.type,
                    quantity: itemToCertify.quantity,
                    companyName: itemToCertify.companyName,
                    companyUrl: itemToCertify.companyUrl,
                    unitPrice: itemToCertify.certifyPrice,
                    price: itemToCertify.certifyPrice * itemToCertify.quantity,
                    isCertified: false,
                    parentItemId: itemId,
                    parentItemKey: itemToCertify.key,
                    isDeleteDisabled: false,
                    isQuantityDisabled: true,
                    feeId: itemToCertify.certifyFeeId,
                    isAvailableToCertify: false,
                    key: itemToCertify.key,
                    displayPrice: true
                };

                // Add the new item to cart
                this.cartItems.push(certifiedCopyFeeItem);
            }
        }

        // Save updated cart to localStorage
        this.saveCartToStorage(this.CART_STORAGE_KEY, this.cartItems);

        // Dispatch custom event to notify parent components
        this.dispatchEvent(new CustomEvent("cartupdated", {}));
    }

    async handleExpeditedReview(event) {
        const itemId = event.currentTarget.dataset.itemId;
        const expediteItem = this.cartItems.find((item) => item.id === itemId);

        if (!expediteItem?.isExpediteFee) {
            return;
        }

        const includePrice = expediteItem.quantity === 0;

        if (includePrice) {
            const isDisabled = await isExpeditedProcessingDisabled();

            if (isDisabled) {
                this.showExpeditedDisabledModal = true;
                return;
            }
        }

        const parentItem = this.cartItems.find((item) => item.id === expediteItem.parentItemId);
        const updatedQuantity = includePrice ? parentItem?.quantity || 1 : 0;

        this.cartItems = this.cartItems.map((item) => {
            if (item.id === itemId) {
                return {
                    ...item,
                    quantity: updatedQuantity,
                    price: includePrice ? item.unitPrice * updatedQuantity : 0,
                    displayPrice: includePrice,
                    expeditedReviewAction: includePrice ? "Delete Expedite fee" : "Add Expedite fee"
                };
            }

            if (parentItem && item.id === parentItem.id) {
                return {
                    ...item,
                    isExpediteSelected: includePrice
                };
            }

            return item;
        });

        this.saveCartToStorage(this.CART_STORAGE_KEY, this.cartItems);
        this.dispatchEvent(new CustomEvent("cartupdated", {}));
    }

    handleTooltipHover(event) {
        const itemId = event.currentTarget.dataset.itemId;
        this.cartItems = this.cartItems.map((item) => {
            if (item.id === itemId) {
                return {
                    ...item,
                    showTooltip: !item.showTooltip
                };
            }
            return item;
        });
    }

    async handleCheckOut() {
        try {
            this.isLoading = true;
            window.location.href = "/checkout?page=checkout";
        } catch (error) {
            console.error("Error during checkout:", error);
            this.isLoading = false;
        }
    }
}