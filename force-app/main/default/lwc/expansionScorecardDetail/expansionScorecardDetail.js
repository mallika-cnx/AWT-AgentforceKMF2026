import { LightningElement, api, track } from 'lwc';
import approveSite from
  '@salesforce/apex/ExpansionDashboardController.approveSite';
import rejectSite from
  '@salesforce/apex/ExpansionDashboardController.rejectSite';
 
export default class ExpansionScorecardDetail
        extends LightningElement {
    @api site;
    @track isProcessing = false;
    @track resultMessage = '';
    @track resultType = '';
    @track remarks = '';
 
    rejectionOptions = [
        {label:'High Competition',
         value:'High Competition'},
        {label:'Low Demand Score',
         value:'Low Demand Score'},
        {label:'Unfavourable Financials',
         value:'Unfavourable Financials'},
        {label:'Regulatory Issue',
         value:'Regulatory Issue'},
        {label:'Site Unavailable',
         value:'Site Unavailable'},
        {label:'Other', value:'Other'},
    ];
    @track rejectionReason = 'Other';
 
    handleClose() {
        this.dispatchEvent(
            new CustomEvent('modal-close'));
    }
 
    handleRemarksChange(event) {
        this.remarks = event.target.value;
    }
 
    handleRejectionReasonChange(event) {
        this.rejectionReason = event.detail.value;
    }
 
    async handleApprove() {
        this.isProcessing = true;
        try {
            await approveSite({
                siteId: this.site.id,
                remarks: this.remarks ||
                    'Approved via Expansion Dashboard'
            });
            this.resultMessage =
                'Site approved successfully.';
            this.resultType = 'success';
            this.dispatchEvent(
                new CustomEvent('action-complete'));
        } catch (error) {
            this.resultMessage =
                error.body?.message ||
                'Approval failed. Please try again.';
            this.resultType = 'error';
        } finally {
            this.isProcessing = false;
        }
    }
 
    async handleReject() {
        this.isProcessing = true;
        try {
            await rejectSite({
                siteId: this.site.id,
                rejectionReason: this.rejectionReason,
                remarks: this.remarks ||
                    'Rejected via Expansion Dashboard'
            });
            this.resultMessage = 'Site rejected.';
            this.resultType = 'success';
            this.dispatchEvent(
                new CustomEvent('action-complete'));
        } catch (error) {
            this.resultMessage =
                error.body?.message ||
                'Rejection failed. Please try again.';
            this.resultType = 'error';
        } finally {
            this.isProcessing = false;
        }
    }
 
    get scoreColor() {
        const s = this.site.demandScore || 0;
        return s>=80 ? 'score-prime'
             : s>=60 ? 'score-viable'
             : s>=40 ? 'score-marginal'
             : 'score-poor';
    }
    get formattedRevenue() {
        const r = this.site.revenueY1 || 0;
        if (r>=10000000)
            return '₹'+(r/10000000).toFixed(2)+' Cr';
        if (r>=100000)
            return '₹'+(r/100000).toFixed(1)+' L';
        return '₹'+r.toLocaleString('en-IN');
    }
    get formattedPayback() {
        return this.site.payback > 0
            ? this.site.payback.toFixed(1)+' years'
            : 'Not projected';
    }
    get resultClass() {
        return this.resultType === 'success'
            ? 'result-box result-success'
            : 'result-box result-error';
    }
    get showResult() {
        return this.resultMessage !== '';
    }
    get demandScoreDisplay() {
        return (this.site.demandScore||0).toFixed(0);
    }
}