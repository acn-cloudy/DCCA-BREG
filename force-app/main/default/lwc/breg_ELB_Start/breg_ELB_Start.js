import { LightningElement, api } from "lwc";
import getFees from "@salesforce/apex/BREGGetFeeForService.getFees";
import { formatCurrency } from "c/utils";

export default class Breg_ELB_Start extends LightningElement {
    columns = [
        { label: "Cost", fieldName: "cost" },
        { label: "Details", fieldName: "details" }
    ];

    tableData = [];
    isLoading = true;

    @api
    validate() {
        let isValid = true;
        //always return true, selection is not required on this step
        return isValid;
    }

    async connectedCallback() {
        try {
            const fees = await getFees({
                fieldsToSelect: ["breg_Fee_Amount__c", "breg_Cashier_Code__c"],
                filters: {
                    breg_Purchase_Type_Fee_type__c: "Document",
                    breg_Record_Type__c: "Entity List"
                }
            });
            console.log("Fees fetched:", JSON.stringify(fees));
            const perRecordFee = fees.find((fee) => fee.breg_Cashier_Code__c === "B71");
            const monthlyFee = fees.find((fee) => fee.breg_Cashier_Code__c === "B72");

            this.tableData = [
                {
                    id: "1",
                    cost: "One-time Search",
                    details: `${formatCurrency(perRecordFee?.breg_Fee_Amount__c)} per records found`
                },
                {
                    id: "2",
                    cost: "All records (weekly)",
                    details: `${formatCurrency(monthlyFee?.breg_Fee_Amount__c)} flat rate per month`
                }
            ];
        } catch (error) {
            console.error("Error fetching fees:", error.message);
        } finally {
            this.isLoading = false;
        }
    }
}