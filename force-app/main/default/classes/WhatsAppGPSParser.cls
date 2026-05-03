/**
 * Parses GPS coordinates from WhatsApp messages and resolves them to addresses.
 * Designed for use with Agentforce agents and Flows.
 * 
 * @example
 * Input: "Check this location: 28.7041° N, 77.1025° E" or "28.7041,-77.1025"
 * Output: Latitude, Longitude, and Resolved Address
 */
public class WhatsAppGPSParser {

    // Set to false when live Google Maps
    // API key is available
    private static final Boolean USE_MOCK = true;
    private static final String  MAPS_API_KEY =
        'YOUR_GOOGLE_MAPS_API_KEY';

    @InvocableMethod(
        label='Parse GPS from WhatsApp Message')
    public static List<GPSResult> parse(
            List<String> sessionIds) {

        List<GPSResult> results =
            new List<GPSResult>();

        for (String sessionId : sessionIds) {
            GPSResult r = new GPSResult();

            // Query the latest inbound message
            // from ConversationEntry using
            // the MessagingSession ID
            String msgText = '';
            try {
                List<ConversationEntry> entries = [
                    SELECT message,
                           actortype
                    FROM ConversationEntry
                    WHERE conversationid
                        = :sessionId
                    AND actortype = 'EndUser'
                    ORDER BY entrytime DESC
                    LIMIT 1
                ];

                if (!entries.isEmpty()
                        && entries[0].message
                            != null) {
                    msgText = entries[0].message;
                }

                System.debug(
                    'Session: ' + sessionId
                    + ' Message: ' + msgText);

            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR,
                    'ConversationEntry query '
                    + 'error: ' + e.getMessage());
                r.resolvedAddress =
                    'Error reading message. '
                    + 'Please try again.';
                r.success = false;
                results.add(r);
                continue;
            }

            // Parse GPS coordinates from
            // message text using regex
            Pattern p = Pattern.compile(
                '(-?\\d{1,3}\\.\\d+)'
                + '[,\\s]+'
                + '(-?\\d{1,3}\\.\\d+)');
            Matcher m = p.matcher(msgText);

            if (m.find()) {
                r.latitude  =
                    Decimal.valueOf(m.group(1));
                r.longitude =
                    Decimal.valueOf(m.group(2));

                if (USE_MOCK) {
                    MockResult mock =
                        mockResolve(
                            r.latitude,
                            r.longitude);
                    r.resolvedAddress =
                        mock.address;
                    r.pinCode = mock.pinCode;
                    r.city    = mock.city;
                    r.state   = mock.state;
                } else {
                    MockResult live =
                        liveResolve(
                            r.latitude,
                            r.longitude);
                    r.resolvedAddress =
                        live.address;
                    r.pinCode = live.pinCode;
                    r.city    = live.city;
                    r.state   = live.state;
                }

                r.success = true;

                System.debug(
                    'GPS parsed: '
                    + r.latitude + ','
                    + r.longitude
                    + ' PIN: ' + r.pinCode
                    + ' City: ' + r.city);

            } else {
                r.resolvedAddress =
                    'Could not parse GPS. '
                    + 'Please send coordinates '
                    + 'as: latitude, longitude. '
                    + 'Example: 17.4495, 78.3773';
                r.pinCode = '';
                r.city    = '';
                r.state   = '';
                r.success = false;

                System.debug(
                    'GPS parse failed for '
                    + 'message: ' + msgText);
            }

            results.add(r);
        }

        return results;
    }

    // ── Mock resolver ──────────────────────────
    private static MockResult mockResolve(
            Decimal lat, Decimal lng) {

        MockResult r = new MockResult();

        Map<String, Map<String,String>> coordMap =
            new Map<String, Map<String,String>>{

            '19.1136,72.8697' =>
                new Map<String,String>{
                    'address' =>
                        'Shop 12 Marol Industrial'
                        + ' Estate Andheri East'
                        + ' Mumbai Maharashtra',
                    'pinCode' => '500081',
                    'city'    => 'Mumbai',
                    'state'   => 'Maharashtra'
                },
            '17.4495,78.3773' =>
                new Map<String,String>{
                    'address' =>
                        'Madhapur Hi-Tech City'
                        + ' Road Hyderabad'
                        + ' Telangana',
                    'pinCode' => '500082',
                    'city'    => 'Hyderabad',
                    'state'   => 'Telangana'
                },
            '12.9352,77.6245' =>
                new Map<String,String>{
                    'address' =>
                        'Koramangala Block 5'
                        + ' 80 Ft Road'
                        + ' Bengaluru Karnataka',
                    'pinCode' => '560034',
                    'city'    => 'Bengaluru',
                    'state'   => 'Karnataka'
                },
            '28.5733,77.3219' =>
                new Map<String,String>{
                    'address' =>
                        'Sector 18 Atta Market'
                        + ' Noida Uttar Pradesh',
                    'pinCode' => '201301',
                    'city'    => 'Noida',
                    'state'   => 'Uttar Pradesh'
                },
            '13.0418,80.2341' =>
                new Map<String,String>{
                    'address' =>
                        'T Nagar Pondy Bazaar'
                        + ' Chennai Tamil Nadu',
                    'pinCode' => '600017',
                    'city'    => 'Chennai',
                    'state'   => 'Tamil Nadu'
                },
            '19.1350,72.8151' =>
                new Map<String,String>{
                    'address' =>
                        'Plot 8 Andheri West'
                        + ' Versova Mumbai'
                        + ' Maharashtra',
                    'pinCode' => '400061',
                    'city'    => 'Mumbai',
                    'state'   => 'Maharashtra'
                },
            '19.0596,72.8295' =>
                new Map<String,String>{
                    'address' =>
                        'Ground Floor Bandra'
                        + ' West SV Road'
                        + ' Mumbai Maharashtra',
                    'pinCode' => '400050',
                    'city'    => 'Mumbai',
                    'state'   => 'Maharashtra'
                },
            '17.4126,78.4484' =>
                new Map<String,String>{
                    'address' =>
                        'Banjara Hills Road'
                        + ' No 12 Hyderabad'
                        + ' Telangana',
                    'pinCode' => '500034',
                    'city'    => 'Hyderabad',
                    'state'   => 'Telangana'
                },
            '18.5188,73.8397' =>
                new Map<String,String>{
                    'address' =>
                        'FC Road Deccan'
                        + ' Gymkhana Pune'
                        + ' Maharashtra',
                    'pinCode' => '411004',
                    'city'    => 'Pune',
                    'state'   => 'Maharashtra'
                },
            '12.9698,77.7499' =>
                new Map<String,String>{
                    'address' =>
                        'Whitefield Main Road'
                        + ' Opp ITPL Bengaluru'
                        + ' Karnataka',
                    'pinCode' => '560066',
                    'city'    => 'Bengaluru',
                    'state'   => 'Karnataka'
                }
        };

        String key =
            String.valueOf(lat.setScale(4))
            + ','
            + String.valueOf(lng.setScale(4));

        if (coordMap.containsKey(key)) {
            Map<String,String> d =
                coordMap.get(key);
            r.address = d.get('address');
            r.pinCode = d.get('pinCode');
            r.city    = d.get('city');
            r.state   = d.get('state');
        } else {
            r.address =
                String.valueOf(lat)
                + ', '
                + String.valueOf(lng)
                + ' (address lookup pending)';
            r.pinCode = '';
            r.city    = '';
            r.state   = '';
        }

        return r;
    }

    // ── Live resolver ──────────────────────────
    private static MockResult liveResolve(
            Decimal lat, Decimal lng) {

        MockResult r = new MockResult();

        try {
            Http h = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint(
                'callout:Google_Maps_API'
                + '/maps/api/geocode/json'
                + '?latlng=' + lat + ',' + lng
                + '&key=' + MAPS_API_KEY);
            req.setMethod('GET');
            HttpResponse res = h.send(req);

            if (res.getStatusCode() == 200) {
                Map<String,Object> body =
                    (Map<String,Object>)
                    JSON.deserializeUntyped(
                        res.getBody());
                List<Object> results2 =
                    (List<Object>)
                    body.get('results');

                if (results2 != null
                        && !results2.isEmpty()) {
                    Map<String,Object> first =
                        (Map<String,Object>)
                        results2[0];
                    r.address = (String)
                        first.get(
                            'formatted_address');

                    List<Object> components =
                        (List<Object>) first.get(
                            'address_components');
                    if (components != null) {
                        for (Object comp
                                : components) {
                            Map<String,Object> c =
                                (Map<String,Object>)
                                comp;
                            List<Object> types =
                                (List<Object>)
                                c.get('types');
                            if (types != null) {
                                if (types.contains(
                                    'postal_code')) {
                                    r.pinCode =
                                        (String) c
                                        .get('long_name');
                                }
                                if (types.contains(
                                    'locality')) {
                                    r.city =
                                        (String) c
                                        .get('long_name');
                                }
                                if (types.contains(
                                'administrative_area'
                                + '_level_1')) {
                                    r.state =
                                        (String) c
                                        .get('long_name');
                                }
                            }
                        }
                    }
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'Maps API error: '
                + e.getMessage());
            r.address =
                String.valueOf(lat)
                + ', '
                + String.valueOf(lng);
        }

        return r;
    }

    // ── Inner classes ──────────────────────────

    private class MockResult {
        String address = '';
        String pinCode = '';
        String city    = '';
        String state   = '';
    }

    public class GPSResult {
        @InvocableVariable
        public Decimal latitude;

        @InvocableVariable
        public Decimal longitude;

        @InvocableVariable
        public String  resolvedAddress;

        @InvocableVariable
        public String  pinCode;

        @InvocableVariable
        public String  city;

        @InvocableVariable
        public String  state;

        @InvocableVariable
        public Boolean success;
    }
}