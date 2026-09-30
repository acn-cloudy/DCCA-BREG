import { LightningElement, api } from 'lwc';

export default class Sc_nav_cards extends LightningElement {
    @api cards ;
    currentIndex = 0;

    @api index;
    connectedCallback() {
        if(this.index) {
            this.currentIndex = this.index;
        }
    }
    get displayCards() {
        this.currentIndex = this.currentIndex || 0;
        return this.cards.reduce((result, item, index) => {
            const cItem = JSON.parse(JSON.stringify(item));
            if(index == this.currentIndex) {
                cItem.isCurrent = true;
            }
            result.push(cItem);
            return result;
        }, []);
    }
    @api 
    setupIndex(index) {
        this.currentIndex = index;
    }
    @api 
    setupCards(cards) {
        this.cards = cards;
    }
    handleClick(event) {
        const id = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('cardclick', {detail: {id}}));
    }
 }