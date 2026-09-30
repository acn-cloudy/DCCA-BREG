import LightningDatatable from "lightning/datatable";
import customNavigationTemplate from "./customNavigationType.html";

export default class ExtendedDataTable extends LightningDatatable {
  static customTypes = {
    navigation: {
      template: customNavigationTemplate,
      typeAttributes: ["label", "recordId", "pageRef"]
    }
  };
}