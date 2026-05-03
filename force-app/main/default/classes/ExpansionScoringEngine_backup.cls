public with sharing class ExpansionScoringEngine_backup {
     @InvocableMethod(label='Score Expansion Site bkp' 
                     description='Scores a potential site using footfall, demographic, and competitor data') 
    public static List<ScorecardResult> scoreSite(List<SiteInput> inputs) { 
        List<ScorecardResult> results = new List<ScorecardResult>(); 
        for (SiteInput inp : inputs) {    
            Potential_Site__c site = [ SELECT Id,  /*PIN_Code__c, Latitude__c, Longitude__c*/ Address__c,Address__PostalCode__s  FROM Potential_Site__c WHERE Id = :inp.siteId]; 
            
            Demographic_Profile__c dem = [ 
                SELECT Composite_Demand__c, Footfall_Estimate__c FROM Demographic_Profile__c WHERE PIN_Code__c = :site.Address__PostalCode__s  LIMIT 1]; 
            
            List<Competitor_Proximity__c> comps = [ SELECT Threat_Score__c FROM Competitor_Proximity__c WHERE Potential_Site__c = :site.Id]; 
            Decimal demandScore = 50;
            
            if (dem.Composite_Demand__c != null) {
                Decimal value = Decimal.valueOf(dem.Composite_Demand__c);
                demandScore = Math.max(0, Math.min(100, value));
            }
            Decimal threatTotal = 0; 
            
            for (Competitor_Proximity__c c : comps) 
                threatTotal += c.Threat_Score__c; 
            Decimal compScore = comps.isEmpty() ? 0 : threatTotal / comps.size(); 
            Decimal finalScore = (demandScore * 0.70) - (compScore * 0.30); 
            finalScore = Math.max(0, Math.min(100, finalScore.setScale(2)));
            
            String compLevel = compScore >= 60 ? 'High' : compScore >= 30 ? 'Medium' : 'Low'; 
            
            Site_Score__c sc = new Site_Score__c( 
                Potential_Site__c = site.Id, 
                Demand_Score__c   = finalScore, 
                Competition_Level__c = compLevel, 
                Competitor_Density__c = compScore, 
                Demographic_Index__c  = demandScore, 
                Scored_Date__c   = DateTime.now(), 
                Agent_Version__c = 'v1.0'); 
            
            upsert sc; 
            
            ScorecardResult r = new ScorecardResult(); 
            r.demandScore    = finalScore; 
            r.competitionLevel = compLevel; 
            r.scorecardId    = sc.Id; 
            results.add(r);    
        } 
        return results;  
    } 
    
    public class SiteInput  { @InvocableVariable public Id siteId; } 
    public class ScorecardResult { 
        @InvocableVariable public Decimal demandScore; 
        @InvocableVariable public String  competitionLevel; 
        @InvocableVariable public Id      scorecardId;    
    } 
}