import { LightningElement } from 'lwc';
import getPickListValuesIntoList from "@salesforce/apex/CreateRecordCont.getPickListValuesIntoList";
import getApplicationRecordTypes from "@salesforce/apex/GeneratePicklistOptionsCont.getApplicationRecordTypes";
import createFieldOptions from "@salesforce/apex/GeneratePicklistOptionsCont.createFieldOptions";
import createInstructions from "@salesforce/apex/GeneratePicklistOptionsCont.updateInstructions";
const appMetaDataName = "APPLICATION FOR LICENSE BY EXAM - NURSE";
const affectedFieldName = "MethodOfLicensure";
const dependingFieldName = "Select License Type";
const secondDependingFieldName = "SelectLicenseType";
const instructionInfo = "InstructionsInfo";

export default class GeneratePicklistOptions extends LightningElement {
    connectedCallback() {
        this.getRT();
    }
    async getRT() {
        const rtTypes = await getApplicationRecordTypes();
        rtTypes.forEach( recordTypeName => {
            this.getPicklistVal(recordTypeName);
        });
        createInstructions({appMetaDataName, affectedFieldName: "instructionInfo", dependingFieldName: "MethodOfLicensure", secondDependingFieldName});
    }
    async getPicklistVal(recordTypeName) {
        const objectType = "Application__c";
        const selectedField = "MethodofLicensure__c";
        const str = await getPickListValuesIntoList({objectType, selectedField, recordTypeName});
        const obj = JSON.parse(str);
        const optionValues = obj.values;
        
        const values = optionValues.reduce((result, item) => [...result, item.value], []) ;
        console.log("values", values);
        
        createFieldOptions({values, recordTypeName, appMetaDataName,
            dependingFieldName, affectedFieldName});
    }
}