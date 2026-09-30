import { LightningElement, api } from "lwc";

export default class LookupSearchResult extends LightningElement {
  @api iconName;
  @api record;
  @api searchTerm;

  renderedCallback() {
    const nameNode = this.template.querySelector(".search-result-name");
    // eslint-disable-next-line @lwc/lwc/no-inner-html
    nameNode.innerHTML = this._highlightSubstring(
      this.record.title,
      this.searchTerm
    );
    const addtionalFieldsDataNode = this.template.querySelector(
      ".search-result-additional-data"
    );
    // eslint-disable-next-line @lwc/lwc/no-inner-html
    addtionalFieldsDataNode.innerHTML = this._highlightSubstring(
      this.record.subtitle,
      this.searchTerm
    );
  }

  selectedHandler() {
    const selectedEvent = new CustomEvent("selected", { detail: this.record });
    this.dispatchEvent(selectedEvent);
  }

  _highlightSubstring(baseString = "", subString = "") {
    const subStrIndex = baseString
      .toUpperCase()
      .indexOf(subString.toUpperCase());
    const portionToHighlight = baseString.slice(
      subStrIndex,
      subStrIndex + subString.length
    );
    return baseString.replace(
      portionToHighlight,
      `<b>${portionToHighlight}</b>`
    );
  }
}