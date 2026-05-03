public with sharing class WhatsAppMessagingSessionService {
    /**
     * This class exposes Invocable methods usable from Flow.
     * It intentionally DOES NOT call WhatsAppGPSParser. Instead it returns message text + metadata
     * so your Flow can pass the message into WhatsAppGPSParser (also implemented as a Flow action).
     *
     * Constraints:
     * - No SOQL against Message records is performed.
     * - If your org exposes Messaging.Session APIs, update the session retrieval implementation accordingly.
     */

    // Invocable input wrapper for session-based requests
    public class Request {
        @InvocableVariable(label='Session Id' required=true)
        public String sessionId;
    }

    // Invocable input wrapper for payload-based requests (pass JSON stringified payload from flow)
    public class PayloadRequest {
        @InvocableVariable(label='Serialized Payload JSON' required=true)
        public String payloadJson;
    }

    // Invocable response wrapper for returning a single message (Flow can iterate over result list)
    public class Response {
        @InvocableVariable(label='Message Text')
        public String messageText;

        @InvocableVariable(label='Metadata')
        public Map<String, String> metadata;

        public Response(String messageText, Map<String, String> metadata) {
            this.messageText = messageText;
            this.metadata = metadata;
        }
    }

    /**
     * Invocable method to fetch messages for the provided session ids.
     * Returns a list of Response objects containing message text + metadata.
     * NOTE: Implementation uses a placeholder approach because Messaging.Session APIs differ across orgs.
     * If your org provides an Apex API to fetch session messages, replace the placeholder with that call.
     */
    @InvocableMethod(label='Fetch WhatsApp Messages by Session' description='Provide session id(s) and returns messages for Flow processing')
    public static List<Response> fetchMessagesBySession(List<Request> requests) {
        List<Response> results = new List<Response>();
        if (requests == null || requests.isEmpty()) return results;

        for (Request req : requests) {
            if (String.isBlank(req.sessionId)) continue;
            try {
                // Placeholder behavior: return a single informational response that Flow can inspect.
                // Replace this block with actual Messaging.Session integration if available in your org.
                Map<String, String> meta = new Map<String, String>{
                    'sessionId' => req.sessionId,
                    'note' => 'Session retrieval not implemented; integration should pass messages into Flow using payload-based invocable or update this method to call Messaging.Session API.'
                };
                results.add(new Response('<<SESSION_RETRIEVAL_NOT_IMPLEMENTED>>', meta));
            } catch (Exception ex) {
                Map<String, String> meta = new Map<String, String>{ 'sessionId' => req.sessionId, 'error' => ex.getMessage() };
                results.add(new Response(null, meta));
            }
        }
        return results;
    }

    /**
     * Invocable method to fetch messages from serialized payloads (useful for Flow when the connector passes the payload).
     * Input: list of PayloadRequest where payloadJson is a JSON string representation of the event/payload.
     * Output: flattened list of Message Responses found in the payloads.
     */
    @InvocableMethod(label='Fetch WhatsApp Messages from Payload' description='Provide serialized payload(s) and returns messages for Flow processing')
    public static List<Response> fetchMessagesFromPayload(List<PayloadRequest> requests) {
        List<Response> results = new List<Response>();
        if (requests == null || requests.isEmpty()) return results;

        for (PayloadRequest pr : requests) {
            if (String.isBlank(pr.payloadJson)) continue;
            try {
                Object deserialized = JSON.deserializeUntyped(pr.payloadJson);
                if (deserialized instanceof Map<String, Object>) {
                    Map<String, Object> payloadMap = (Map<String, Object>) deserialized;
                    List<Object> messages = extractMessagesFromPayloadMap(payloadMap);
                    for (Object rawMsg : messages) {
                        String msgText;
                        Map<String, String> meta = new Map<String, String>();
                        if (rawMsg instanceof Map<String, Object>) {
                            Map<String, Object> msgMap = (Map<String, Object>) rawMsg;
                            if (msgMap.containsKey('text')) {
                                msgText = String.valueOf(msgMap.get('text'));
                            } else if (msgMap.containsKey('body')) {
                                msgText = String.valueOf(msgMap.get('body'));
                            } else if (msgMap.containsKey('message')) {
                                msgText = String.valueOf(msgMap.get('message'));
                            } else {
                                msgText = JSON.serialize(msgMap);
                            }
                            if (msgMap.containsKey('from')) meta.put('from', String.valueOf(msgMap.get('from')));
                            if (msgMap.containsKey('id')) meta.put('messageId', String.valueOf(msgMap.get('id')));
                            if (msgMap.containsKey('timestamp')) meta.put('timestamp', String.valueOf(msgMap.get('timestamp')));
                        } else {
                            msgText = String.valueOf(rawMsg);
                        }
                        if (!String.isBlank(msgText)) {
                            results.add(new Response(msgText, meta));
                        }
                    }
                } else if (deserialized instanceof List<Object>) {
                    for (Object item : (List<Object>) deserialized) {
                        // treat each list item as a potential message
                        String msgText = (item == null) ? null : String.valueOf(item);
                        if (!String.isBlank(msgText)) {
                            results.add(new Response(msgText, new Map<String, String>()));
                        }
                    }
                }
            } catch (Exception ex) {
                Map<String, String> meta = new Map<String, String>{ 'error' => ex.getMessage() };
                results.add(new Response(null, meta));
            }
        }
        return results;
    }

    // Helper to extract a messages list from a deserialized payload map
    private static List<Object> extractMessagesFromPayloadMap(Map<String, Object> payloadMap) {
        Object messagesObj = null;
        if (payloadMap.containsKey('messages')) messagesObj = payloadMap.get('messages');
        else if (payloadMap.containsKey('message')) messagesObj = payloadMap.get('message');
        else if (payloadMap.containsKey('body')) messagesObj = payloadMap.get('body');
        else if (payloadMap.containsKey('text')) messagesObj = payloadMap.get('text');

        List<Object> messagesList = new List<Object>();
        if (messagesObj instanceof List<Object>) {
            messagesList = (List<Object>) messagesObj;
        } else if (messagesObj != null) {
            // single message object or primitive
            messagesList.add(messagesObj);
        } else {
            // No explicit message container - attempt to see if top-level payload is itself a message map
            messagesList.add(payloadMap);
        }
        return messagesList;
    }

    /**
     * Backwards-compatible helper for non-invocable callers that had used fetchConversationFromPlatformEvent.
     * Retained but modified to NOT call WhatsAppGPSParser - instead returns a list of Response objects.
     */
    public static List<Response> fetchConversationFromPlatformEvent(Map<String, Object> eventPayload) {
        List<Response> results = new List<Response>();
        if (eventPayload == null) return results;

        List<Object> messages = extractMessagesFromPayloadMap(eventPayload);
        for (Object rawMsg : messages) {
            try {
                String msgText;
                Map<String, String> meta = new Map<String, String>();

                if (rawMsg instanceof Map<String, Object>) {
                    Map<String, Object> msgMap = (Map<String, Object>) rawMsg;
                    if (msgMap.containsKey('text')) msgText = String.valueOf(msgMap.get('text'));
                    else if (msgMap.containsKey('body')) msgText = String.valueOf(msgMap.get('body'));
                    else if (msgMap.containsKey('message')) msgText = String.valueOf(msgMap.get('message'));
                    else msgText = JSON.serialize(msgMap);

                    if (msgMap.containsKey('from')) meta.put('from', String.valueOf(msgMap.get('from')));
                    if (msgMap.containsKey('id')) meta.put('messageId', String.valueOf(msgMap.get('id')));
                    if (msgMap.containsKey('timestamp')) meta.put('timestamp', String.valueOf(msgMap.get('timestamp')));
                } else {
                    msgText = String.valueOf(rawMsg);
                }

                if (!String.isBlank(msgText)) {
                    results.add(new Response(msgText, meta));
                }
            } catch (Exception e) {
                System.debug('Error processing message payload: ' + e.getMessage());
            }
        }
        return results;
    }

    /**
     * Helper method to be called by integration code or platform event triggers.
     * This method intentionally does not perform SOQL on messaging objects.
     */
    public static void handleInboundWhatsAppEvent(Map<String, Object> eventPayload) {
        // Validate source / channel if needed (org-specific)
        // Previously this method parsed and forwarded to WhatsAppGPSParser; now it simply returns.
        // Keep behavior minimal: no-op or callers may use fetchConversationFromPlatformEvent to get messages.
        return;
    }

    /**
     * Helper method to be called by integration code or platform event triggers.
     * This method intentionally does not perform SOQL on messaging objects.
     */
    public static void handleInboundWhatsAppEvent(Map<String, Object> eventPayload) {
        // Validate source / channel if needed (org-specific)
        fetchConversationFromPlatformEvent(eventPayload);
    }
}