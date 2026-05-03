public with sharing class StoreSiteAction {

    // INPUT FROM AGENTFORCE / FLOW
    public class Request {
        @InvocableVariable(required=true)
        public Decimal latitude;

        @InvocableVariable(required=true)
        public Decimal longitude;

        @InvocableVariable
        public String locationName;

        @InvocableVariable
        public String address;
    }

    // OUTPUT BACK TO AGENTFORCE / FLOW
    public class Result {
        @InvocableVariable(label='Demand Score')
        public Integer demandScore;

        @InvocableVariable(label='Competition Level')
        public String competitionLevel;

        @InvocableVariable(label='Scorecard')
        public String scorecard;

        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    @InvocableMethod(
        label='Calculate Demand Score'
        description='Calculates a simple demand score from WhatsApp current location'
        category='Store Expansion'
    )
    public static List<Result> calculateDemandScore(List<Request> requests) {
        List<Result> results = new List<Result>();

        for (Request req : requests) {
            Result r = new Result();

            try {
                if (req == null || req.latitude == null || req.longitude == null) {
                    r.success = false;
                    r.errorMessage = 'Latitude and Longitude are required.';
                    results.add(r);
                    continue;
                }

                Integer score = getDemandScore(req.latitude, req.longitude);
                String level = getCompetitionLevel(score);
                String locationText = String.isNotBlank(req.locationName)
                    ? req.locationName
                    : 'Shared WhatsApp Location';

                r.demandScore = score;
                r.competitionLevel = level;
                r.scorecard =
                    '📍 Location: ' + locationText + '\n' +
                    '📊 Demand Score: ' + score + '/100\n' +
                    '🏪 Competition: ' + level;
                r.success = true;

            } catch (Exception e) {
                r.success = false;
                r.errorMessage = 'Unable to calculate demand score.';
            }

            results.add(r);
        }

        return results;
    }

    private static Integer getDemandScore(Decimal lat, Decimal lng) {
        Integer latPart = Math.abs((lat * 100).intValue());
        Integer lngPart = Math.abs((lng * 100).intValue());

        Integer score = Math.mod(latPart + lngPart, 50) + 50; // returns 50-99
        return Math.min(100, Math.max(1, score));
    }

    private static String getCompetitionLevel(Integer score) {
        if (score >= 75) {
            return 'Low';
        } else if (score >= 60) {
            return 'Medium';
        } else {
            return 'High';
        }
    }
}