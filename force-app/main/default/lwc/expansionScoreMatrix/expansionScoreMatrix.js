import { LightningElement, api, track } from 'lwc';
 
export default class ExpansionScoreMatrix
        extends LightningElement {
    @api sites = [];
 
    get lowSites() {
        return this.sites.filter(
            s => s.competition === 'Low'
              && s.demandScore > 0
        );
    }
    get mediumSites() {
        return this.sites.filter(
            s => s.competition === 'Medium'
              && s.demandScore > 0
        );
    }
    get highSites() {
        return this.sites.filter(
            s => s.competition === 'High'
              && s.demandScore > 0
        );
    }
    get matrixRows() {
        const levels = [
            { label: 'High Competition',
              sites: this.highSites,
              rowClass: 'matrix-row row-high' },
            { label: 'Medium Competition',
              sites: this.mediumSites,
              rowClass: 'matrix-row row-medium' },
            { label: 'Low Competition',
              sites: this.lowSites,
              rowClass: 'matrix-row row-low sweet-spot' },
        ];
        return levels.map(level => ({
            ...level,
            cells: this.buildCells(level.sites)
        }));
    }
    buildCells(sites) {
        // 10 columns for demand score bands 0-100
        const cells = Array(10).fill(null).map(
            (_, i) => ({
                band: i * 10,
                label: `${i*10}-${(i+1)*10}`,
                sites: []
            })
        );
        sites.forEach(s => {
            const idx = Math.min(
                Math.floor(s.demandScore / 10), 9);
            cells[idx].sites.push(s);
        });
        return cells.map(c => ({
            ...c,
            cellClass: c.sites.length > 0
                ? 'matrix-cell cell-filled'
                : 'matrix-cell cell-empty',
            count: c.sites.length,
            tooltip: c.sites.map(s => s.name).join(', ')
        }));
    }
    get sweetSpotSites() {
        return this.sites.filter(
            s => s.demandScore >= 70
              && s.competition === 'Low'
        );
    }
    get sweetSpotCount() {
        return this.sweetSpotSites.length;
    }
}