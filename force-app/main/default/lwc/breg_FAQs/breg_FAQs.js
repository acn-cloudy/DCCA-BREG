import { LightningElement, api, wire, track } from 'lwc';
import { Labels } from './labels';
import getArticles from '@salesforce/apex/BREGHelpCenterController.getArticles';

export default class Breg_FAQs extends LightningElement {
    @api topicName; 
    @track articles;
    @track activeTab = '';
    error;
    label = Labels;
    @track allArticles = [];
    @track filteredArticles = [];
    searchTimeout;
    includeDefault = false;

    searchValue = ''
    @track selectedCategory = 'Manage';
    @track categoryOptions = [
        { label: 'Select a Topic', value: 'Manage' },
        { label: 'Annual report', value: 'Annual report' },
        { label: 'Changes', value: 'Changes' }, 
        { label: 'Trade Names & Marks', value: 'Trade Names & Marks' },
        { label: 'Notifications', value: 'Notifications' }
    ];


    connectedCallback() {
        if(this.topicName == 'Search & Buy') {
            this.topicName = 'Business Naming Rules';
            this.activeTab = 'businessNamingRules';
        }
        if (this.topicName == 'Manage'){
            this.includeDefault = true;
        }
        this.getArticlesApex(this.topicName);
    }

    async getArticlesApex(topicName) {
        try {
            this.articles = await getArticles({topicName: topicName, includeDefault: this.includeDefault});
            this.allArticles = this.articles.map(article => {
                if (article.Title === 'All Help Links' || topicName == 'Business Naming Rules') {
                    return {
                        ...article,
                        Title: '',
                        isNotAccordion: true, 
                    };
                } else {
                    return {
                        ...article,
                        Title: article.Title,
                        isNotAccordion: false, 
                    };
                }
            });
            this.filteredArticles = [...this.allArticles];
        } catch(error) {
            console.error(error)
            this.error = this.label.Error_LoadingArticles;
        }
    }

    handleCategoryChange(event) {
        this.selectedCategory = event.detail.value;
        this.topicName = event.detail.value;
        this.includeDefault = this.topicName == 'Manage';
        this.getArticlesApex(this.topicName, this.searchValue);
    }
    handleSearch(event) {
        let newSearchValue = event.target.value?.toLowerCase() || '';
        this.searchValue = !newSearchValue ? '' : newSearchValue;
        
        if(this.searchTimeout) {
            clearTimeout(this.searchTimeout);
        }
        this.searchTimeout = setTimeout(() => {
            this.filteredArticles = this.allArticles.filter(article => {
                const title = article.Title?.toLowerCase() || '';
                const answer = article.Answer?.toLowerCase() || '';
                return title.includes(this.searchValue) || answer.includes(this.searchValue);
            });
        }, 800); 

    }

    handleTabChange(event) {
        this.activeTab = event.target.value;
        if(this.activeTab == 'faqs') {
            this.topicName = 'Search & Buy';
            this.searchValue = '';
        } else {
            this.topicName = 'Business Naming Rules';
            this.searchValue = '';
        }
        
        this.getArticlesApex(this.topicName, this.searchValue);
    }

    get isSearchAndBuyPage() {
        return this.topicName == 'Search & Buy' || this.topicName == 'Business Naming Rules';
    }
    get isNotHomePage() {
        return this.topicName != 'Home';
    }
    get isHomePage() {
        return this.topicName == 'Home';
    }

    get isManagePage() {
        const isManageCategory = this.categoryOptions.some(
            option => option.value === this.topicName
        );
        return isManageCategory;
    }

}