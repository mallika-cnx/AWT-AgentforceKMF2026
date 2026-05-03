// Class name : HaversineDistanceCalculator
// Created Date: 23/04/2026
// Author: Arnab Saha - CNX
// Description: To Calculate Distance Between places 

public class HaversineDistanceCalculator {
    @InvocableMethod(label='Calculate Haversine Distance (km)') 
    public static List<Result> calculate(List<Request> requests) { 
        System.debug('HaversineDistanceCalculator.calculate() invoked with ' + requests.size() + ' request(s)');
        List<Result> results = new List<Result>(); 
        
        for (Request req : requests) {
            System.debug('Processing request - lat1: ' + req.lat1 + ', lon1: ' + req.lon1 + ', lat2: ' + req.lat2 + ', lon2: ' + req.lon2);
            Result res = new Result();
            
            // Handle null or invalid coordinates by returning null
            if (req.lat1 == null || req.lon1 == null || req.lat2 == null || req.lon2 == null) {
                System.debug('One or more coordinates are null. Returning null distance.');
                res.distance = null;
                results.add(res);
                continue;
            }
            
            Double R = 6371; 
            System.debug('All coordinates present. Calculating distance...');

            Double lat1Rad = req.lat1 * Math.PI / 180;
            Double lat2Rad = req.lat2 * Math.PI / 180;
            Double dLat = (req.lat2 - req.lat1) * Math.PI / 180;
            Double dLon = (req.lon2 - req.lon1) * Math.PI / 180;

            Double a = Math.sin(dLat/2) * Math.sin(dLat/2) 
                     + Math.cos(lat1Rad) 
                     * Math.cos(lat2Rad) 
                     * Math.sin(dLon/2) * Math.sin(dLon/2); 

            Double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a)); 

            res.distance = Decimal.valueOf(R * c).setScale(3);
            System.debug('Calculated distance: ' + res.distance + ' km');
            results.add(res);
        } 

        System.debug('HaversineDistanceCalculator.calculate() completed. Returning ' + results.size() + ' result(s)');
        return results; 
    }

    public class Request { 
        @InvocableVariable(label='Site Latitude' required=false) 
        public Double lat1; 
        
        @InvocableVariable(label='Site Longitude' required=false) 
        public Double lon1; 
        
        @InvocableVariable(label='Competitor Latitude' required=false) 
        public Double lat2; 
        
        @InvocableVariable(label='Competitor Longitude' required=false) 
        public Double lon2; 
    }
    
    public class Result {
        @InvocableVariable(label='Distance (km)')
        public Decimal distance;
    }
}