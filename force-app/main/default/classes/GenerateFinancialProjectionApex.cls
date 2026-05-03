public class GenerateFinancialProjectionApex {

    @InvocableMethod(
        label='Generate Financial Projection')
    public static List<ProjectionResult> generate(
            List<Id> siteIds) {

        List<ProjectionResult> results =
            new List<ProjectionResult>();

        // SOQL 1 — get config outside loop
        Expansion_Config__mdt cfg =
            Expansion_Config__mdt.getInstance(
                'India_Standard_Config');

        Decimal capex =
            cfg != null
            && cfg.Default_Capex_INR__c != null
            ? cfg.Default_Capex_INR__c : 5000000;

        Decimal opex =
            cfg != null
            && cfg.Default_Opex_Y1_INR__c != null
            ? cfg.Default_Opex_Y1_INR__c : 1200000;

        Decimal gy2 =
            cfg != null
            && cfg.Revenue_Growth_Rate_Y2__c != null
            ? cfg.Revenue_Growth_Rate_Y2__c / 100
            : 0.15;

        Decimal gy3 =
            cfg != null
            && cfg.Revenue_Growth_Rate_Y3__c != null
            ? cfg.Revenue_Growth_Rate_Y3__c / 100
            : 0.20;

        // SOQL 2 — get all existing projections
        // outside loop
        Map<Id, Financial_Projection__c> existingMap =
            new Map<Id, Financial_Projection__c>();
        for (Financial_Projection__c fp : [
            SELECT Id,
                   Potential_Site__c,
                   Expected_Revenue_Yr1__c,
                   Expected_Revenue_Yr2__c,
                   Expected_Revenue_Yr3__c,
                   Capex_Estimate__c,
                   Opex_Estimate_Yr1__c,
                   Payback_Period_Yrs__c
            FROM Financial_Projection__c
            WHERE Potential_Site__c IN :siteIds
            ORDER BY Generated_Date__c DESC
        ]) {
            if (!existingMap.containsKey(
                    fp.Potential_Site__c)) {
                existingMap.put(
                    fp.Potential_Site__c, fp);
            }
        }

        // SOQL 3 — get all scores outside loop
        Map<Id, Site_Score__c> scoreMap =
            new Map<Id, Site_Score__c>();
        for (Site_Score__c sc : [
            SELECT Id,
                   Potential_Site__c,
                   Demand_Score__c
            FROM Site_Score__c
            WHERE Potential_Site__c IN :siteIds
            ORDER BY Scored_Date__c DESC
        ]) {
            if (!scoreMap.containsKey(
                    sc.Potential_Site__c)) {
                scoreMap.put(
                    sc.Potential_Site__c, sc);
            }
        }

        // Process each site — NO SOQL inside loop
        List<Financial_Projection__c> toInsert =
            new List<Financial_Projection__c>();

        for (Id siteId : siteIds) {

            // Return existing if found
            if (existingMap.containsKey(siteId)) {
                Financial_Projection__c ex =
                    existingMap.get(siteId);
                ProjectionResult r =
                    new ProjectionResult();
                r.revenueY1    =
                    ex.Expected_Revenue_Yr1__c;
                r.revenueY2    =
                    ex.Expected_Revenue_Yr2__c;
                r.revenueY3    =
                    ex.Expected_Revenue_Yr3__c;
                r.capex        =
                    ex.Capex_Estimate__c;
                r.paybackYears =
                    ex.Payback_Period_Yrs__c;
                r.projectionId = ex.Id;
                results.add(r);
                continue;
            }

            // Get demand score from map
            Site_Score__c sc =
                scoreMap.get(siteId);
            Decimal df = (sc != null
                && sc.Demand_Score__c != null)
                ? sc.Demand_Score__c / 100
                : 50.0 / 100;

            // Calculate
            Decimal y1 = capex * df * 0.6;
            Decimal y2 = y1 * (1 + gy2);
            Decimal y3 = y2 * (1 + gy3);
            Decimal profit = y1 - opex;
            Decimal pb = profit > 0
                ? (capex / profit).setScale(2)
                : null;

            Financial_Projection__c fp =
                new Financial_Projection__c(
                    Potential_Site__c       = siteId,
                    Expected_Revenue_Yr1__c = y1,
                    Expected_Revenue_Yr2__c = y2,
                    Expected_Revenue_Yr3__c = y3,
                    Capex_Estimate__c       = capex,
                    Opex_Estimate_Yr1__c    = opex,
                    Projection_Model__c     =
                        'v1.0-DemandWeighted',
                    Generated_Date__c       =
                        DateTime.now()
                );
            toInsert.add(fp);

            ProjectionResult r =
                new ProjectionResult();
            r.revenueY1    = y1;
            r.revenueY2    = y2;
            r.revenueY3    = y3;
            r.capex        = capex;
            r.paybackYears = pb;
            results.add(r);
        }

        // Single DML outside loop
        if (!toInsert.isEmpty()) {
            insert toInsert;
            // Map IDs back to results
            for (Integer i = 0;
                    i < toInsert.size(); i++) {
                results[results.size()
                    - toInsert.size() + i]
                    .projectionId =
                    toInsert[i].Id;
            }
        }

        return results;
    }

    public class ProjectionResult {
        @InvocableVariable
        public Decimal revenueY1;
        @InvocableVariable
        public Decimal revenueY2;
        @InvocableVariable
        public Decimal revenueY3;
        @InvocableVariable
        public Decimal capex;
        @InvocableVariable
        public Decimal paybackYears;
        @InvocableVariable
        public Id      projectionId;
    }
}