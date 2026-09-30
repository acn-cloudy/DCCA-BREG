import { LightningElement, api, track, wire } from 'lwc';
import getContent from '@salesforce/apex/ManagedContentController.getContent';
import { htmlDecode } from "c/utils";

export default class CmsIconWithCard extends LightningElement {
  @track contents = []

  @api contentId1
  @api contentId2

  @api title
  @api subTitle1
  @api subTitle2
  @api buttonLabel
  @api buttonLink

  @wire(getContent, { contentId: '$contentId1', page: 0, pageSize: 1, language: 'en_US', filterby: '' })
  setContent1(res) {
    this.addContent(res, 1)
  }

  @wire(getContent, { contentId: '$contentId2', page: 0, pageSize: 1, language: 'en_US', filterby: '' })
  setContent2(res) {
    this.addContent(res, 2)
  }

  addContent({ data, error }, order) {
    if (data) {
      this.contents.push({
        id: data.Image.contentKey,
        order,
        url: `sfsites/c${data.Image.unauthenticatedUrl}`,
        title: htmlDecode(htmlDecode(data.Title.value)),
        link: data.Link.value
      })
      this.contents.sort((c1, c2) => c1.order - c2.order)
    }
    if (error) {
      console.log('Error: ' + JSON.stringify(error));
    }
  }

  get itemClassName() {
    return `item slds-grid slds-grid--vertical slds-grid--vertical-align-center slds-large-size--1-of-4 slds-p-top--large slds-size--1-of-2`
  }
}