import { LightningElement, api } from "lwc";
import { formatCurrency } from "c/utils";

export default class Breg_TransactionLinesTable extends LightningElement {
    @api header = "Items";
    @api transactionLines = [];

    get totalAmount() {
        return this.transactionLines.reduce((total, line) => total + (line.price || 0), 0);
    }

    get formattedTotalAmount() {
        return `${formatCurrency(this.totalAmount)} USD`;
    }

    get hasTransactionLines() {
        return this.transactionLines && this.transactionLines.length > 0;
    }

    get formattedTransactionLines() {
        return this.transactionLines.map((line, index) => {
            let desc = line.description || "";
            const tags = [];
            if (line.isCertified) tags.push("Certified");
            if (line.isExpedited) tags.push("Expedited");
            if (tags.length > 0) {
                desc += ` (${tags.join(", ")})`;
            }
            return {
                ...line,
                Id: line.Id || `${line.paymentId}-${index}`,
                description: desc,
                quantity: line.quantity,
                price: line.price,
                formattedPrice: `${formatCurrency(line.price)} USD`
            };
        });
    }

    get transactionColumns() {
        return [
            {
                label: "Item",
                fieldName: "description",
                type: "text",
                wrapText: true
            },
            {
                label: "Quantity",
                fieldName: "quantity",
                type: "text",
                cellAttributes: { alignment: "right" }
            },
            {
                label: "Price",
                fieldName: "formattedPrice",
                type: "text",
                cellAttributes: { alignment: "right" }
            }
        ];
    }
}