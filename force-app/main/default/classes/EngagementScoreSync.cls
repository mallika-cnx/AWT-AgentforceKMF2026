public class EngagementScoreSync implements Schedulable {

    public void execute(SchedulableContext sc) {
        syncScores();
    }

    @future(callout=true)
    public static void syncScores() {

        // Query Engagement Score DLM via Data Cloud REST API
        String endpoint = URL.getOrgDomainUrl().toExternalForm()
            + '/services/data/v60.0/ssot/querydata';

        String query = 'SELECT Region__c, Avg_Basket_Size__c, '
            + 'Active_Customer_Density__c, Score_Date__c '
            + 'FROM Engagement_Score__dlm';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(new Map<String, String>{
            'sql' => query
        }));

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> body =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> rows =
                (List<Object>) body.get('data');

            List<Demographic_Profile__c> upsertList =
                new List<Demographic_Profile__c>();

            for (Object row : rows) {
                Map<String, Object> r = (Map<String, Object>) row;
                Demographic_Profile__c profile =
                    new Demographic_Profile__c(
                        PIN_Code__c          = (String)  r.get('Region__c'),
                        Footfall_Estimate__c = (Decimal) r.get('Active_Customer_Density__c'),
                        As_Of_Date__c        = Date.today(),
                        Data_Source__c       = 'Data Cloud'
                    );
                upsertList.add(profile);
            }

            if (!upsertList.isEmpty()) {
                upsert upsertList PIN_Code__c;
            }
        }
    }
}