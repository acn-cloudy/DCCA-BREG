import { LightningElement, api, track } from 'lwc';

const PAGE_SIZE_OPTIONS = [
    { label: '25', value: '25' },
    { label: '50', value: '50' },
    { label: '100', value: '100' }
];

export default class Breg_DatatableWithPagination extends LightningElement {
    @api keyField = 'Id';
    @api columns = [];
    @api hideCheckboxColumn = false;

    _pageSize = 25;
    @track currentPage = 1;
    @track _data = [];

    pageSizeOptions = PAGE_SIZE_OPTIONS;

    get pageSizeString() {
        return String(this._pageSize);
    }

    @api
    get pageSize() {
        return this._pageSize;
    }
    set pageSize(value) {
        this._pageSize = value > 0 ? value : 10;
        this.currentPage = 1;
    }

    handlePageSizeChange(event) {
        this._pageSize = Number(event.detail.value);
        this.currentPage = 1;
    }

    @api
    get data() {
        return this._data;
    }
    set data(value) {
        this._data = Array.isArray(value) ? value : [];
        this.currentPage = 1;
    }

    get pagedData() {
        const start = (this.currentPage - 1) * this._pageSize;
        return this._data.slice(start, start + this._pageSize);
    }

    get totalPages() {
        return Math.max(1, Math.ceil(this._data.length / this._pageSize));
    }

    get showPagination() {
        return this._data.length > this._pageSize;
    }

    get isFirstPage() {
        return this.currentPage === 1;
    }

    get isLastPage() {
        return this.currentPage >= this.totalPages;
    }

    get startRecord() {
        return this._data.length > 0 ? (this.currentPage - 1) * this._pageSize + 1 : 0;
    }

    get endRecord() {
        return Math.min(this.currentPage * this._pageSize, this._data.length);
    }

    get pageInfo() {
        return `${this.startRecord}-${this.endRecord} of ${this._data.length}`;
    }

    handlePrevious() {
        if (!this.isFirstPage) {
            this.currentPage -= 1;
        }
    }

    handleNext() {
        if (!this.isLastPage) {
            this.currentPage += 1;
        }
    }
}