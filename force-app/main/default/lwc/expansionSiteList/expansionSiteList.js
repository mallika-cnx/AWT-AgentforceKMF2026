import { LightningElement, api } from 'lwc';
 
export default class ExpansionSiteList extends LightningElement {
    @api sites = [];
 
    handleCardClick(event) {
        const siteId = event.detail;
        const site = this.sites.find(s => s.id === siteId);
        if (site) {
            this.dispatchEvent(new CustomEvent('site-select', { detail: site }));
        }
    }
 
    get hasSites() {
        return this.sites && this.sites.length > 0;
    }
}