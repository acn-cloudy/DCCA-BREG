import { LightningElement, wire } from 'lwc';
import getRecoveredApps from "@salesforce/apex/sc_AppRecoverController.getAppsInStaticResource"
export default class Sc_appRecover extends LightningElement {
    selectedApps = [];
    appList;
    columns = [
        {label: "Name", fieldName: "name"}]
    @wire(getRecoveredApps)
    wireGetRecoveredApps({error, data}){
        if(data) {
            this.appList = data.reduce( (result, item) => 
                [...result, {name: item}], []);
        } else if(error) {

        }
    }

    getSelectedName(event) {
        const { selectedRows } = event.detail;
        if(selectedRows && selectedRows.length) {
            this.selectedApps = selectedRows.reduce((result, item) => [...result, item.name], []);
        } else {
            this.selectedApps = [];
        }
    }
}