import { Labels } from './labels';

export const annualFilingColumns = [
    {
        label: Labels.filingYear,
        fieldName: 'breg_Filing_Year__c',
        type: 'text',
        wrapText: true
    },
    {
        label: Labels.dateReceived,
        fieldName: 'breg_Received_Date__c',
        type: 'date',
        typeAttributes: {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
            timeZone: 'UTC'
        },
        wrapText: true
    },
    {
        label: Labels.status,
        fieldName: 'breg_Status__c',
        type: 'text',
        wrapText: true
    }
];

export const otherFilingColumns = [
    {
        label: Labels.date,
        fieldName: 'breg_Effective_Date__c',
        type: 'date',
        typeAttributes: {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
            timeZone: 'UTC'
        },
        wrapText: true
    },
    {
        label: Labels.description,
        fieldName: 'breg_Description__c',
        type: 'text',
        wrapText: true
    },
    {
        label: Labels.remarks,
        fieldName: 'breg_Remarks__c',
        type: 'text',
        wrapText: true
    }
];

export const accountAffiliationColumns = [
    {
        label: Labels.name,
        fieldName: 'breg_Affiliation_Name__c',
        type: 'text',
        wrapText: true
    },
    {
        label: Labels.office,
        fieldName: 'breg_Officer_Director_Titles__c',
        type: 'text',
        wrapText: true
    },
    {
        label: Labels.date,
        fieldName: 'breg_Start_Date__c',
        type: 'date',
        typeAttributes: {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
            timeZone: 'UTC'
        },
        wrapText: true
    },
    
];

export const stockColumns = [
    {
        label: Labels.date,
        fieldName: 'breg_Start_Date__c',
        type: 'date',
        typeAttributes: {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
            timeZone: 'UTC'
        },
        wrapText: true
    },
    {
        label: Labels.class,
        fieldName: 'breg_Class_Detail__c',
        type: 'text',
        wrapText: true
    },
    {
        label: Labels.shares,
        fieldName: 'breg_Number_of_Issued_Shares__c',
        type: 'number',
        wrapText: true
    },
    {
        label: Labels.paidShares,
        fieldName: 'breg_Paid_Shares__c',
        type: 'number',
        wrapText: true
    },
    {
        label: Labels.perValue,
        fieldName: 'breg_Per_Value__c',
        type: 'number',
        wrapText: true
    },
    {
        label: Labels.stockAmount,
        fieldName: 'breg_Stock_Amount__c',
        type: 'number',
        wrapText: true
    }
];

export const tnTmSmColumns = [
    {
        label: Labels.name,
        fieldName: 'nameUrl',
        type: 'url',
        typeAttributes: {
            label: { fieldName: 'breg_Trade_Name__c' },
            target: '_blank'
        },
        wrapText: true
    },
    {
        label: Labels.type,
        fieldName: 'breg_Type__c',
        type: 'text',
        wrapText: true
    },
    {
        label: Labels.category,
        fieldName: 'breg_TM_SM_Category__c',
        type: 'text',
        wrapText: true
    },
    {
        label: Labels.certificateNumber,
        fieldName: 'breg_Cert_Number__c',
        type: 'text',
        wrapText: true
    },
    {
        label: Labels.status,
        fieldName: 'breg_Status__c',
        type: 'text',
        wrapText: true
    },
    {
        label: Labels.registrationDate,
        fieldName: 'breg_Registration_Date__c',
        type: 'date',
        typeAttributes: {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
            timeZone: 'UTC'
        },
        wrapText: true
    },
    {
        label: Labels.expirationDate,
        fieldName: 'breg_Expiration_Date__c',
        type: 'date',
        typeAttributes: {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
            timeZone: 'UTC'
        },
        wrapText: true
    }
];

export const buyAvailableDocsColumns = [
    {
        label: Labels.date,
        fieldName: 'effectiveDate',
        type: 'date',
        typeAttributes: {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
            timeZone: 'UTC'
        },
        wrapText: true
    },
    {
        label: Labels.documentAndTradeName,
        fieldName: 'documentAndTradeName',
        type: 'text',
        wrapText: true
    },
    {
        label: Labels.availability,
        fieldName: 'availability',
        type: 'text',
        wrapText: true
    },
     {
        label: Labels.certify,
        fieldName: 'isAvailableToCertify',
        type: 'boolean',
        wrapText: false
    },
    {
        label: Labels.purchase,
        fieldName: 'purchase',
        type: 'text',
        wrapText: true
    }
];