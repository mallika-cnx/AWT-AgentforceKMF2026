/**
 * Service class to perform reverse geocoding using Google Maps Geocoding API.
 * Converts latitude/longitude coordinates to a formatted address.
 * 
 * @example
 * Decimal latitude = 23.189127;
 * Decimal longitude = 77.457311;
 * GoogleMapsGeocodeService.GeocodeResult result = GoogleMapsGeocodeService.reverseGeocode(latitude, longitude);
 * if (result.isSuccess) {
 *     System.debug('Address: ' + result.formattedAddress);
 * }
 */
public with sharing class GoogleMapsGeocodeService {
    
    private static final String API_ENDPOINT = 'https://maps.googleapis.com/maps/api/geocode/json';
    private static final String API_KEY_NAME = 'AIzaSyAvVNVrF40LyMgH6hMKeyDvC5qIru9GIr8';
    private static final Integer TIMEOUT_MILLISECONDS = 10000;
    
    /**
     * Result wrapper for geocoding API response.
     */
    public class GeocodeResult {
        @AuraEnabled public Boolean isSuccess { get; set; }
        @AuraEnabled public String formattedAddress { get; set; }
        @AuraEnabled public String street { get; set; }
        @AuraEnabled public String city { get; set; }
        @AuraEnabled public String state { get; set; }
        @AuraEnabled public String country { get; set; }
        @AuraEnabled public String postalCode { get; set; }
        @AuraEnabled public String errorMessage { get; set; }
        
        public GeocodeResult() {
            this.isSuccess = false;
        }
    }
    
    /**
     * Performs reverse geocoding to convert coordinates to an address.
     * 
     * @param latitude The latitude coordinate
     * @param longitude The longitude coordinate
     * @return GeocodeResult containing address information or error details
     * 
     * @example
     * GeocodeResult result = GoogleMapsGeocodeService.reverseGeocode(23.189127, 77.457311);
     */
    public static GeocodeResult reverseGeocode(Decimal latitude, Decimal longitude) {
        GeocodeResult result = new GeocodeResult();
        
        // Validate inputs
        if (latitude == null || longitude == null) {
            result.errorMessage = 'Latitude and longitude cannot be null';
            return result;
        }
        
        if (latitude < -90 || latitude > 90) {
            result.errorMessage = 'Invalid latitude value: ' + latitude;
            return result;
        }
        
        if (longitude < -180 || longitude > 180) {
            result.errorMessage = 'Invalid longitude value: ' + longitude;
            return result;
        }
        
        try {
            // Retrieve API key from Custom Metadata
            String apiKey = getApiKey();
            
            if (String.isBlank(apiKey)) {
                result.errorMessage = 'Google Maps API key not configured';
                return result;
            }
            
            // Make HTTP callout to Google Maps Geocoding API
            String responseBody = makeGeocodeCallout(latitude, longitude, apiKey);
            
            // Parse the response
            parseGeocodeResponse(responseBody, result);
            
        } catch (Exception e) {
            result.errorMessage = 'Error performing geocoding: ' + e.getMessage();
            result.isSuccess = false;
        }
        
        return result;
    }
    
    /**
     * Retrieves the Google Maps API key from Custom Metadata.
     * 
     * @return The API key string
     */
    private static String getApiKey() {
        // Retrieve from Custom Metadata Type or Custom Settings
        // For now, returning a placeholder that should be configured
        try {
            // Example: retrieve from Custom Metadata Type
            // Google_API_Config__mdt config = Google_API_Config__mdt.getInstance(API_KEY_NAME);
            // return config?.API_Key__c;
            
            // For demo purposes, this should be replaced with actual metadata retrieval
            return API_KEY_NAME; // Replace with actual retrieval logic
            //throw new GoogleMapsGeocodeException('API key must be configured in Custom Metadata or Named Credentials');
        } catch (Exception e) {
            throw new GoogleMapsGeocodeException('Unable to retrieve API key: ' + e.getMessage());
        }
    }
    
    /**
     * Makes the HTTP callout to Google Maps Geocoding API.
     * 
     * @param latitude The latitude coordinate
     * @param longitude The longitude coordinate
     * @param apiKey The Google Maps API key
     * @return The JSON response body as a string
     */
    private static String makeGeocodeCallout(Decimal latitude, Decimal longitude, String apiKey) {
        // Build the request URL
        String latlng = String.valueOf(latitude) + ',' + String.valueOf(longitude);
        String endpoint = API_ENDPOINT + '?latlng=' + EncodingUtil.urlEncode(latlng, 'UTF-8') + 
                         '&key=' + EncodingUtil.urlEncode(apiKey, 'UTF-8');
        
        // Create HTTP request
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        req.setTimeout(TIMEOUT_MILLISECONDS);
        
        // Send request
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        // Check response status
        if (res.getStatusCode() != 200) {
            throw new GoogleMapsGeocodeException('HTTP request failed with status code: ' + 
                res.getStatusCode() + ', Body: ' + res.getBody());
        }
        
        return res.getBody();
    }
    
    /**
     * Parses the Google Maps Geocoding API JSON response.
     * 
     * @param jsonResponse The JSON response string
     * @param result The GeocodeResult object to populate
     */
    private static void parseGeocodeResponse(String jsonResponse, GeocodeResult result) {
        if (String.isBlank(jsonResponse)) {
            result.errorMessage = 'Empty response from geocoding API';
            return;
        }
        
        try {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(jsonResponse);
            
            // Check status
            String status = (String) responseMap.get('status');
            
            if (status != 'OK') {
                result.errorMessage = 'Geocoding API returned status: ' + status;
                return;
            }
            
            // Get results array
            List<Object> results = (List<Object>) responseMap.get('results');
            
            if (results == null || results.isEmpty()) {
                result.errorMessage = 'No results found for the provided coordinates';
                return;
            }
            
            // Parse first result
            Map<String, Object> firstResult = (Map<String, Object>) results[0];
            
            // Get formatted address
            result.formattedAddress = (String) firstResult.get('formatted_address');
            
            // Parse address components
            List<Object> addressComponents = (List<Object>) firstResult.get('address_components');
            
            if (addressComponents != null) {
                String premise;
                String route;
                String landmark;
                String streetNumber;
                String sublocality;
                for (Object component : addressComponents) {
                    Map<String, Object> componentMap = (Map<String, Object>) component;
                    List<Object> types = (List<Object>) componentMap.get('types');
                    String longName = (String) componentMap.get('long_name');
                    String shortName = (String) componentMap.get('short_name');

                    if (types.contains('street_number')) {
                        streetNumber = longName;
                    }
                    if (types.contains('premise')) {
                        premise = longName;
                    }
                    if (types.contains('route')) {
                        route = longName;
                    }
                    if (types.contains('landmark')) {
                        landmark = longName;
                    } else if (types.contains('sublocality') || types.contains('neighborhood')) {
                        sublocality = longName; 
                    } else if (types != null && types.contains('locality')) {
                        result.city = longName;
                    } else if (types != null && types.contains('administrative_area_level_1')) {
                        result.state = shortName;
                    } else if (types != null && types.contains('country')) {
                        result.country = shortName;
                    } else if (types != null && types.contains('postal_code')) {
                        result.postalCode = longName;
                    }
                }
                String finalStreet = '';

                if (premise != null) {
                    finalStreet += premise + ', ';
                }
                if (streetNumber != null) {
                    finalStreet += streetNumber + ' ';
                }
                if (route != null) {
                    finalStreet += route;
                }
                if (landmark != null && route == null) {
                    finalStreet += landmark;
                }
                if(sublocality != null && route == null && landmark == null) {
                    finalStreet += sublocality;
                }

                result.street = finalStreet.trim();
            }
            
            result.isSuccess = true;
            
        } catch (Exception e) {
            result.errorMessage = 'Error parsing geocoding response: ' + e.getMessage();
            result.isSuccess = false;
        }
    }
    
    /**
     * Custom exception for geocoding errors.
     */
    public class GoogleMapsGeocodeException extends Exception {}
}