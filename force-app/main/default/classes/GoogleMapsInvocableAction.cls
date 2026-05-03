/**
 * Invocable Apex action for resolving Google Maps URLs and retrieving address details.
 * Designed for use with Agentforce agents and Flows.
 * 
 * @example
 * Input: Google Maps short URL (https://maps.app.goo.gl/AxxZHFuMLSd7NJBv6)
 * Output: Coordinates and formatted address information
 */
public with sharing class GoogleMapsInvocableAction {
    
    /**
     * Request input for the invocable method.
     */
    public class Request {
        @InvocableVariable(
            label='Google Maps URL'
            description='The Google Maps URL to resolve (short or full URL)'
            required=true
        )
        public String mapsUrl;
        
        @InvocableVariable(
            label='Include Geocoding'
            description='Whether to fetch address details (requires API key configuration)'
            required=false
        )
        public Boolean includeGeocoding;
    }
    
    /**
     * Response output from the invocable method.
     */
    public class Response {
        @InvocableVariable(label='Success')
        public Boolean isSuccess;
        
        @InvocableVariable(label='Latitude')
        public Decimal latitude;
        
        @InvocableVariable(label='Longitude')
        public Decimal longitude;
        
        @InvocableVariable(label='Formatted Address')
        public String formattedAddress;
        
        @InvocableVariable(label='Street')
        public String street;
        
        @InvocableVariable(label='City')
        public String city;
        
        @InvocableVariable(label='State')
        public String state;
        
        @InvocableVariable(label='Country')
        public String country;
        
        @InvocableVariable(label='Postal Code')
        public String postalCode;
        
        @InvocableVariable(label='Resolved URL')
        public String resolvedUrl;
        
        @InvocableVariable(label='Error Message')
        public String errorMessage;
        
        @InvocableVariable(label='Error Type')
        public String errorType;
        
        public Response() {
            this.isSuccess = false;
        }
    }
    
    /**
     * Resolves Google Maps URLs and optionally retrieves address information.
     * 
     * @param requests List of request objects containing Google Maps URLs
     * @return List of response objects with coordinates and address details
     */
    @InvocableMethod(
        label='Resolve Google Maps URL'
        description='Resolves a Google Maps URL to coordinates and optionally retrieves address details'
        category='Location Services'
        callout=true
    )
    public static List<Response> resolveGoogleMapsUrl(List<Request> requests) {
        List<Response> responses = new List<Response>();
        
        for (Request req : requests) {
            Response res = new Response();
            
            try {
                // Validate input
                if (String.isBlank(req.mapsUrl)) {
                    res.errorMessage = 'Google Maps URL is required';
                    res.errorType = 'ValidationError';
                    responses.add(res);
                    continue;
                }
                
                // Set default for includeGeocoding if not specified
                Boolean performGeocoding = (req.includeGeocoding != null) ? req.includeGeocoding : true;
                
                // Step 1: Resolve the URL to get coordinates
                GoogleMapsUrlResolver.CoordinateResult urlResult = 
                    GoogleMapsUrlResolver.resolveUrl(req.mapsUrl);
                
                if (!urlResult.isSuccess) {
                    res.errorMessage = urlResult.errorMessage;
                    res.errorType = 'UrlResolutionError';
                    responses.add(res);
                    continue;
                }
                
                // Populate coordinate information
                res.latitude = urlResult.latitude;
                res.longitude = urlResult.longitude;
                res.resolvedUrl = urlResult.resolvedUrl;
                
                // Step 2: Optionally perform geocoding to get address
                if (performGeocoding) {
                    GoogleMapsGeocodeService.GeocodeResult geocodeResult = 
                        GoogleMapsGeocodeService.reverseGeocode(urlResult.latitude, urlResult.longitude);
                    
                    if (geocodeResult.isSuccess) {
                        res.formattedAddress = geocodeResult.formattedAddress;
                        res.street = geocodeResult.street;
                        res.city = geocodeResult.city;
                        res.state = geocodeResult.state;
                        res.country = geocodeResult.country;
                        res.postalCode = geocodeResult.postalCode;
                        res.isSuccess = true;
                    } else {
                        // Geocoding failed, but we still have coordinates
                        res.isSuccess = true;
                        res.errorMessage = 'Coordinates resolved successfully, but geocoding failed: ' + 
                            geocodeResult.errorMessage;
                        res.errorType = 'GeocodingWarning';
                    }
                } else {
                    // Just coordinates, no geocoding requested
                    res.isSuccess = true;
                }
                
            } catch (Exception e) {
                res.isSuccess = false;
                res.errorMessage = 'Unexpected error: ' + e.getMessage();
                res.errorType = e.getTypeName();
            }
            
            responses.add(res);
        }
        
        return responses;
    }
}