import { LightningElement, api, track, wire } from 'lwc';
import getContent from '@salesforce/apex/ManagedContentController.getContent';
import getContentList from '@salesforce/apex/ManagedContentController.getContentList';
import { htmlDecode } from "c/utils";
import { NavigationMixin } from 'lightning/navigation'

export default class CmsNews extends NavigationMixin(LightningElement) {
  @track contents = []

  @api contentId1
  @api contentId2
  @api contentId3
  @api contentId4

  // @wire(getContent, { contentId: '$contentId1', page: 0, pageSize: 1, language: 'en_US', filterby: '' })
  // setContent1(res) {
  //   this.addContent(res, 1)
  // }

  // @wire(getContent, { contentId: '$contentId2', page: 0, pageSize: 1, language: 'en_US', filterby: '' })
  // setContent2(res) {
  //   this.addContent(res, 2)
  // }

  // @wire(getContent, { contentId: '$contentId3', page: 0, pageSize: 1, language: 'en_US', filterby: '' })
  // setContent3(res) {
  //   this.addContent(res, 3)
  // }

  // @wire(getContent, { contentId: '$contentId4', page: 0, pageSize: 1, language: 'en_US', filterby: '' })
  // setContent4(res) {
  //   this.addContent(res, 4)
  // }

  async connectedCallback() {
    const res = await getContentList({
      pageSize: 250,
      filterby: 'DCCA_News'
    })
    this.contents = (await Promise.all(res.map(async (row, index) => {
      const link = await this[NavigationMixin.GenerateUrl]({
        type: 'standard__managedContentPage',
        attributes: {
          contentTypeName: 'DCCA_News',
          contentKey: row.contentKey
        }
      })
      return {
        id: row.contentKey,
        order: index,
        title: htmlDecode(htmlDecode(row.title)),
        publishedDate: row.publishedDate,
        date1: row.contentNodes?.Date1?.value?.split('T').shift() ?? '',
        link
      }
    }))).sort((a, b) => a.date1 < b.date1 ? 1 : -1).slice(0, 4)
  }


  addContent({ data, error }, order) {
    if (data) {
      this.contents.push({
        id: data.$meta.id,
        order,
        title: htmlDecode(htmlDecode(data.title.value)),
        publishedDate: data.$meta.publishedDate,
      })
      this.contents.sort((c1, c2) => c1.order - c2.order)
    }
    if (error) {
      console.log('Error: ' + JSON.stringify(error));
    }
  }

  handleNavDetail(event) {
    event.stopPropagation()
    event.preventDefault()
    this[NavigationMixin.Navigate]({
      type: 'standard__managedContentPage',
      attributes: {
        contentTypeName: 'DCCA_News',
        contentKey: event.target.dataset.contentKey
      }
    });
  }

  handleNavAll(event) {
    event.stopPropagation()
    event.preventDefault()
    this[NavigationMixin.Navigate]({
      type: 'comm__namedPage',
      attributes: {
        name: 'DCCA_News_List__c'
      }
    })
  }

  get itemClassName() {
    return `slds-grid slds-grid--vertical slds-large-size--1-of-4 slds-size--1-of-1`
  }
}