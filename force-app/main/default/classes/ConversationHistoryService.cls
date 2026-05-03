/**
 * Service class to fetch conversation history messages via Salesforce Connect API.
 * ConversationHistory is not queryable via SOQL, so this service uses REST API.
 * 
 * @example
 * String conversationId = '0Mx5g000000001ECAQ';
 * ConversationHistoryService.ConversationResult result = 
 *     ConversationHistoryService.getLatestMessage(conversationId);
 * if (result.isSuccess) {
 *     System.debug('Latest Message: ' + result.messageText);
 * }
 */
public with sharing class ConversationHistoryService {
    
    private static final String CONNECT_API_BASE_PATH = '/services/data/v66.0/connect/conversation-history';
    private static final Integer TIMEOUT_MILLISECONDS = 120000;
    private static final Integer DEFAULT_PAGE_SIZE = 50;
    
    /**
     * Request input for the invocable method.
     */
    public class Request {
        @InvocableVariable(
            label='Conversation ID'
            description='The ID of the MessagingSession to retrieve messages from'
            required=true
        )
        public String conversationId;
        
        @InvocableVariable(
            label='Include Full Transcript'
            description='Whether to include the complete conversation transcript'
            required=false
        )
        public Boolean includeFullTranscript;
    }
    
    /**
     * Response output for the invocable method.
     */
    public class Response {
        @InvocableVariable(label='Success')
        public Boolean isSuccess;
        
        @InvocableVariable(label='Latest Message Text')
        public String messageText;
        
        @InvocableVariable(label='Message ID')
        public String messageId;
        
        @InvocableVariable(label='Sender ID')
        public String senderId;
        
        @InvocableVariable(label='Sender Name')
        public String senderName;
        
        @InvocableVariable(label='Sender Role')
        public String senderRole;
        
        @InvocableVariable(label='Message Timestamp')
        public DateTime messageTimestamp;
        
        @InvocableVariable(label='Message Type')
        public String messageType;
        
        @InvocableVariable(label='Full Transcript')
        public String fullTranscript;
        
        @InvocableVariable(label='Error Message')
        public String errorMessage;
        
        @InvocableVariable(label='Error Type')
        public String errorType;
        
        public Response() {
            this.isSuccess = false;
        }
    }
    
    /**
     * Result wrapper for conversation history API response.
     */
    public class ConversationResult {
        @AuraEnabled public Boolean isSuccess { get; set; }
        @AuraEnabled public String messageText { get; set; }
        @AuraEnabled public String messageId { get; set; }
        @AuraEnabled public String senderId { get; set; }
        @AuraEnabled public String senderName { get; set; }
        @AuraEnabled public String senderRole { get; set; }
        @AuraEnabled public DateTime messageTimestamp { get; set; }
        @AuraEnabled public String messageType { get; set; }
        @AuraEnabled public String fullTranscript { get; set; }
        @AuraEnabled public String errorMessage { get; set; }
        
        public ConversationResult() {
            this.isSuccess = false;
        }
    }
    
    /**
     * Fetches the latest message from a conversation via Connect API.
     * 
     * @param conversationId The ID of the conversation (MessagingSession)
     * @return ConversationResult containing the latest message details or error
     * 
     * @example
     * ConversationResult result = ConversationHistoryService.getLatestMessage('0Mx5g000000001ECAQ');
     */
    public static ConversationResult getLatestMessage(String conversationId) {
        ConversationResult result = new ConversationResult();
        
        // Validate input
        if (String.isBlank(conversationId)) {
            result.errorMessage = 'Conversation ID cannot be blank';
            return result;
        }
        
        // Validate ID format
        if (!isValidSalesforceId(conversationId)) {
            result.errorMessage = 'Invalid Conversation ID format: ' + conversationId;
            return result;
        }
        
        try {
            // Make HTTP callout to Connect API
            String responseBody = makeConversationHistoryCallout(conversationId);
            
            // Parse the response and extract latest message
            parseConversationResponse(responseBody, result);
            
        } catch (CalloutException e) {
            result.errorMessage = 'Callout error: ' + e.getMessage();
            result.isSuccess = false;
        } catch (Exception e) {
            result.errorMessage = 'Error fetching conversation history: ' + e.getMessage();
            result.isSuccess = false;
        }
        
        return result;
    }
    
    /**
     * Fetches the complete message transcript for a conversation.
     * 
     * @param conversationId The ID of the conversation (MessagingSession)
     * @return ConversationResult containing the full transcript or error
     * 
     * @example
     * ConversationResult result = ConversationHistoryService.getFullTranscript('0Mx5g000000001ECAQ');
     */
    public static ConversationResult getFullTranscript(String conversationId) {
        ConversationResult result = new ConversationResult();
        
        // Validate input
        if (String.isBlank(conversationId)) {
            result.errorMessage = 'Conversation ID cannot be blank';
            return result;
        }
        
        if (!isValidSalesforceId(conversationId)) {
            result.errorMessage = 'Invalid Conversation ID format: ' + conversationId;
            return result;
        }
        
        try {
            // Make HTTP callout to Connect API
            String responseBody = makeConversationHistoryCallout(conversationId);
            
            // Parse and build full transcript
            buildFullTranscript(responseBody, result);
            
        } catch (CalloutException e) {
            result.errorMessage = 'Callout error: ' + e.getMessage();
            result.isSuccess = false;
        } catch (Exception e) {
            result.errorMessage = 'Error fetching conversation history: ' + e.getMessage();
            result.isSuccess = false;
        }
        
        return result;
    }
    
    /**
     * Validates Salesforce ID format (15 or 18 characters).
     * 
     * @param recordId The ID to validate
     * @return True if valid Salesforce ID format
     */
    private static Boolean isValidSalesforceId(String recordId) {
        if (String.isBlank(recordId)) {
            return false;
        }
        
        String idPattern = '[a-zA-Z0-9]{15}|[a-zA-Z0-9]{18}';
        return Pattern.matches(idPattern, recordId);
    }
    
    /**
     * Makes HTTP callout to Salesforce Connect API for conversation history.
     * 
     * @param conversationId The conversation ID
     * @return The JSON response body
     */
    private static String makeConversationHistoryCallout(String conversationId) {
        // Build endpoint URL
        String instanceUrl = URL.getOrgDomainUrl().toExternalForm();
        String endpoint = instanceUrl + CONNECT_API_BASE_PATH + '/' + conversationId + 
                         '?pageSize=' + DEFAULT_PAGE_SIZE;
        
        // Create HTTP request
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + getSessionId());
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setTimeout(TIMEOUT_MILLISECONDS);
        
        // Send request
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        // Check response status
        if (res.getStatusCode() == 404) {
            throw new ConversationHistoryException('Conversation not found: ' + conversationId);
        } else if (res.getStatusCode() == 403) {
            throw new ConversationHistoryException('Access denied to conversation history. Check user permissions.');
        } else if (res.getStatusCode() != 200) {
            throw new ConversationHistoryException('API request failed with status ' + 
                res.getStatusCode() + ': ' + res.getBody());
        }
        
        return res.getBody();
    }
    
    /**
     * Retrieves the current session ID for API authentication.
     * 
     * @return The session ID
     */
    private static String getSessionId() {
        return UserInfo.getSessionId();
    }
    
    /**
     * Parses the Connect API response and extracts the latest message.
     * 
     * @param jsonResponse The JSON response string
     * @param result The ConversationResult to populate
     */
    private static void parseConversationResponse(String jsonResponse, ConversationResult result) {
        if (String.isBlank(jsonResponse)) {
            result.errorMessage = 'Empty response from Connect API';
            return;
        }
        
        try {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(jsonResponse);
            
            // Get messages array
            List<Object> messages = (List<Object>) responseMap.get('messages');
            
            if (messages == null || messages.isEmpty()) {
                result.errorMessage = 'No messages found in conversation';
                return;
            }
            
            // Get the latest message (last in the array, assuming chronological order)
            Map<String, Object> latestMessage = (Map<String, Object>) messages[messages.size() - 1];
            
            // Extract message details
            result.messageId = (String) latestMessage.get('id');
            result.messageText = (String) latestMessage.get('messageText');
            result.messageType = (String) latestMessage.get('messageType');
            
            // Extract sender information
            Map<String, Object> sender = (Map<String, Object>) latestMessage.get('sender');
            if (sender != null) {
                result.senderId = (String) sender.get('id');
                result.senderName = (String) sender.get('name');
                result.senderRole = (String) sender.get('role');
            }
            
            // Parse timestamp
            String timestampStr = (String) latestMessage.get('timestamp');
            if (String.isNotBlank(timestampStr)) {
                result.messageTimestamp = parseTimestamp(timestampStr);
            }
            
            result.isSuccess = true;
            
        } catch (JSONException e) {
            result.errorMessage = 'Error parsing API response: ' + e.getMessage();
            result.isSuccess = false;
        } catch (Exception e) {
            result.errorMessage = 'Unexpected error parsing response: ' + e.getMessage();
            result.isSuccess = false;
        }
    }
    
    /**
     * Builds a full conversation transcript from all messages.
     * 
     * @param jsonResponse The JSON response string
     * @param result The ConversationResult to populate
     */
    private static void buildFullTranscript(String jsonResponse, ConversationResult result) {
        if (String.isBlank(jsonResponse)) {
            result.errorMessage = 'Empty response from Connect API';
            return;
        }
        
        try {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(jsonResponse);
            
            // Get messages array
            List<Object> messages = (List<Object>) responseMap.get('messages');
            
            if (messages == null || messages.isEmpty()) {
                result.errorMessage = 'No messages found in conversation';
                return;
            }
            
            // Build transcript
            List<String> transcriptLines = new List<String>();
            
            for (Object msgObj : messages) {
                Map<String, Object> msg = (Map<String, Object>) msgObj;
                
                String senderName = 'Unknown';
                Map<String, Object> sender = (Map<String, Object>) msg.get('sender');
                if (sender != null && sender.get('name') != null) {
                    senderName = (String) sender.get('name');
                }
                
                String messageText = (String) msg.get('messageText');
                String timestamp = (String) msg.get('timestamp');
                
                String line = '[' + (timestamp ?? 'No timestamp') + '] ' + 
                             senderName + ': ' + (messageText ?? '');
                transcriptLines.add(line);
            }
            
            result.fullTranscript = String.join(transcriptLines, '\n');
            
            // Also populate latest message details
            Map<String, Object> latestMessage = (Map<String, Object>) messages[messages.size() - 1];
            result.messageId = (String) latestMessage.get('id');
            result.messageText = (String) latestMessage.get('messageText');
            result.messageType = (String) latestMessage.get('messageType');
            
            Map<String, Object> sender = (Map<String, Object>) latestMessage.get('sender');
            if (sender != null) {
                result.senderId = (String) sender.get('id');
                result.senderName = (String) sender.get('name');
                result.senderRole = (String) sender.get('role');
            }
            
            String timestampStr = (String) latestMessage.get('timestamp');
            if (String.isNotBlank(timestampStr)) {
                result.messageTimestamp = parseTimestamp(timestampStr);
            }
            
            result.isSuccess = true;
            
        } catch (JSONException e) {
            result.errorMessage = 'Error parsing API response: ' + e.getMessage();
            result.isSuccess = false;
        } catch (Exception e) {
            result.errorMessage = 'Unexpected error building transcript: ' + e.getMessage();
            result.isSuccess = false;
        }
    }
    
    /**
     * Parses ISO 8601 timestamp string to DateTime.
     * 
     * @param timestampStr The timestamp string
     * @return DateTime object
     */
    private static DateTime parseTimestamp(String timestampStr) {
        try {
            // Handle ISO 8601 format: 2024-01-15T10:30:00.000Z
            return DateTime.valueOfGmt(timestampStr.replace('T', ' ').replace('Z', ''));
        } catch (Exception e) {
            return null;
        }
    }
    
    /**
     * Invocable method to fetch conversation history from Flow.
     * 
     * @param requests List of request objects containing conversation IDs
     * @return List of response objects with message details
     */
    @InvocableMethod(
        label='Get Conversation History'
        description='Fetches the latest message and optionally full transcript from a MessagingSession'
        category='Messaging'
        callout=true
    )
    public static List<Response> getConversationHistory(List<Request> requests) {
        List<Response> responses = new List<Response>();
        
        for (Request req : requests) {
            Response res = new Response();
            
            try {
                // Validate input
                if (String.isBlank(req.conversationId)) {
                    res.errorMessage = 'Conversation ID is required';
                    res.errorType = 'ValidationError';
                    responses.add(res);
                    continue;
                }
                
                // Set default for includeFullTranscript if not specified
                Boolean fetchFullTranscript = (req.includeFullTranscript != null) ? 
                    req.includeFullTranscript : false;
                
                // Fetch conversation history
                ConversationResult result;
                if (fetchFullTranscript) {
                    result = getFullTranscript(req.conversationId);
                } else {
                    result = getLatestMessage(req.conversationId);
                }
                
                // Map result to response
                res.isSuccess = result.isSuccess;
                res.messageText = result.messageText;
                res.messageId = result.messageId;
                res.senderId = result.senderId;
                res.senderName = result.senderName;
                res.senderRole = result.senderRole;
                res.messageTimestamp = result.messageTimestamp;
                res.messageType = result.messageType;
                res.fullTranscript = result.fullTranscript;
                res.errorMessage = result.errorMessage;
                
                if (!result.isSuccess) {
                    res.errorType = 'ConversationHistoryError';
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
    
    /**
     * Custom exception for conversation history errors.
     */
    public class ConversationHistoryException extends Exception {}
}