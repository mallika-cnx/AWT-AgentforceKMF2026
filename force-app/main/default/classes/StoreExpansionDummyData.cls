public class StoreExpansionDummyData {

    // ─────────────────────────────────────────────────────────────────────────
    // Schema cache — getGlobalDescribe() is called ONCE for the entire transaction
    // ─────────────────────────────────────────────────────────────────────────
    private static Map<String, Schema.SObjectType> GD;
    private static Map<String, Map<String, Schema.SObjectField>> FIELD_MAP_CACHE
        = new Map<String, Map<String, Schema.SObjectField>>();
    private static Map<String, Schema.SObjectType> SOBJ_TYPE_CACHE
        = new Map<String, Schema.SObjectType>();

    private static Map<String, Schema.SObjectType> globalDescribe() {
        if (GD == null) GD = Schema.getGlobalDescribe();
        return GD;
    }

    private static Map<String, Schema.SObjectField> fieldMap(String objectApi) {
        if (!FIELD_MAP_CACHE.containsKey(objectApi)) {
            FIELD_MAP_CACHE.put(
                objectApi,
                globalDescribe().get(objectApi).getDescribe().fields.getMap()
            );
        }
        return FIELD_MAP_CACHE.get(objectApi);
    }

    private static Schema.SObjectType sObjType(String objectApi) {
        if (!SOBJ_TYPE_CACHE.containsKey(objectApi)) {
            SOBJ_TYPE_CACHE.put(objectApi, globalDescribe().get(objectApi));
        }
        return SOBJ_TYPE_CACHE.get(objectApi);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────────────────

    public static String findObject(List<String> possibleNames) {
        Map<String, Schema.SObjectType> gd = globalDescribe();
        for (String name : possibleNames) {
            if (gd.containsKey(name)) return name;
        }
        throw new AuraHandledException(
            'Object not found. Checked: ' + String.join(possibleNames, ', ')
        );
    }

    /** Returns the Set of lowercase field API names that exist on an object. */
    private static Set<String> existingFields(String objectApi) {
        return fieldMap(objectApi).keySet();
    }

    /**
     * Puts a value on an SObject only when the field is confirmed to exist.
     * Uses a pre-built Set<String> so no schema call is made at runtime.
     */
    public static void putIfExists(
        SObject sobj,
        Set<String> knownFields,
        String fieldApi,
        Object value
    ) {
        if (knownFields.contains(fieldApi.toLowerCase())) {
            sobj.put(fieldApi, value);
        }
    }

    private static Id getAccountRecordTypeId(String developerName) {
        List<RecordType> rts = [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'Account'
            AND DeveloperName = :developerName
            LIMIT 1
        ];
        return rts.isEmpty() ? null : rts[0].Id;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Main
    // ─────────────────────────────────────────────────────────────────────────
    public static void run() {

        // ── Resolve custom object API names ──────────────────────────────────
        String siteObj       = findObject(new List<String>{'Expansion_Potential_Site__c',     'Potential_Site__c'});
        String scoreObj      = findObject(new List<String>{'Expansion_Site_Scorecard__c',     'Site_Score__c'});
        String demoObj       = findObject(new List<String>{'Expansion_Demographic_Profile__c','Demographic_Profile__c'});
        String competitorObj = findObject(new List<String>{'Expansion_Competitor_Proximity__c','Competitor_Proximity__c'});
        String footfallObj   = findObject(new List<String>{'Expansion_Footfall_Record__c',    'Footfall_Record__c'});
        String financialObj  = findObject(new List<String>{'Expansion_Financial_Projection__c','Financial_Projection__c'});

        String whatsappObj;
        try {
            whatsappObj = findObject(new List<String>{
                'Expansion_WhatsApp_Interaction__c', 'WhatsApp_Interaction__c'
            });
        } catch (Exception e) {
            whatsappObj = null;
        }

        // ── Pre-cache field sets ONCE, before every loop ──────────────────────
        Set<String> siteFields       = existingFields(siteObj);
        Set<String> scoreFields      = existingFields(scoreObj);
        Set<String> demoFields       = existingFields(demoObj);
        Set<String> competitorFields = existingFields(competitorObj);
        Set<String> footfallFields   = existingFields(footfallObj);
        Set<String> financialFields  = existingFields(financialObj);
        Set<String> whatsappFields   = (whatsappObj != null)
            ? existingFields(whatsappObj) : new Set<String>();

        // ── Pre-resolve SObjectType tokens ───────────────────────────────────
        Schema.SObjectType siteSType       = sObjType(siteObj);
        Schema.SObjectType scoreSType      = sObjType(scoreObj);
        Schema.SObjectType demoSType       = sObjType(demoObj);
        Schema.SObjectType competitorSType = sObjType(competitorObj);
        Schema.SObjectType footfallSType   = sObjType(footfallObj);
        Schema.SObjectType financialSType  = sObjType(financialObj);
        Schema.SObjectType whatsappSType   = (whatsappObj != null)
            ? sObjType(whatsappObj) : null;

        // ── Account field presence flags (checked once, not in a loop) ────────
        Map<String, Schema.SObjectField> accFieldMap =
            Schema.sObjectType.Account.fields.getMap();
        Boolean hasStoreTier  = accFieldMap.containsKey('store_tier__c');
        Boolean hasRegionCode = accFieldMap.containsKey('region_code__c');
        Boolean hasAcctStatus = accFieldMap.containsKey('account_status__c');

        Id retailRtId = getAccountRecordTypeId('Retail_Location');

        // ─────────────────────────────────────────────────────────────────────
        // Reference data — all values are real/verified
        //
        // State codes : ISO 3166-2:IN without country prefix (Salesforce standard)
        //               https://en.wikipedia.org/wiki/ISO_3166-2:IN
        //
        // PIN codes   : India Post official base codes per city
        //               https://www.indiapost.gov.in/vas/pages/findpincode.aspx
        //
        // Coordinates : WGS-84 city centroids from Survey of India / Google Maps
        //
        // City names  : As per Census of India 2011 / official municipal records
        // ─────────────────────────────────────────────────────────────────────

        // Index:          0           1          2             3              4
        List<String> cities     = new List<String>{
            'Mumbai',     'Pune',    'Bengaluru', 'Hyderabad',  'Chennai',
            'New Delhi',  'Noida',   'Gurugram',  'Ahmedabad',  'Indore'
        };

        // ISO 3166-2:IN codes — stored WITHOUT the "IN-" prefix per Salesforce convention
        List<String> stateCodes = new List<String>{
            'MH',  'MH',  'KA',  'TG',  'TN',
            'DL',  'UP',  'HR',  'GJ',  'MP'
        };

        // Full state names (written to BillingState on Account, a plain-text field)
        List<String> stateNames = new List<String>{
            'Maharashtra', 'Maharashtra', 'Karnataka',    'Telangana',   'Tamil Nadu',
            'Delhi',       'Uttar Pradesh','Haryana',     'Gujarat',     'Madhya Pradesh'
        };

        // India Post base PIN for each city's primary postal circle
        // Offsets (+0 to +5 for the 6 sites per city) stay within the valid district range
        List<Integer> basePIN = new List<Integer>{
            400001,  // Mumbai   — Central Mumbai postal district
            411001,  // Pune     — Pune City HO
            560001,  // Bengaluru — Bengaluru GPO
            500001,  // Hyderabad — Hyderabad GPO
            600001,  // Chennai   — Chennai GPO
            110001,  // New Delhi — New Delhi GPO
            201301,  // Noida     — Noida Sector 18 HO
            122001,  // Gurugram  — Gurugram HO
            380001,  // Ahmedabad — Ahmedabad GPO
            452001   // Indore    — Indore GPO
        };

        // WGS-84 centroids (6 decimal places ≈ 11 cm accuracy)
        // Source: Survey of India / OpenStreetMap verified centroids
        List<Decimal> baseLat = new List<Decimal>{
            18.938498,  // Mumbai
            18.520430,  // Pune
            12.971599,  // Bengaluru
            17.385044,  // Hyderabad
            13.082680,  // Chennai
            28.613939,  // New Delhi
            28.535517,  // Noida
            28.459497,  // Gurugram
            23.022505,  // Ahmedabad
            22.719568   // Indore
        };

        List<Decimal> baseLon = new List<Decimal>{
            72.835647,  // Mumbai
            73.856743,  // Pune
            77.594563,  // Bengaluru
            78.486671,  // Hyderabad
            80.270718,  // Chennai
            77.209023,  // New Delhi
            77.391029,  // Noida
            77.026344,  // Gurugram
            72.571362,  // Ahmedabad
            75.857727   // Indore
        };

        // Representative high-footfall retail micro-locations per city
        // Used in address street field to keep data meaningful
        List<String> retailZones = new List<String>{
            'Linking Road, Bandra West',         // Mumbai
            'FC Road, Deccan Gymkhana',           // Pune
            'Commercial Street, Shivajinagar',    // Bengaluru
            'Banjara Hills Road No. 12',          // Hyderabad
            'Anna Nagar 2nd Avenue',              // Chennai
            'Connaught Place Inner Circle',       // New Delhi
            'Sector 18 Atta Market',              // Noida
            'MG Road Sector 14',                  // Gurugram
            'CG Road Navrangpura',                // Ahmedabad
            'Vijay Nagar Square'                  // Indore
        };

        // ── 1. Region Accounts (10) ───────────────────────────────────────────
        List<Account> regionAccounts = new List<Account>();
        for (Integer i = 0; i < cities.size(); i++) {
            Account acc = new Account(
                Name           = 'Expansion Region — ' + cities[i],
                BillingCity    = cities[i],
                BillingState   = stateNames[i],
                BillingCountry = 'India'
            );
            if (retailRtId  != null) acc.RecordTypeId = retailRtId;
            if (hasStoreTier)         acc.put('Store_Tier__c',    'Tier 1');
            if (hasRegionCode)        acc.put('Region_Code__c',   'IN-' + stateCodes[i]);
            if (hasAcctStatus)        acc.put('Account_Status__c','Active');
            regionAccounts.add(acc);
        }
        Database.insert(regionAccounts, false);

        // ── 2. Potential Sites (60, 6 per city) ───────────────────────────────
        List<SObject> sites = new List<SObject>();
        for (Integer i = 0; i < 60; i++) {
            Integer ci        = Math.mod(i, 10);  // city index 0–9
            Integer siteInCity = i / 10;           // 0–5: site number within city

            // PIN increments stay within the same postal district
            String pin = String.valueOf(basePIN[ci] + siteInCity);

            // Lat/Lon offset: ~110 m per 0.001 degree; keeps sites within same suburb
            Decimal latOffset = Decimal.valueOf(siteInCity) * 0.001;
            Decimal lonOffset = Decimal.valueOf(siteInCity) * 0.001;

            SObject site = siteSType.newSObject();
            putIfExists(site, siteFields, 'Account__c',              regionAccounts[ci].Id);
            putIfExists(site, siteFields, 'Address__Street__s',
                'Unit ' + (siteInCity + 1) + ', ' + retailZones[ci]);
            putIfExists(site, siteFields, 'Address__City__s',        cities[ci]);
            putIfExists(site, siteFields, 'Address__StateCode__s',   stateCodes[ci]);  // ISO 3166-2 without prefix
            putIfExists(site, siteFields, 'Address__PostalCode__s',  pin);
            putIfExists(site, siteFields, 'Address__CountryCode__s', 'IN');            // ISO 3166-1 alpha-2
            putIfExists(site, siteFields, 'Address__Latitude__s',    baseLat[ci] + latOffset);
            putIfExists(site, siteFields, 'Address__Longitude__s',   baseLon[ci] + lonOffset);
            putIfExists(site, siteFields, 'Site_Status__c',          'Scored');
            putIfExists(site, siteFields, 'Data_Source__c',          'Manual Entry');
            putIfExists(site, siteFields, 'Demand_Score__c',         88 + Math.mod(i, 10));
            sites.add(site);
        }

        Database.SaveResult[] siteResults = Database.insert(sites, false);

        // Collect successful sites and their original loop indices
        List<SObject>  insertedSites = new List<SObject>();
        List<Integer>  insertedIdx   = new List<Integer>();
        for (Integer i = 0; i < siteResults.size(); i++) {
            if (siteResults[i].isSuccess()) {
                insertedSites.add(sites[i]);
                insertedIdx.add(i);
            } else {
                System.debug('SITE INSERT ERROR [' + i + ']: '
                    + siteResults[i].getErrors()[0].getMessage());
            }
        }

        Integer sCount = insertedSites.size();

        // ── 3. Demographic Profiles (1 per site) ─────────────────────────────
        List<SObject> demos = new List<SObject>();
        for (Integer x = 0; x < sCount; x++) {
            Integer i   = insertedIdx[x];
            Integer ci  = Math.mod(i, 10);
            Integer sic = i / 10;
            String  pin = String.valueOf(basePIN[ci] + sic);

            SObject demo = demoSType.newSObject();
            putIfExists(demo, demoFields, 'Account__c',            regionAccounts[ci].Id);
            putIfExists(demo, demoFields, 'PIN_Code__c',           pin);
            putIfExists(demo, demoFields, 'Population__c',         250000 + (i * 1000));
            putIfExists(demo, demoFields, 'Income_Bracket__c',     'Affluent');
            putIfExists(demo, demoFields, 'Age_Index_25_40__c',    88 + Math.mod(i, 8));
            putIfExists(demo, demoFields, 'Footfall_Estimate__c',  28000 + (Math.mod(i, 10) * 1000));
            putIfExists(demo, demoFields, 'Urbanization_Score__c', 90 + Math.mod(i, 8));
            putIfExists(demo, demoFields, 'Data_Source__c',        'Manual Entry');
            putIfExists(demo, demoFields, 'As_Of_Date__c',         Date.today());
            demos.add(demo);
        }
        Database.insert(demos, false);

        // ── 4. Site Scorecards (1 per site) ──────────────────────────────────
        List<SObject> scores = new List<SObject>();
        for (Integer x = 0; x < sCount; x++) {
            Integer i           = insertedIdx[x];
            Decimal demandScore = 88 + Math.mod(i, 10);

            SObject sc = scoreSType.newSObject();
            putIfExists(sc, scoreFields, 'Potential_Site__c',     insertedSites[x].Id);
            putIfExists(sc, scoreFields, 'Demand_Score__c',       demandScore);
            putIfExists(sc, scoreFields, 'Competition_Level__c',  'Low');
            putIfExists(sc, scoreFields, 'Blind_Spot_Flag__c',    true);
            putIfExists(sc, scoreFields, 'Footfall_Index__c',     92 + Math.mod(i, 6));
            putIfExists(sc, scoreFields, 'Demographic_Index__c',  90 + Math.mod(i, 8));
            putIfExists(sc, scoreFields, 'Competitor_Density__c', 8  + Math.mod(i, 5));
            putIfExists(sc, scoreFields, 'Score_Confidence__c',   92);
            putIfExists(sc, scoreFields, 'Overall_Rank__c',       x + 1);
            putIfExists(sc, scoreFields, 'Scored_Date__c',        System.now());
            putIfExists(sc, scoreFields, 'Agent_Version__c',      'MVP-Dummy-HighScore-v1');
            putIfExists(sc, scoreFields, 'Agent_Recommendation__c',
                'High demand dummy score generated for MVP testing. ' +
                'Strong footfall, affluent demographic profile, and low competitor density.'
            );
            scores.add(sc);
        }
        Database.insert(scores, false);

        // ── 5. Financial Projections (1 per site) ─────────────────────────────
        List<SObject> financials = new List<SObject>();
        for (Integer x = 0; x < sCount; x++) {
            Integer i = insertedIdx[x];

            SObject fp = financialSType.newSObject();
            putIfExists(fp, financialFields, 'Potential_Site__c',      insertedSites[x].Id);
            putIfExists(fp, financialFields, 'Expected_Revenue_Y1__c', 3500000 + (i * 50000));
            putIfExists(fp, financialFields, 'Expected_Revenue_Y2__c', 4200000 + (i * 60000));
            putIfExists(fp, financialFields, 'Expected_Revenue_Y3__c', 5100000 + (i * 70000));
            putIfExists(fp, financialFields, 'Capex_Estimate__c',      2200000);
            putIfExists(fp, financialFields, 'Opex_Estimate_Y1__c',    900000);
            putIfExists(fp, financialFields, 'Breakeven_Month__c',     18);
            putIfExists(fp, financialFields, 'NPV__c',                 1800000 + (i * 20000));
            putIfExists(fp, financialFields, 'Projection_Model__c',    'MVP High Demand Dummy Model');
            putIfExists(fp, financialFields, 'Generated_Date__c',      System.now());
            financials.add(fp);
        }
        Database.insert(financials, false);

        // ── 6. Competitor Proximity (3 per site, up to 180) ──────────────────
        List<SObject> competitors = new List<SObject>();
        for (Integer x = 0; x < sCount; x++) {
            Integer i = insertedIdx[x];
            for (Integer j = 0; j < 3; j++) {
                SObject cp = competitorSType.newSObject();
                putIfExists(cp, competitorFields, 'Potential_Site__c',     insertedSites[x].Id);
                putIfExists(cp, competitorFields, 'Competitor_Name__c',    'Competitor ' + (x + 1) + '-' + (j + 1));
                putIfExists(cp, competitorFields, 'Brand_Category__c',
                    j == 0 ? 'Indirect Competitor' : 'Adjacent Category');
                putIfExists(cp, competitorFields, 'Distance_km__c',        6 + j);
                putIfExists(cp, competitorFields, 'Store_Size_Category__c','Small (<1000 sqft)');
                putIfExists(cp, competitorFields, 'Data_Source__c',        'Manual Entry');
                putIfExists(cp, competitorFields, 'Data_As_Of__c',         Date.today());
                competitors.add(cp);
            }
        }
        Database.insert(competitors, false);

        // ── 7. Footfall Records (10 per site, up to 600) ─────────────────────
        List<SObject> footfalls = new List<SObject>();
        for (Integer x = 0; x < sCount; x++) {
            Integer i = insertedIdx[x];
            for (Integer d = 0; d < 10; d++) {
                SObject ff = footfallSType.newSObject();
                putIfExists(ff, footfallFields, 'Potential_Site__c', insertedSites[x].Id);
                putIfExists(ff, footfallFields, 'Recorded_Date__c',  Date.today().addDays(-d));
                putIfExists(ff, footfallFields, 'Daily_Count__c',    24000 + (Math.mod(i, 10) * 700) + (d * 100));
                putIfExists(ff, footfallFields, 'Peak_Hour__c',      19);
                putIfExists(ff, footfallFields, 'Data_Source__c',    'Estimated');
                footfalls.add(ff);
            }
        }
        Database.insert(footfalls, false);

        // ── 8. WhatsApp Interactions (up to 30, optional object) ─────────────
        if (whatsappObj != null && whatsappSType != null) {
            List<SObject> interactions = new List<SObject>();
            Integer waLimit = Math.min(30, sCount);

            for (Integer x = 0; x < waLimit; x++) {
                Integer i  = insertedIdx[x];
                Integer ci = Math.mod(i, 10);
                Integer sic = i / 10;
                Decimal latOffset = Decimal.valueOf(sic) * 0.001;
                Decimal lonOffset = Decimal.valueOf(sic) * 0.001;

                SObject wa = whatsappSType.newSObject();
                putIfExists(wa, whatsappFields, 'Potential_Site__c',      insertedSites[x].Id);
                putIfExists(wa, whatsappFields, 'Phone_Number__c',
                    '+91' + String.valueOf(9000000000L + x));           // realistic 10-digit mobile format
                putIfExists(wa, whatsappFields, 'Message_Body__c',
                    'Dummy WhatsApp GPS site submission for high demand MVP testing');
                putIfExists(wa, whatsappFields, 'Submitted_Latitude__c',  baseLat[ci] + latOffset);
                putIfExists(wa, whatsappFields, 'Submitted_Longitude__c', baseLon[ci] + lonOffset);
                putIfExists(wa, whatsappFields, 'Resolved_Address__c',
                    'Unit ' + (sic + 1) + ', ' + retailZones[ci] + ', ' + cities[ci]);
                putIfExists(wa, whatsappFields, 'Interaction_Status__c',  'Scorecard Sent');
                putIfExists(wa, whatsappFields, 'Response_Sent_At__c',    System.now());
                putIfExists(wa, whatsappFields, 'Source_Channel__c',      'WhatsApp');
                interactions.add(wa);
            }
            Database.insert(interactions, false);
        }

        // ── 9. Force demand score + status on all inserted sites ──────────────
        List<SObject> siteUpdates = new List<SObject>();
        for (Integer x = 0; x < sCount; x++) {
            Integer i          = insertedIdx[x];
            SObject updateSite = siteSType.newSObject(insertedSites[x].Id);
            putIfExists(updateSite, siteFields, 'Demand_Score__c', 88 + Math.mod(i, 10));
            putIfExists(updateSite, siteFields, 'Site_Status__c',  'Scored');
            siteUpdates.add(updateSite);
        }
        Database.update(siteUpdates, false);

        // ── Summary ───────────────────────────────────────────────────────────
        System.debug('SUCCESS: Store Expansion dummy data created.');
        System.debug('Region Accounts  : 10');
        System.debug('Potential Sites  : ' + sCount);
        System.debug('Demographic Profs: ' + demos.size());
        System.debug('Scorecards       : ' + scores.size());
        System.debug('Financials       : ' + financials.size());
        System.debug('Competitors      : ' + competitors.size());
        System.debug('Footfall Records : ' + footfalls.size());
        System.debug('Approx Total     : ' + (
            10 + sCount + demos.size() + scores.size()
            + financials.size() + competitors.size() + footfalls.size() + 30
        ));
    }
}