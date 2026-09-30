import LightningDatatable from "lightning/datatable";
import customSelectRowTemplate from "./customSelectRow.html";
import customNameCellTemplate from "./customNameCell.html";

export default class Breg_CustomDataTable extends LightningDatatable {
    static customTypes = {
        customSelect: {
            template: customSelectRowTemplate,
            standardCellLayout: true,
            typeAttributes: ["disabledItem", "checkedItem", "id", "recordId"]
        },
        customNameButton: {
            template: customNameCellTemplate,
            standardCellLayout: true,
            typeAttributes: ["label", "recordId", "fileNumber", "sourceObject"]
        }
    };
}