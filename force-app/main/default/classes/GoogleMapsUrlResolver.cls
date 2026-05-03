/**
 * Utility class to resolve Google Maps short URLs and extract latitude/longitude coordinates.
 * 
 * @example
 * String shortUrl = 'https://maps.app.goo.gl/AxxZHFuMLSd7NJBv6';
 * GoogleMapsUrlResolver.CoordinateResult result = GoogleMapsUrlResolver.resolveUrl(shortUrl);
 * if (result.isSuccess) {
 *     System.debug('Latitude: ' + result.latitude);
 *     System.debug('Longitude: ' + result.longitude);
 * }
 */
public with sharing class GoogleMapsUrlResolver {
    
    private static final String MAPS_GOOGLE_DOMAIN = 'maps.google.com';
    private static final String MAPS_APP_DOMAIN = 'maps.app.goo.gl';
    private static final Pattern COORDINATE_PATTERN_AT = Pattern.compile('@(-?\\d+\\.\\d+),(-?\\d+\\.\\d+)');
    private static final Pattern COORDINATE_PATTERN_SEARCH = Pattern.compile('/search/(-?\\d+\\.\\d+),\\+?(-?\\d+\\.\\d+)');
    private static final Pattern COORDINATE_PATTERN_QUERY = Pattern.compile('[?&]q=(-?\\d+\\.\\d+),\\+?(-?\\d+\\.\\d+)');
    private static final Pattern COORDINATE_PATTERN_DATA = Pattern.compile('!3d(-?\\d+\\.\\d+)!4d(-?\\d+\\.\\d+)');
    private static final Integer TIMEOUT_MILLISECONDS = 10000;
    private static final Integer MAX_REDIRECTS = 5;
    
    /**
     * Result wrapper for coordinate resolution.
     */
    public class CoordinateResult {
        @AuraEnabled public Boolean isSuccess { get; set; }
        @AuraEnabled public Decimal latitude { get; set; }
        @AuraEnabled public Decimal longitude { get; set; }
        @AuraEnabled public String errorMessage { get; set; }
        @AuraEnabled public String resolvedUrl { get; set; }
        
        public CoordinateResult() {
            this.isSuccess = false;
        }
    }
    
    /**
     * Resolves a Google Maps short URL and extracts the latitude and longitude coordinates.
     * 
     * @param shortUrl The Google Maps short URL (e.g., https://maps.app.goo.gl/AxxZHFuMLSd7NJBv6)
     * @return CoordinateResult containing success status, coordinates, and any error messages
     * @throws IllegalArgumentException if the URL is null or blank
     * 
     * @example
     * String shortUrl = 'https://maps.app.goo.gl/AxxZHFuMLSd7NJBv6';
     * CoordinateResult result = GoogleMapsUrlResolver.resolveUrl(shortUrl);
     */
    public static CoordinateResult resolveUrl(String shortUrl) {
        CoordinateResult result = new CoordinateResult();
        
        // Validate input
        if (String.isBlank(shortUrl)) {
            result.errorMessage = 'URL cannot be null or blank';
            return result;
        }
        
        try {
            // Follow redirects to get the final URL
            String finalUrl = followRedirects(shortUrl);
            result.resolvedUrl = finalUrl;
            
            if (String.isBlank(finalUrl)) {
                result.errorMessage = 'Unable to resolve the short URL';
                return result;
            }
            
            // Extract coordinates from the final URL
            Map<String, Decimal> coordinates = extractCoordinates(finalUrl);
            
            if (coordinates == null || coordinates.isEmpty()) {
                result.errorMessage = 'No coordinates found in the resolved URL';
                return result;
            }
            
            result.latitude = coordinates.get('latitude');
            result.longitude = coordinates.get('longitude');
            result.isSuccess = true;
            
        } catch (Exception e) {
            result.errorMessage = 'Error resolving URL: ' + e.getMessage();
            result.isSuccess = false;
        }
        
        return result;
    }
    
    /**
     * Follows HTTP redirects to get the final destination URL.
     * 
     * @param initialUrl The starting URL to follow
     * @return The final resolved URL after all redirects
     */
    private static String followRedirects(String initialUrl) {
        String currentUrl = initialUrl;
        Integer redirectCount = 0;
        
        while (redirectCount < MAX_REDIRECTS) {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(currentUrl);
            req.setMethod('GET');
            req.setTimeout(TIMEOUT_MILLISECONDS);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            Integer statusCode = res.getStatusCode();
            
            // Check if it's a redirect (3xx status codes)
            if (statusCode >= 300 && statusCode < 400) {
                String locationHeader = res.getHeader('Location');
                
                if (String.isBlank(locationHeader)) {
                    break;
                }
                
                // Handle relative URLs
                if (locationHeader.startsWith('/')) {
                    URL parsedUrl = new URL(currentUrl);
                    locationHeader = parsedUrl.getProtocol() + '://' + parsedUrl.getHost() + locationHeader;
                }
                
                currentUrl = locationHeader;
                redirectCount++;
            } else if (statusCode == 200) {
                // Successfully reached final URL
                return currentUrl;
            } else {
                // Error status code
                throw new GoogleMapsUrlResolverException('HTTP request failed with status code: ' + statusCode);
            }
        }
        
        if (redirectCount >= MAX_REDIRECTS) {
            throw new GoogleMapsUrlResolverException('Maximum redirect limit reached');
        }
        
        return currentUrl;
    }
    
    /**
     * Extracts latitude and longitude coordinates from a Google Maps URL.
     * Supports various Google Maps URL formats:
     * - @23.189127,77.457311 format
     * - /search/23.189127,+77.457311 format
     * - ?q=23.189127,+77.457311 format
     * - !3d23.189127!4d77.457311 format (Google Maps place URLs)
     * 
     * @param url The Google Maps URL containing coordinates
     * @return Map with 'latitude' and 'longitude' keys, or null if coordinates not found
     */
    private static Map<String, Decimal> extractCoordinates(String url) {
        if (String.isBlank(url)) {
            return null;
        }
        
        // Try different coordinate patterns in order of specificity
        List<Pattern> patterns = new List<Pattern>{
            COORDINATE_PATTERN_DATA,    // !3d23.189127!4d77.457311 (Google Maps place URLs)
            COORDINATE_PATTERN_SEARCH,  // /search/23.189127,+77.457311
            COORDINATE_PATTERN_AT,      // @23.189127,77.457311
            COORDINATE_PATTERN_QUERY    // ?q=23.189127,+77.457311
        };
        
        for (Pattern pattern : patterns) {
            Matcher matcher = pattern.matcher(url);
            
            if (matcher.find()) {
                String latStr = matcher.group(1);
                String lngStr = matcher.group(2);
                
                try {
                    Decimal latitude = Decimal.valueOf(latStr);
                    Decimal longitude = Decimal.valueOf(lngStr);
                    
                    // Ensure 6 decimal places (round to nearest)
                    latitude = latitude.setScale(6, RoundingMode.HALF_UP);
                    longitude = longitude.setScale(6, RoundingMode.HALF_UP);
                    
                    // Validate coordinate ranges
                    if (latitude < -90 || latitude > 90) {
                        throw new GoogleMapsUrlResolverException('Invalid latitude value: ' + latitude);
                    }
                    if (longitude < -180 || longitude > 180) {
                        throw new GoogleMapsUrlResolverException('Invalid longitude value: ' + longitude);
                    }
                    
                    return new Map<String, Decimal>{
                        'latitude' => latitude,
                        'longitude' => longitude
                    };
                } catch (Exception e) {
                    throw new GoogleMapsUrlResolverException('Error parsing coordinates: ' + e.getMessage());
                }
            }
        }
        
        return null;
    }
    
    /**
     * Custom exception for Google Maps URL resolution errors.
     */
    public class GoogleMapsUrlResolverException extends Exception {}
}