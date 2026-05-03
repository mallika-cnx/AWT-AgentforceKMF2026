import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
export default class ExpansionSiteCard extends NavigationMixin(LightningElement) {
    @api site;

    handleClick() {
        console.log('expansionSiteCard: View details clicked', {
            id: this.site?.id,
            name: this.site?.name,
            addressRaw: this.site?.address
        });

        // If caller listens for a card-click event, still dispatch for backward compatibility
        this.dispatchEvent(new CustomEvent('card-click', { detail: this.site?.id }));

        // Also navigate to the record page if an id is present
        if (this.site?.id) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.site.id,
                    objectApiName: 'Potential_Site__c',
                    actionName: 'view'
                }
            });
        }
    }

    handleKeyPress(event) {
        // Support Enter and Space to activate the link via keyboard
        if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            this.handleClick();
        }
    }

    get sanitizedAddress() {
        if (!this.site || !this.site.address) return '';
        // Replace HTML <br> tags and escaped variants with a comma + space
        return this.site.address
            .replace(/<br\s*\/?>/gi, ', ')
            .replace(/<br\s*\/?>/gi, ', ')
            .replace(/\s*,\s*/g, ', ')
            .trim();
    }

    get scoreBarStyle() {
        const score = this.site?.demandScore || 0;
        const color = score >= 80 ? '#1D9E75'
            : score >= 60 ? '#2E75B6'
            : score >= 40 ? '#EF9F27' : '#E24B4A';
        return `width:${score}%;background-color:${color}`;
    }

    get competitionClass() {
        const c = this.site?.competition;
        if (c === 'Low')    return 'badge badge-low';
        if (c === 'Medium') return 'badge badge-medium';
        if (c === 'High')   return 'badge badge-high';
        return 'badge badge-default';
    }

    get tierClass() {
        const t = this.site?.qualityTier;
        if (t === 'Prime')    return 'tier tier-prime';
        if (t === 'Viable')   return 'tier tier-viable';
        if (t === 'Marginal') return 'tier tier-marginal';
        return 'tier tier-poor';
    }

    get formattedRevenue() {
        const r = this.site?.revenueY1 || 0;
        if (r >= 10000000)
            return '₹' + (r/10000000).toFixed(2) + ' Cr';
        if (r >= 100000)
            return '₹' + (r/100000).toFixed(1) + ' L';
        return '₹' + r.toLocaleString('en-IN');
    }

    get formattedPayback() {
        return this.site?.payback > 0
            ? this.site.payback.toFixed(1) + ' yrs'
            : 'TBD';
    }

    get demandScoreDisplay() {
        return ((this.site?.demandScore) || 0).toFixed(0);
    }
}