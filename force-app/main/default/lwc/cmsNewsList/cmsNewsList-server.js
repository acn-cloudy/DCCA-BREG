import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation'
import communityPath from '@salesforce/community/basePath';
console.log(communityPath)
import getContentCollectionApex from '@salesforce/apex/ManagedContentController.getContentCollection';
import { htmlDecode } from "c/utils";
const MAX_LENGTH = 355

export default class CmsNewList extends NavigationMixin(LightningElement) {
  @api pageSize

  loading = true
  currentPage = 1
  news = []
  totalPage = 1

  page

  @wire(CurrentPageReference)
  setCurrentPageReference(pageRef) {
    this.pageRef = pageRef
    let page = parseInt(pageRef.state.page)
    this.currentPage = Number.isInteger(page) ? page : 1
    this.page = this.currentPage - 1
  }

  @wire(getContentCollectionApex, {
    page: '$page',
    pageSize: '$pageSize',
    filterby: 'DCCA_News'
  })

  getContentCollection({ error, data }) {
    if (error) {
      this.loading = false
    } else if (data) {
      this.nextUrl = data.nextPageUrl
      this.news = data.items.map((row, index) => {
        let excerpt = htmlDecode(htmlDecode(row.contentNodes.Excerpt ? row.contentNodes.Excerpt.value : ''))
        excerpt = excerpt.length > MAX_LENGTH ? (excerpt.substring(0, MAX_LENGTH) + '...') : excerpt
        let imgSrc = row.contentNodes.Image ? row.contentNodes.Image.unauthenticatedUrl : ''
        return {
          id: row.contentKey,
          order: index,
          image: imgSrc ? `/sfsites/c${imgSrc}` : '',
          excerpt,
          title: htmlDecode(htmlDecode(row.title)),
          publishedDate: row.publishedDate,
        }
      })
      this.loading = false
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

  hanldePrevious(event) {
    this.navPage(event, this.currentPage - 1)
  }
  handleNext(event) {
    this.navPage(event, this.currentPage + 1)
  }

  handleQuickLink(event) {
    this.navPage(event, parseInt(event.target.dataset.page))
  }

  navPage(event, page) {
    event.stopPropagation()
    event.preventDefault()
    this[NavigationMixin.Navigate]({
      ...this.pageRef,
      state: {
        ...this.pageRef.state,
        page
      }
    })
  }

  get hasPrevious() {
    return this.currentPage > 1
  }
  get hasNext() {
    return !!this.nextUrl
  }

  get previousQuickLinks() {
    if (this.currentPage == 1) return []
    return [this.currentPage - 3, this.currentPage - 2, this.currentPage - 1].filter(item => item > 0).map(item => `${item}`)
  }

  get nextQuickLinks() {
    if (!this.hasNext) return []
    return [this.currentPage + 1].map(item => `${item}`)
  }
}