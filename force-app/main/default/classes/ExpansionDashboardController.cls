public with sharing class ExpansionDashboardController {
 
    // Returns all non-rejected sites with scorecard
    // and financial projection data
    @AuraEnabled(cacheable=true)
    public static List<SiteWrapper> getSites(
            String regionFilter,
            String statusFilter,
            String competitionFilter) {
 
        String regionLike  = '%' +
            (regionFilter  != null ? regionFilter  : '') + '%';
        String statusLike  = '%' +
            (statusFilter  != null ? statusFilter  : '') + '%';
 
        List<Potential_Site__c> sites;
 
        if (String.isNotBlank(regionFilter)
                && String.isNotBlank(competitionFilter)
                && competitionFilter != 'All') {
            sites = [
                SELECT Id, Name, Full_Address__c,
                       Address__City__s, Address__StateCode__s, PIN_Code__c,
                       Site_Status__c,
                       Demand_Score__c,
                  (SELECT Demand_Score__c,
                          Competition_Level__c,
                          Blind_Spot_Flag__c,
                          Site_Quality_Tier__c,
                          Agent_Recommendation__c,
                          Scored_Date__c
                   FROM Site_Scores__r
                   ORDER BY Scored_Date__c DESC LIMIT 1),
                  (SELECT Expected_Revenue_Yr1__c,
                          Payback_Period_Yrs__c,
                          Viability_Status__c
                   FROM Financial_Projections__r
                   ORDER BY Generated_Date__c DESC LIMIT 1)
                FROM Potential_Site__c
                WHERE Site_Status__c != 'Rejected'
                AND (Address__City__s LIKE :regionLike
                     OR Address__StateCode__s LIKE :regionLike)
                ORDER BY Demand_Score__c DESC
                LIMIT 50
            ];
        } else if (String.isNotBlank(regionFilter)) {
            sites = [
                SELECT Id, Name, Full_Address__c,
                       Address__City__s, Address__StateCode__s, PIN_Code__c,
                       Site_Status__c,
                       Demand_Score__c,
                  (SELECT Demand_Score__c,
                          Competition_Level__c,
                          Blind_Spot_Flag__c,
                          Site_Quality_Tier__c,
                          Agent_Recommendation__c,
                          Scored_Date__c
                   FROM Site_Scores__r
                   ORDER BY Scored_Date__c DESC LIMIT 1),
                  (SELECT Expected_Revenue_Yr1__c,
                          Payback_Period_Yrs__c,
                          Viability_Status__c
                   FROM Financial_Projections__r
                   ORDER BY Generated_Date__c DESC LIMIT 1)
                FROM Potential_Site__c
                WHERE Site_Status__c != 'Rejected'
                AND (Address__City__s LIKE :regionLike
                     OR Address__StateCode__s LIKE :regionLike)
                ORDER BY Demand_Score__c DESC
                LIMIT 50
            ];
        } else {
            sites = [
                SELECT Id, Name, Full_Address__c,
                       Address__City__s, Address__StateCode__s, PIN_Code__c,
                       Site_Status__c,
                       Demand_Score__c,
                  (SELECT Demand_Score__c,
                          Competition_Level__c,
                          Blind_Spot_Flag__c,
                          Site_Quality_Tier__c,
                          Agent_Recommendation__c,
                          Scored_Date__c
                   FROM Site_Scores__r
                   ORDER BY Scored_Date__c DESC LIMIT 1),
                  (SELECT Expected_Revenue_Yr1__c,
                          Payback_Period_Yrs__c,
                          Viability_Status__c
                   FROM Financial_Projections__r
                   ORDER BY Generated_Date__c DESC LIMIT 1)
                FROM Potential_Site__c
                WHERE Site_Status__c != 'Rejected'
                ORDER BY Demand_Score__c DESC
                LIMIT 50
            ];
        }
 
        List<SiteWrapper> result = new List<SiteWrapper>();
        for (Potential_Site__c site : sites) {
            SiteWrapper w = new SiteWrapper();
            w.id          = site.Id;
            w.name        = site.Name;
            w.address     = site.Full_Address__c;
            w.city        = site.Address__City__s;
            w.state       = site.Address__StateCode__s;
            w.pinCode     = site.PIN_Code__c;
            w.siteStatus  = site.Site_Status__c;
            w.latestScore = site.Demand_Score__c
                            != null
                            ? site.Demand_Score__c
                            : 0;
            List<Site_Score__c> scs =
                site.Site_Scores__r;
            if (scs != null && !scs.isEmpty()) {
                w.demandScore    = scs[0].Demand_Score__c
                    != null ? scs[0].Demand_Score__c : 0;
                w.competition    = scs[0].Competition_Level__c;
                w.blindSpot      = scs[0].Blind_Spot_Flag__c;
                w.qualityTier    = scs[0].Site_Quality_Tier__c;
                w.recommendation =
                    scs[0].Agent_Recommendation__c;
            }
            List<Financial_Projection__c> fps =
                site.Financial_Projections__r;
            if (fps != null && !fps.isEmpty()) {
                w.revenueY1   =
                    fps[0].Expected_Revenue_Yr1__c != null
                    ? fps[0].Expected_Revenue_Yr1__c : 0;
                w.payback     =
                    fps[0].Payback_Period_Yrs__c != null
                    ? fps[0].Payback_Period_Yrs__c : 0;
                w.viability   = fps[0].Viability_Status__c;
            }
            // Apply competition filter in Apex
            if (String.isBlank(competitionFilter)
                    || competitionFilter == 'All'
                    || w.competition == competitionFilter) {
                result.add(w);
            }
        }
        return result;
    }
 
    // Approve a site — creates Expansion Decision record
    @AuraEnabled
    public static String approveSite(
            Id siteId, String remarks) {
        try {
            Site_Score__c sc = [
                SELECT Id FROM Site_Score__c
                WHERE Potential_Site__c = :siteId
                ORDER BY Scored_Date__c DESC LIMIT 1];
                Expansion_Decision__c dec =
                new Expansion_Decision__c(
                    Site_Score_Card__c   = sc.Id,
                    Decision_Status__c  = 'Approved',
                    Approved_By__c      = UserInfo.getUserId(),
                    Decision_Date__c    = DateTime.now(),
                    Remarks__c          = remarks
                );
            insert dec;
            update new Potential_Site__c(
                Id = siteId,
                Site_Status__c = 'Approved'
            );
            return 'SUCCESS';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
 
    // Reject a site
    @AuraEnabled
    public static String rejectSite(
            Id siteId,
            String rejectionReason,
            String remarks) {
        try {
            Site_Score__c sc = [
                SELECT Id FROM Site_Score__c
                WHERE Potential_Site__c = :siteId
                ORDER BY Scored_Date__c DESC LIMIT 1];
            Expansion_Decision__c dec =
                new Expansion_Decision__c(
                    Site_Score_Card__c    = sc.Id,
                    Decision_Status__c   = 'Rejected',
                    Approved_By__c       = UserInfo.getUserId(),
                    Decision_Date__c     = DateTime.now(),
                    Rejection_Reason__c  = rejectionReason,
                    Remarks__c           = remarks
                );
            insert dec;
            update new Potential_Site__c(
                Id = siteId,
                Site_Status__c = 'Rejected'
            );
            return 'SUCCESS';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
 
    public class SiteWrapper {
        @AuraEnabled public Id      id;
        @AuraEnabled public String  name;
        @AuraEnabled public String  address;
        @AuraEnabled public String  city;
        @AuraEnabled public String  state;
        @AuraEnabled public String  pinCode;
        @AuraEnabled public String  siteStatus;
        @AuraEnabled public Decimal latestScore;
        @AuraEnabled public Decimal demandScore;
        @AuraEnabled public String  competition;
        @AuraEnabled public Boolean blindSpot;
        @AuraEnabled public String  qualityTier;
        @AuraEnabled public String  recommendation;
        @AuraEnabled public Decimal revenueY1;
        @AuraEnabled public Decimal payback;
        @AuraEnabled public String  viability;
    }
}