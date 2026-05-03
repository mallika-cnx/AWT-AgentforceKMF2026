import { LightningElement, track, wire } from 'lwc';
import getSites from '@salesforce/apex/ExpansionDashboardController.getSites';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
 
export default class ExpansionDashboard extends LightningElement {
    @track sites = [];
    @track filteredSites = [];
    @track selectedSite = null;
    @track isLoading = true;
    @track errorMessage = '';
    @track activeTab = 'sites';
    @track searchTerm = '';
    @track competitionFilter = 'All';
    @track regionFilter = '';
 
    wiredSitesResult;
 
    competitionOptions = [
        { label: 'All', value: 'All' },
        { label: 'Low', value: 'Low' },
        { label: 'Medium', value: 'Medium' },
        { label: 'High', value: 'High' },
    ];
 
    @wire(getSites, {
        regionFilter: '$regionFilter',
        statusFilter: '',
        competitionFilter: '$competitionFilter'
    })
    wiredSites(result) {
        this.wiredSitesResult = result;
        this.isLoading = false;
        if (result.data) {
            this.sites = result.data;
            this.applySearch();
            this.errorMessage = '';
        } else if (result.error) {
            this.errorMessage =
                (result.error.body && result.error.body.message) ||
                result.error.message ||
                'Failed to load sites.';
        }
    }
 
    applySearch() {
        if (!this.searchTerm) {
            this.filteredSites = [...this.sites];
            return;
        }
        const term = this.searchTerm.toLowerCase();
        this.filteredSites = this.sites.filter(s =>
            (s.name && s.name.toLowerCase().includes(term)) ||
            (s.address && s.address.toLowerCase().includes(term)) ||
            (s.city && s.city.toLowerCase().includes(term))
        );
    }
 
    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        this.applySearch();
    }
 
    handleCompetitionChange(event) {
        this.competitionFilter = event.detail.value;
    }
 
    handleRegionChange(event) {
        this.regionFilter = event.target.value;
    }
 
    handleRefresh() {
        this.isLoading = true;
        // refreshApex expects the wired result
        refreshApex(this.wiredSitesResult).finally(() => {
            this.isLoading = false;
        });
    }
 
    handleTabChange(event) {
        this.activeTab = event.currentTarget.dataset.tab;
    }
 
    handleSiteSelect(event) {
        // event.detail should be the site wrapper object
        this.selectedSite = event.detail;
    }
 
    handleModalClose() {
        this.selectedSite = null;
    }
 
    handleActionComplete() {
        this.selectedSite = null;
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: 'Decision recorded successfully.',
            variant: 'success'
        }));
        this.handleRefresh();
    }
 
    get isSitesTab() {
        return this.activeTab === 'sites';
    }
    get isMatrixTab() {
        return this.activeTab === 'matrix';
    }
    get sitesTabClass() {
        return this.activeTab === 'sites' ? 'tab-btn tab-active' : 'tab-btn';
    }
    get matrixTabClass() {
        return this.activeTab === 'matrix' ? 'tab-btn tab-active' : 'tab-btn';
    }
    get siteCount() {
        return this.filteredSites ? this.filteredSites.length : 0;
    }
    get showModal() {
        return this.selectedSite !== null;
    }
    get totalSites() { return this.sites ? this.sites.length : 0; }
    get highPotential() {
        return (this.sites || []).filter(s => (s.demandScore || 0) >= 70).length;
    }
    get blindSpots() {
        return (this.sites || []).filter(s => s.blindSpot).length;
    }
    get avgPayback() {
        const scored = (this.sites || []).filter(s => s.payback > 0);
        if (!scored.length) return 'N/A';
        const avg = scored.reduce((a, s) => a + s.payback, 0) / scored.length;
        return avg.toFixed(1) + ' yrs';
    }
}