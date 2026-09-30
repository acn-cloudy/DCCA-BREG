import { LightningElement, track } from "lwc";
import performNameSearch from "@salesforce/apex/BREGNameClearanceController.performNameSearch";
import performSearchLogSearch from "@salesforce/apex/BREGNameClearanceController.performSearchLogSearch";

export default class BregNameClearenceSearchComponent extends LightningElement {
    @track searchTerm = "";
    @track selectedMatchType = "alphabetical";
    @track selectedDataSources = ["current", "historical", "reservations"];
    @track searchResults = [];
    @track isLoading = false;
    @track errorMessage = "";
    @track searchStatus = "idle"; // idle, success, error
    @track totalCount = 0;

    // Handle search term input
    handleTermSearch(event) {
        this.searchTerm = event.detail.searchTerm;
    }

    // Handle search execution
    async handleSearch(event) {
        if (!this.searchTerm || this.searchTerm.trim().length < 2) {
            this.showError("Please enter at least 2 characters to search");
            return;
        }

        this.isLoading = true;
        this.errorMessage = "";
        this.searchStatus = "idle";
        this.searchResults = [];
        this.totalCount = 0;

        try {
            const searchParams = {
                searchTerm: this.searchTerm.trim(),
                matchType: this.selectedMatchType,
                dataSources: this.selectedDataSources,
                maxResults: 2000
            };

            console.debug("Search Parameters:", JSON.stringify(searchParams));
            let results = [];
            if (this.selectedMatchType === "alphabetical") {
                searchParams.searchField = "breg_Search_Name_NS__c";
                results.push(await performNameSearch({ request: searchParams }));
                searchParams.searchField = "breg_Search_Xref_Name_1_NS__c";
                results.push(await performNameSearch({ request: searchParams }));
                searchParams.searchField = "breg_Search_Xref_Name_2_NS__c";
                results.push(await performNameSearch({ request: searchParams }));
            } else {
                results.push(await performNameSearch({ request: searchParams }));
            }

            // Search historical search-log records for the same term
            if (this.selectedDataSources.includes("current")) {
                const searchLogParams = {
                    searchTerm: searchParams.searchTerm,
                    matchType: this.selectedMatchType,
                    dataSources: ['searchLog'],
                    maxResults: searchParams.maxResults
                };
                results.push(await performSearchLogSearch({ request: searchLogParams }));
            }

            if (results && results.length) {
                results.forEach((result, index) => {
                    console.debug(`Result ${index + 1}:`, JSON.stringify(result));
                    if (!result || !result.success) {
                        console.warn(`No results returned for search field ${result.errorMessage || "unknown error"}`);
                        return;
                    }
                    this.searchResults.push(...(result.results || []));
                    this.totalCount += result.totalCount || 0;
                    this.searchStatus = "success";
                });

                // Update the results table pagination
                if (this.totalCount > 2000) {
                    this.totalCount = 2000; // Cap total count at 2000 for pagination purposes
                }
                const resultsTable = this.template.querySelector("c-breg_-name-clearence-search-results-table");
                console.debug("Updating results table with", this.searchResults.length, "results");
                if (resultsTable) {
                    resultsTable.updateResults(this.searchResults);
                }

                if (this.searchResults.length === 0) {
                    this.errorMessage = "No results found for your search criteria";
                }
            }
        } catch (error) {
            console.error("Search error:", error);
            this.handleSearchError(this.extractErrorMessage(error));
        } finally {
            this.isLoading = false;
        }
    }

    // Handle filter changes
    handleFilterChange(event) {
        const { filterType, value } = event.detail;

        if (filterType === "matchType") {
            this.selectedMatchType = value;
        } else if (filterType === "dataSources") {
            this.selectedDataSources = [...value];
        }

        // Auto-search if there's already a search term
        // if (this.searchTerm && this.searchTerm.trim().length >= 2) {
        //     this.handleSearch();
        // }
    }

    handleSearchError(errorMsg) {
        this.searchStatus = "error";
        this.errorMessage = errorMsg;
        this.searchResults = [];
        this.totalCount = 0;
    }

    showError(message) {
        this.errorMessage = message;
        this.searchStatus = "error";
    }

    extractErrorMessage(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        if (error?.message) {
            return error.message;
        }
        return "An unexpected error occurred during the search";
    }
}