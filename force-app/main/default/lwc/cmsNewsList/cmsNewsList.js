import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation'
import communityPath from '@salesforce/community/basePath';
console.log(communityPath)
import getContentCollectionApex from '@salesforce/apex/ManagedContentController.getContentCollection';
import { htmlDecode, deffer } from "c/utils";
const MAX_LENGTH = 355

export default class CmsNewList extends NavigationMixin(LightningElement) {
  @api pageSize

  loading = true
  currentPage = 1
  news = []
  totalPage = 1

  page = 0
  topic

  @wire(CurrentPageReference)
  setCurrentPageReference(pageRef) {
    this.pageRef = pageRef
    let page = parseInt(pageRef.state.page)
    this.currentPage = Number.isInteger(page) ? page : 1
    this.topic = pageRef.state.division ?? ''
  }

  get pageData() {
    return this.news.slice((this.currentPage - 1) * this.pageSize, this.currentPage * this.pageSize)
  }




  @wire(getContentCollectionApex, {
    page: '$page',
    pageSize: 250,
    topic: '$topic',
    filterby: 'DCCA_News'
  })

  async getContentCollection({ error, data }) {
    if (error) {
      this.loading = false
    } else if (data) {
      this.nextUrl = data.nextPageUrl
      const news = [...this.news]
      for (let index = 0; index < data.items.length; index++) {
        const row = data.items[index]
        let excerpt = htmlDecode(htmlDecode(row.contentNodes.Excerpt ? row.contentNodes.Excerpt.value : ''))
        excerpt = excerpt.length > MAX_LENGTH ? (excerpt.substring(0, MAX_LENGTH) + '...') : excerpt
        let imgSrc = row.contentNodes.Image ? row.contentNodes.Image.unauthenticatedUrl : ''
        const link = await this[NavigationMixin.GenerateUrl]({
          type: 'standard__managedContentPage',
          attributes: {
            contentTypeName: 'DCCA_News',
            contentKey: row.contentKey
          }
        })
        news.push({
          id: row.contentKey,
          link,
          order: index,
          image: imgSrc ? `/sfsites/c${imgSrc}` : '',
          excerpt,
          title: htmlDecode(htmlDecode(row.title)),
          publishedDate: row.publishedDate,
          date1: row.contentNodes.Date1?.value?.split('T').shift() ?? ''
        })
      }
      news.sort((a, b) => a.date1 < b.date1 ? 1 : -1)
      this.news = news
      this.totalPage = ~~((this.news.length + this.pageSize - 1) / this.pageSize)
      if (this.currentPage > this.totalPage) this.navPage(null, this.totalPage)
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
    event?.stopPropagation()
    event?.preventDefault()
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
    return this.currentPage < this.totalPage
  }

  get previousQuickLinks() {
    if (this.currentPage == 1) return []
    return [this.currentPage - 3, this.currentPage - 2, this.currentPage - 1].filter(item => item > 0).map(item => `${item}`)
  }

  get nextQuickLinks() {
    if (!this.hasNext) return []
    return [this.currentPage + 1, this.currentPage + 2, this.currentPage + 3].filter(item => item <= this.totalPage).map(item => `${item}`)
  }
}