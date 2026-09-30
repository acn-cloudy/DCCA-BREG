import { LightningElement, track, api } from "lwc";
import getSearchResults from "@salesforce/apex/LookupService.getSearchResults";
export default class XLookup extends LightningElement {
  @track state = {};

  @api fieldList;
  @api sobjectName;
  @api recordType;
  @api fieldsToSearch;
  @api extraCondition;
  @api iconName;
  @api placeholder;
  @api searchResultSelectHandler;
  @api label;
  @api searchResultTitleFormatter;
  @api searchResultSubtitleFormatter;

  @api
  get selectedRecord() {
    return this.state.selectedRecord;
  }
  set selectedRecord(value) {
    this.state.selectedRecord = value;
  }

  @track isLoading;
  @track searchResults = [];
  @track shouldShowDropDown = false;
  @track searchTerm = "";

  get pillItem() {
    return this.state.selectedRecord
      ? [
          {
            type: "icon",
            label: this.state.selectedRecord.Name,
            iconName: this.iconName
          }
        ]
      : [];
  }

  search(event) {
    const searchTerm = event.target.value;
    this.searchTerm = searchTerm;
    if (searchTerm.length >= 1) {
      this.debouncedSearchHandler(searchTerm);
    }
  }
  debounce(func, wait, immediate) {
    var timeout;
    return function () {
      var context = this,
        args = arguments;
      var later = function () {
        timeout = null;
        if (!immediate) func.apply(context, args);
      };
      var callNow = immediate && !timeout;
      clearTimeout(timeout);
      // eslint-disable-next-line @lwc/lwc/no-async-operation
      timeout = setTimeout(later, wait);
      if (callNow) func.apply(context, args);
    };
  }

  focusOnSearchInput() {
    const searchInput = this.template.querySelector("input");
    if (searchInput) {
      searchInput.focus();
    }
  }

  clearSearchTerm() {
    this.searchTerm = "";
    this.focusOnSearchInput();
  }

  // eslint-disable-next-line no-undef
  debouncedSearchHandler = this.debounce(this.handleSearch, 200);

  async handleSearch(searchTerm) {
    const {
      fieldList,
      sobjectName,
      recordType,
      fieldsToSearch,
      extraCondition
    } = this;

    this.isLoading = true;
    this.openSearchResultsList();

    try {
      const result = await getSearchResults({
        searchTerm,
        fieldList,
        sobjectName,
        recordType,
        fieldsToSearch,
        extraCondition
      });
      this.searchResults = this.formatSearchRecordsForDisplay(result);
      if (this.searchResults.length === 0) {
        this.closeSearchResultsList();
      }
    } catch (error) {
      // eslint-disable-next-line no-console
      console.log(JSON.parse(JSON.stringify(error)));
    } finally {
      this.isLoading = false;
    }
  }

  // takes the records returned from the search and concatanates the data contained
  // in the queried fields (except 'Id', 'Name', 'FirstName' and 'LastName') joins it with a '|' for diplay
  // and puts in in a new field called 'additionalFieldData'
  defaultSearchResultSubtitleFormatter = (record) => {
    const additionalFieldData = Object.entries(record)
      .filter(
        ([key, value]) =>
          !!(!["Id", "Name", "FirstName", "LastName"].includes(key) && !!value)
      )
      .reduce((acc, [, value]) => {
        return acc ? `${acc}  ·  ${value}` : `${value}`;
      }, "");
    return additionalFieldData;
  };

  defaultSearchResultTitleFormatter = (record) => record.Name;

  formatSearchRecordsForDisplay(records) {
    const titleMapper =
      typeof this.searchResultTitleFormatter === "function"
        ? this.searchResultTitleFormatter
        : this.defaultSearchResultTitleFormatter;

    const subtitleMapper =
      typeof this.searchResultSubtitleFormatter === "function"
        ? this.searchResultSubtitleFormatter
        : this.defaultSearchResultSubtitleFormatter;

    const titles = records.map(titleMapper);
    const subtitles = records.map(subtitleMapper);

    return records.map((record, index) => ({
      ...record,
      title: titles[index],
      subtitle: subtitles[index]
    }));
  }

  handleSearchResultSelect(event) {
    var isOnFocusInitialValue = event.detail === 0;

    if (!isOnFocusInitialValue) {
      this.state.selectedRecord = event.detail;
      if (typeof this.searchResultSelectHandler === "function") {
        this.searchResultSelectHandler(event.detail);
      }
      this.closeSearchResultsList();
    }
  }

  handleItemRemove() {
    this.state.selectedRecord = null;
    const listOfFieldsToSearch = this.fieldList
      .split(",")
      .map((field) => field.trim());
    const emptyFieldsRecord = listOfFieldsToSearch.reduce(
      (acc, field) => ({ ...acc, [field]: "" }),
      {}
    );
    if (typeof this.searchResultSelectHandler === "function") {
      this.searchResultSelectHandler(emptyFieldsRecord);
    }
    this.clearSearchTerm();
  }

  openSearchResultsList() {
    if (this.searchResults.length > 0 || this.isLoading) {
      this.shouldShowDropDown = true;
    }
  }

  closeSearchResultsList() {
    this.shouldShowDropDown = false;
  }
}