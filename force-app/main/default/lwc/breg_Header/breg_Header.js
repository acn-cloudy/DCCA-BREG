import { LightningElement } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import getUserInfo from '@salesforce/apex/BREGPortalUtils.getUserInfo';
import basePath from "@salesforce/community/basePath";

export default class Breg_Header extends NavigationMixin(LightningElement) {
  isNotGuest = false;
  userName = '';
  showDropdown = false;
  isMenuOpen = false;

  async connectedCallback() {
    this.fetchUserInfo();
    console.log("Logout URL: ", this.logoutUrl);
  }

  get logoutUrl() {
    const sitePrefix = basePath.replace("/", "");
    return '/${sitePrefix}vforcesite/secur/logout.jsp';
  }

  async fetchUserInfo() {
    try {
      const result = await getUserInfo();
      this.isNotGuest = !result.isGuest;
      if (this.isNotGuest) {
        this.userName = result.name;
      }
    } catch (error) {
      console.error('Error fetching user info', error);
    }
  }

  get userInitials() {
    if (this.userName) {
      return this.userName
        .split(' ')
        .map((n) => n[0])
        .join('')
        .substring(0, 2)
        .toUpperCase();
    }
    return '';
  }

  async handleLogout() {
    if (window.innerWidth <= 768) {
      this.closeMenu();
    }
    localStorage.removeItem('breg_shopping_cart');
    window.location.href = this.logoutUrl;
  }

  toggleDropdown() {
    this.showDropdown = !this.showDropdown;
  }

  handleLoginClick() {
    if (window.innerWidth <= 768) {
      this.closeMenu();
    }

    this[NavigationMixin.Navigate]({
            type: "comm__namedPage",
            attributes: {
                name: "Login"
            }
    });
  }

  handleEditAccount() {
    if (window.innerWidth <= 768) {
      this.closeMenu();
    }
    window.location.href = '/account-settings';
  }

  toggleMenu() {
    this.isMenuOpen = !this.isMenuOpen;
  }

  closeMenu() {
    this.isMenuOpen = false;
  }

}