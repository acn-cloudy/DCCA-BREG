import { LightningElement, api, track } from 'lwc';
import queryPageUnwrapped from '@salesforce/apex/BREGBigObjectRelatedListController.queryPageUnwrapped';
import getFieldLabels from '@salesforce/apex/BREGBigObjectRelatedListController.getFieldLabels';

export default class BigObjectRelatedList extends LightningElement {
    // Inputs
    @api recordId;
    @api bigObjectApiName;
    @api keyFieldApiName;
    @api displayFields; // comma-separated
    @api heightPx = 360;

    // State
    @track columns = [];
    @track rows = [];
    @track warning;

    pageSize = 10;
    pageSizeOptions = [
        { label: '10', value: 10 },
        { label: '50', value: 50 },
        { label: '200', value: 200 }
    ];

    sortedBy;
    sortedDirection = 'asc';

    // keyset cursors
    nextCursor = null;
    prevCursor = null;

    isLoading = false;
    fetchedCount = 0;

    get hostStyle() {
        return `min-height:${this.heightPx}px;`;
    }
    get tableContainerStyle() {
        return `height:${this.heightPx - 90}px; overflow:auto;`;
    }
    get pageFieldList() {
        return (this.displayFields || '')
            .split(',')
            .map(s => s.trim())
            .filter(Boolean);
    }

    get isPrevDisabled() {
        return !this.prevCursor;
    }
    get isNextDisabled() {
        return !this.nextCursor;
    }

    connectedCallback() {
        // Initial sort default: first display field or key field
        this.sortedBy = this.pageFieldList[0] || this.keyFieldApiName;
        this.initColumns().then(() => this.loadFirstPage());
    }

    async initColumns() {
        if (!this.bigObjectApiName) return;
        const fields = Array.from(new Set([...this.pageFieldList, this.sortedBy]));
        try {
            const labelsMap = await getFieldLabels({
                bigObjectApiName: this.bigObjectApiName,
                fieldApiNames: fields
            });
            this.columns = this.pageFieldList.map(api => ({
                label: labelsMap[api] || api,
                fieldName: api,
                sortable: true
            }));
        } catch (e) {
            // Fallback if describe fails
            this.columns = this.pageFieldList.map(api => ({
                label: api, fieldName: api, sortable: true
            }));
        }
    }

    async loadFirstPage() {
        this.nextCursor = null;
        this.prevCursor = null;
        await this.loadPage(/*isNext*/true, /*cursor*/null);
    }

    async loadPage(isNext, cursor) {
        this.isLoading = true;
        console.log(`Loading page: isNext=${isNext}, cursor=${cursor}`);
        console.log(`  this.bigObjectApiName=${this.bigObjectApiName}`);
        try {
            const result = await queryPageUnwrapped({
                    bigObjectApiName: this.bigObjectApiName,
                    keyFieldApiName: this.keyFieldApiName,
                    keyFieldValue: this.recordId,
                    fieldApiNames: this.pageFieldList,
                    pageSize: Number(this.pageSize),
                    sortFieldApiName: this.sortedBy,
                    sortDirection: (this.sortedDirection || 'asc').toUpperCase(),
                    cursorValue: cursor,
                    isNext: isNext
                });

            this.warning = result.warning;

            const data = (result.rows || []).map((r, idx) => {
                const row = Object.assign({}, r.values || {});
                // Ensure each row has a stable key for lightning-datatable
                row.__rowKey = `${this.sortedBy}:${row[this.sortedBy]}:${idx}`;
                return row;
            });

            this.rows = data;
            this.fetchedCount = result.fetchedCount || 0;

            // For first page, we get both prev and next from result.
            // For navigation, we use the returned cursors directly.
            this.prevCursor = result.prevCursor || null;
            this.nextCursor = result.nextCursor || null;

            // If user clicked Prev, we reversed the operator in Apex,
            // but the order still follows sortedDirection; nothing to reverse here.
        } catch (e) {
            // Surface a minimal error as warning
            console.error('Error loading data', e);
            this.warning = (e && e.body && e.body.message) ? e.body.message : 'Error loading data.';
            this.rows = [];
            this.fetchedCount = 0;
            this.prevCursor = null;
            this.nextCursor = null;
        } finally {
            this.isLoading = false;
        }
    }

    handleSort(evt) {
        const { fieldName, sortDirection } = evt.detail;
        this.sortedBy = fieldName;
        this.sortedDirection = sortDirection;
        this.loadFirstPage();
    }

    handlePageSizeChange(evt) {
        this.pageSize = Number(evt.detail.value);
        this.loadFirstPage();
    }

    handleNext() {
        this.loadPage(true, this.nextCursor);
    }

    handlePrev() {
        this.loadPage(false, this.prevCursor);
    }
}