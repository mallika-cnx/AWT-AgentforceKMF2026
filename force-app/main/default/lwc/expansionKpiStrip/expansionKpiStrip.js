import { LightningElement, api } from 'lwc';
 
export default class ExpansionKpiStrip
        extends LightningElement {
    @api totalSites = 0;
    @api highPotential = 0;
    @api blindSpots = 0;
    @api avgPayback = 'N/A';
}