import { LightningElement, api } from "lwc";
import { Labels } from "./labels";
import { officeInfoHTML } from "./officeInfoHTML";
import generateCompanyInfoPdf from '@salesforce/apex/BREGBusinessDetailsController.generateCompanyInfoPdf';


export default class Breg_SearchAndBuy_CompanyInformation extends LightningElement {
    labels = Labels;

    // API properties to receive data from parent
    @api companyInfoFields = [];
    @api annualFilingData = [];
    @api otherFilingData = [];
    @api accountAffiliationData = [];
    @api stockData = [];
    @api tnTmSmData = [];
    @api isInGoodStanding = false;
    @api goodStandingMessage = "";

    // Column definitions
    @api annualFilingColumns = [];
    @api otherFilingColumns = [];
    @api accountAffiliationColumns = [];
    @api stockColumns = [];
    @api tnTmSmColumns = [];

    // Entity type flags
    @api isAccountObject = false;
    @api isTnTmSmObject = false;

    // Account or TN/TM/SM record ID
    @api recordId;

    // Modal window for office info
    showOfficeInfoModal = false;
    officeInfoMessage = officeInfoHTML;
    isDownloading = false;

    get annualToPopulate() {
        const validStatuses = ["N", "D", "Not Filed", "Delinquent"];
        const filtered = this.annualFilingData
            .filter((rec) => validStatuses.includes(rec.breg_Status__c) && rec.breg_Filing_Year__c)
            .sort((a, b) => parseInt(a.breg_Filing_Year__c, 10) - parseInt(b.breg_Filing_Year__c, 10));
        const resultId = filtered.length > 0 ? filtered[0].Id : null;
        return resultId;
    }

    get showFilingButton() {
        const validStatuses = [
            "Active (A)",
            "Delinquent Status 1 (1)",
            "Annual report 1 yr delinquent (1)",
        ];
        let statusValue = this.companyInfoFields.find((field) => field.label === "Status")?.value;
        return validStatuses.includes(statusValue) && this.annualToPopulate != null;
    }

    // Getters for displaying fields in two columns
    get leftColumnFields() {
        if (!this.companyInfoFields || this.companyInfoFields.length === 0) {
            return [];
        }
        const halfPoint = Math.ceil(this.companyInfoFields.length / 2);
        return this.companyInfoFields.slice(0, halfPoint);
    }

    get rightColumnFields() {
        if (!this.companyInfoFields || this.companyInfoFields.length === 0) {
            return [];
        }
        const halfPoint = Math.ceil(this.companyInfoFields.length / 2);
        return this.companyInfoFields.slice(halfPoint);
    }

    get earliestYear() {
        return this.annualFilingData
            .filter((filing) => filing.breg_Status__c === "N" || filing.breg_Status__c === "D")
            .sort((a, b) => a.breg_Filing_Year__c - b.breg_Filing_Year__c)[0]?.breg_Filing_Year__c;
    }

    get limitedAnnualFilings() {
        return this.annualFilingData.slice(0, 4).map((an) => {
            const updatedStatus = new Map([
                ["N", "Not Filed"],
                ["F", "Pending"],
                ["D", "Delinquent"],
                ["P", "Processed"],
                ["S", "Pending Resub"],
                ["0", "Zero"],
                ["H", "Held"],
                ["R", "Rejected"],
                ["NR", "Not required by the Statute"]
            ]);

            return {
                ...an,
                status: updatedStatus.get(an.breg_Status__c) || an.breg_Status__c
            };
        });
    }

    // Helper getter to check if we have any fields to display
    get hasFields() {
        return this.companyInfoFields && this.companyInfoFields.length > 0;
    }

    // Helper getters for related lists
    get hasAnnualFilings() {
        return this.isAccountObject && this.annualFilingData && this.annualFilingData.length > 0;
    }

    get hasOtherFilings() {
        return this.isAccountObject && this.otherFilingData && this.otherFilingData.length > 0;
    }

    get hasAccountAffiliations() {
        return this.isAccountObject && this.accountAffiliationData && this.accountAffiliationData.length > 0;
    }

    get transformedAccountAffiliationData() {
        if (!this.accountAffiliationData || this.accountAffiliationData.length === 0) {
            return [];
        }

        return this.accountAffiliationData.map((record) => {
            // Compute full address from compound Address field
            let fullAddress = "";
            const addressLines = [];

            // Handle breg_Address__c compound field
            if (record.breg_Address__c) {
                const address = record.breg_Address__c;

                // Street from compound field
                if (address.street) {
                    addressLines.push(address.street);
                }

                // Street 2 from separate field
                if (record.breg_Address_Street_2__c) {
                    addressLines.push(record.breg_Address_Street_2__c);
                }

                // City, State, Postal Code
                const cityStateZip = [];
                if (address.city) {
                    cityStateZip.push(address.city);
                }
                if (address.state) {
                    cityStateZip.push(address.state);
                }
                if (address.postalCode) {
                    cityStateZip.push(address.postalCode);
                }
                if (cityStateZip.length > 0) {
                    addressLines.push(cityStateZip.join(" "));
                }

                // Country
                if (address.country) {
                    addressLines.push(address.country);
                }
            } else if (record.breg_Address_Street_2__c) {
                // If only Street 2 is present
                addressLines.push(record.breg_Address_Street_2__c);
            }

            fullAddress = addressLines.join("\n");

            return {
                ...record,
                fullAddress: fullAddress
            };
        });
    }

    get hasStocks() {
        return this.isAccountObject && this.stockData && this.stockData.length > 0;
    }

    get hasTnTmSm() {
        return this.isAccountObject && this.tnTmSmData && this.tnTmSmData.length > 0;
    }

    get accountAffiliationTableLabel() {
        if (!this.accountAffiliationData || this.accountAffiliationData.length === 0) {
            return this.labels.roleManagersMembers;
        }

        const firstRecord = this.accountAffiliationData[0];
        const role = firstRecord.breg_Role__c;

        switch (role) {
            case "Officer/Director":
            case "Officer":
            case "Director":
                return this.labels.roleOfficers;
            case "General Partner":
            case "Partner":
                return this.labels.rolePartners;
            case "Member":
            case "Manager":
                return this.labels.roleManagersMembers;
            default:
                return this.labels.roleOfficers;
        }
    }

    get displayGoodStandingMessage() {
        return this.goodStandingMessage || this.labels.notInGoodStanding;
    }

    handleShowOfficeInfo() {
        this.showOfficeInfoModal = true;
    }

    handleCloseOfficeInfo() {
        this.showOfficeInfoModal = false;
    }

    handleAnnualReport() {
        let fileNumber = this.companyInfoFields.find((field) => field.label === "File Number")?.value?.split(" ")[0];
        window.location.href = `/manage?section=annual-report&page=details&file-number=${fileNumber}&account-id=${this.recordId}`;
    }

    handleReceiveReminders() {
        if (!this.recordId) {
            console.error("Receive Reminders error: Missing recordId");
            return;
        }
        window.location.href = `/manage?section=notifications&page=select&account-id=${this.recordId}`;
    }

    handleDownloadCompanyInfoPdf() {
        if (!this.recordId) {
            console.error("PDF error: Missing recordId");
            return;
        }

        this.isDownloading = true;
        generateCompanyInfoPdf({ entityId: this.recordId })
            .then((base64Data) => {
                const byteArray = Uint8Array.from(atob(base64Data), (char) => char.charCodeAt(0));
                const blob = new Blob([byteArray], { type: "application/pdf" });
                const blobUrl = URL.createObjectURL(blob);

                const entityName =
                    this.companyInfoFields.find((field) => field.label === "Entity Name")?.value ||
                    this.recordId;

                const safeFileBase = String(entityName).replace(/[^a-zA-Z0-9-_ ]/g, "_").trim().slice(0, 230);
                const link = document.createElement("a");

                link.href = blobUrl;
                link.download = `${safeFileBase} - CompanyInfo.pdf`;

                document.body.appendChild(link);
                link.click();
                document.body.removeChild(link);

                URL.revokeObjectURL(blobUrl);
                this.isDownloading = false;
            })
            .catch((error) => {
                console.error("PDF error:", error);
                this.isDownloading = false;
            });
    }
}