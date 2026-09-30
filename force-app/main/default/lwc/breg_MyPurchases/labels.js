import BREG_PaymentConfirmation_Download from '@salesforce/label/c.BREG_PaymentConfirmation_Download';
import BREG_PaymentConfirmation_PurchasedItems from '@salesforce/label/c.BREG_PaymentConfirmation_PurchasedItems';
import BREG_PaymentConfirmation_Item from '@salesforce/label/c.BREG_PaymentConfirmation_Item';
import BREG_PaymentConfirmation_Price from '@salesforce/label/c.BREG_PaymentConfirmation_Price';
import BREG_PaymentConfirmation_PurchaseDate from '@salesforce/label/c.BREG_PaymentConfirmation_PurchaseDate';
import BREG_Delivery_Method from '@salesforce/label/c.BREG_Delivery_Method';
import BREG_Action from '@salesforce/label/c.BREG_Action';
import BREG_ItemsPerPage from '@salesforce/label/c.BREG_ItemsPerPage';

// Export all labels as a single object
export default {
    BREG_PaymentConfirmation_Download,
    BREG_PaymentConfirmation_PurchasedItems,
    BREG_PaymentConfirmation_Item,
    BREG_PaymentConfirmation_Price,
    BREG_PaymentConfirmation_PurchaseDate,
    BREG_Delivery_Method,
    BREG_Action,
    itemsPerPage: BREG_ItemsPerPage
};