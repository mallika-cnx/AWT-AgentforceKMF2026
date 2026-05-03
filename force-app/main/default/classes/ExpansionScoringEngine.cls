// Class name : ExpansionScoringEngine
// Created Date: 22/04/2026
// Author: Arnab Saha - CNX
// Description: Calculation of Site Score

public class ExpansionScoringEngine {

    private static final Decimal DEFAULT_SCORE = 50.0;
    private static final Decimal DEMAND_WEIGHT  = 0.90;
    private static final Decimal COMP_WEIGHT    = 0.10;

    @InvocableMethod(label='Score Expansion Site')
    public static List<ScorecardResult> scoreSite(
            List<SiteInput> inputs) {

        List<ScorecardResult> results =
            new List<ScorecardResult>();

        // Collect site IDs
        Set<Id> siteIds = new Set<Id>();
        for (SiteInput inp : inputs)
            if (inp.siteId != null)
                siteIds.add(inp.siteId);

        // SOQL 1 — all sites
        Map<Id, Potential_Site__c> siteMap =
            new Map<Id, Potential_Site__c>([
                SELECT Id, PIN_Code__c
                FROM Potential_Site__c
                WHERE Id IN :siteIds
            ]);

        // Collect PIN codes
        Set<String> pins = new Set<String>();
        for (Potential_Site__c s : siteMap.values())
            if (String.isNotBlank(s.PIN_Code__c))
                pins.add(s.PIN_Code__c);

        // SOQL 2 — all demographics
        Map<String, Demographic_Profile__c> demMap =
            new Map<String, Demographic_Profile__c>();
        if (!pins.isEmpty()) {
            for (Demographic_Profile__c d : [
                SELECT PIN_Code__c,
                       Composite_Demand1__c
                FROM Demographic_Profile__c
                WHERE PIN_Code__c IN :pins
            ]) demMap.put(d.PIN_Code__c, d);
        }

        // SOQL 3 — all competitors
        Map<Id, List<Competitor_Proximity__c>>
            compMap =
            new Map<Id,
                List<Competitor_Proximity__c>>();
        for (Competitor_Proximity__c c : [
            SELECT Potential_Site__c,
                   Threat_Score__c
            FROM Competitor_Proximity__c
            WHERE Potential_Site__c IN :siteIds
        ]) {
            if (!compMap.containsKey(
                    c.Potential_Site__c))
                compMap.put(c.Potential_Site__c,
                    new List<Competitor_Proximity__c>());
            compMap.get(c.Potential_Site__c).add(c);
        }

        // SOQL 4 — all existing scorecards
        Map<Id, Site_Score__c> existingMap =
            new Map<Id, Site_Score__c>();
        for (Site_Score__c sc : [
            SELECT Id, Potential_Site__c
            FROM Site_Score__c
            WHERE Potential_Site__c IN :siteIds
            ORDER BY Scored_Date__c DESC
        ]) {
            if (!existingMap.containsKey(
                    sc.Potential_Site__c))
                existingMap.put(
                    sc.Potential_Site__c, sc);
        }

        // Process — NO SOQL inside this loop
        List<Site_Score__c> toInsert =
            new List<Site_Score__c>();
        List<Site_Score__c> toUpdate =
            new List<Site_Score__c>();

        for (SiteInput inp : inputs) {
            try {
                Potential_Site__c site =
                    siteMap.get(inp.siteId);
                if (site == null) continue;

                Demographic_Profile__c dem =
                    demMap.get(site.PIN_Code__c);

                if (dem == null) {
                    System.debug(LoggingLevel.WARN,
                        'No demographic for PIN: '
                        + site.PIN_Code__c);
                }

                Decimal demScore =
                    (dem != null
                    && dem.Composite_Demand1__c != null)
                    ? Math.max(0, Math.min(100,
                        dem.Composite_Demand1__c))
                    : DEFAULT_SCORE;

                List<Competitor_Proximity__c> comps =
                    compMap.get(site.Id);
                Decimal threat = 0;
                if (comps != null
                        && !comps.isEmpty()) {
                    Decimal total = 0;
                    for (Competitor_Proximity__c c
                            : comps)
                        if (c.Threat_Score__c != null)
                            total += c.Threat_Score__c;
                    threat = total / comps.size();
                }

                Decimal finalScore = Math.max(0,
                    Math.min(100,
                        ((demScore * DEMAND_WEIGHT)
                        - (threat * COMP_WEIGHT))
                        .setScale(2)));

                String lvl = threat >= 60 ? 'High'
                    : threat >= 30 ? 'Medium' : 'Low';

                System.debug(
                    'Site: ' + site.PIN_Code__c
                    + ' Dem: ' + demScore
                    + ' Threat: ' + threat
                    + ' Score: ' + finalScore
                    + ' Level: ' + lvl);

                Site_Score__c sc =
                    new Site_Score__c(
                        Potential_Site__c     = site.Id,
                        Demand_Score__c       = finalScore,
                        Competition_Level__c  = lvl,
                        Competitor_Density__c = threat,
                        Demographic_Index__c  = demScore,
                        Scored_Date__c        =
                            DateTime.now(),
                        Agent_Version__c      = 'v3.0'
                    );

                if (existingMap.containsKey(site.Id)) {
                    sc.Id =
                        existingMap.get(site.Id).Id;
                    toUpdate.add(sc);
                } else {
                    toInsert.add(sc);
                }

                ScorecardResult r =
                    new ScorecardResult();
                r.demandScore      = finalScore;
                r.competitionLevel = lvl;
                results.add(r);

            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR,
                    'Error: ' + e.getMessage());
            }
        }

        // Single DML outside loop
        if (!toInsert.isEmpty()) insert toInsert;
        if (!toUpdate.isEmpty()) update toUpdate;

        // Map scorecard IDs back to results
        Integer idx = 0;
        for (SiteInput inp : inputs) {
            if (idx >= results.size()) break;
            Potential_Site__c site =
                siteMap.get(inp.siteId);
            if (site == null) { idx++; continue; }
            if (existingMap.containsKey(site.Id)) {
                results[idx].scorecardId =
                    existingMap.get(site.Id).Id;
            } else if (!toInsert.isEmpty()) {
                for (Site_Score__c sc : toInsert) {
                    if (sc.Potential_Site__c
                            == site.Id) {
                        results[idx].scorecardId =
                            sc.Id;
                        break;
                    }
                }
            }
            idx++;
        }

        return results;
    }

    public class SiteInput {
        @InvocableVariable public Id siteId;
    }

    public class ScorecardResult {
        @InvocableVariable public Decimal demandScore;
        @InvocableVariable public String competitionLevel;
        @InvocableVariable public Id     scorecardId;
    }
}