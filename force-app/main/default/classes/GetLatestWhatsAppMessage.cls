/**
 * GetLatestWhatsAppMessage
 *
 * Invocable Apex action for use in Record-Triggered Flows on MessagingSession.
 * Retrieves the latest inbound message text from a WhatsApp (Enhanced Messaging)
 * session via the Salesforce Connect REST API, since ConversationEntry data is
 * stored off-platform and is NOT accessible through SOQL or Flow references.
 *
 * Prerequisites:
 *   1. Flow optimized for "Actions and Related Records" (required for callouts).
 *      The method uses the current user's session ID for authentication.
 *
 * Flow usage:
 *   - Input  : messagingSessionId  →  {!$Record.Id}
 *   - Output : messageText         →  store in a text variable (e.g. var_MessageText)
 *              senderPhone         →  store in a text variable (e.g. var_SenderPhone)
 *              hasError            →  Boolean — check before proceeding
 *              errorMessage        →  String  — log or use in fault path
 */
public with sharing class GetLatestWhatsAppMessage {

    // ─── Input / Output wrappers ──────────────────────────────────────────────

    public class FlowInput {
        @InvocableVariable(
            label='Messaging Session Id'
            description='Pass {!$Record.Id} from the MessagingSession trigger'
            required=true
        )
        public String messagingSessionId;
    }

    public class FlowOutput {
        @InvocableVariable(label='Message Text')
        public String messageText;

        @InvocableVariable(label='Sender Phone Number')
        public String senderPhone;

        @InvocableVariable(label='Has Error')
        public Boolean hasError;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    // ─── Invocable entry point ────────────────────────────────────────────────

    @InvocableMethod(
        label='Get Latest WhatsApp Message'
        description='Fetches the latest inbound ConversationEntry text for a MessagingSession via the Connect REST API.'
        callout=true
    )
    public static List<FlowOutput> getLatestMessage(List<FlowInput> inputs) {

        List<FlowOutput> outputs = new List<FlowOutput>();

        for (FlowInput input : inputs) {
            FlowOutput output = new FlowOutput();
            output.hasError = false;

            try {
                // ── Step 1: Get ConversationIdentifier from MessagingSession ──
                // ConversationIdentifier is the UUID used by the Connect REST API.
                // ConversationId is the Salesforce record ID — NOT the same thing.
                MessagingSession session = [
                    SELECT
                        Conversation.ConversationIdentifier,
                        EndUserAccountId
                    FROM MessagingSession
                    WHERE Id = :input.messagingSessionId
                    LIMIT 1
                ];

                String conversationIdentifier =
                    session.Conversation.ConversationIdentifier;

                if (String.isBlank(conversationIdentifier)) {
                    output.hasError    = true;
                    output.errorMessage = 'ConversationIdentifier is blank for session: '
                                        + input.messagingSessionId;
                    outputs.add(output);
                    continue;
                }

                // ── Step 2: Call Connect REST API ─────────────────────────────
                // Endpoint: GET /services/data/v62.0/connect/conversation/{identifier}/entries
                // queryDirection=FromEnd returns newest entries first, so we can
                // use recordLimit=20 to get recent messages without fetching the
                // entire transcript (which could be thousands of entries).
                HttpRequest req = new HttpRequest();
                req.setMethod('GET');
                
                // Use Named Credential for authentication (replaces session ID)
                // Named Credential handles OAuth authentication automatically
                String endpoint = 'callout:WhatsAppConnectAPI/'
                    + conversationIdentifier
                    + '/entries?queryDirection=FromEnd&recordLimit=20';
                
                req.setEndpoint(endpoint);
                
                // Timeout set to 10 s — flows allow up to 120 s per callout.
                req.setTimeout(10000);

                Http http     = new Http();
                HttpResponse res = http.send(req);

                // ── Step 3: Handle HTTP errors ────────────────────────────────
                if (res.getStatusCode() != 200) {
                    output.hasError    = true;
                    output.errorMessage = 'Connect API returned HTTP '
                                        + res.getStatusCode()
                                        + ': ' + res.getBody();
                    outputs.add(output);
                    continue;
                }

                // ── Step 4: Parse JSON response ───────────────────────────────
                // Response shape:
                // {
                //   "conversationEntries": [
                //     {
                //       "messageText"          : "Hello, I am at 19.123, 72.456",
                //       "clientTimestamp"      : 1700000000000,
                //       "serverReceivedTimestamp": 1700000001000,
                //       "sender": {
                //         "role"   : "EndUser",   // "EndUser" | "Agent" | "Chatbot"
                //         "subject": "+919876543210",
                //         "appType": "custom"
                //       },
                //       "entryType": "Message",
                //       "identifier": "uuid-string"
                //     },
                //     ...
                //   ]
                // }
                Map<String, Object> body =
                    (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

                List<Object> entries =
                    (List<Object>) body.get('conversationEntries');

                if (entries == null || entries.isEmpty()) {
                    output.hasError    = true;
                    output.errorMessage = 'No conversation entries found for identifier: '
                                        + conversationIdentifier;
                    outputs.add(output);
                    continue;
                }

                // ── Step 5: Build transcript of all messages ──────────────────
                // Collect all Message entries from the conversation and format
                // as a readable transcript with sender info and timestamps.
                List<String> transcriptLines = new List<String>();
                String endUserPhone = null;
                
                System.debug('Total entries in response: ' + entries.size());

                for (Object rawEntry : entries) {
                    Map<String, Object> entry =
                        (Map<String, Object>) rawEntry;

                    Map<String, Object> sender =
                        (Map<String, Object>) entry.get('sender');
                    String messageText = (String) entry.get('messageText');
                    
                    // Skip entries without a message
                    if (String.isBlank(messageText)) {
                        continue;
                    }

                    String role = 'Unknown';
                    if (sender != null) {
                        String senderRole = (String) sender.get('role');
                        if (senderRole != null) {
                            role = senderRole;
                        }
                    }
                    
                    // Capture phone from first EndUser entry
                    if (endUserPhone == null && role == 'EndUser' && sender != null) {
                        endUserPhone = (String) sender.get('subject');
                    }
                    
                    System.debug('Sender Role: ' + role + ', Message: ' + messageText);
                    
                    String senderName = 'Unknown';
                    if (sender != null) {
                        String subject = (String) sender.get('subject');
                        if (subject != null) {
                            senderName = subject;
                        }
                    }

                    // Format: [ROLE | Timestamp] Message
                    Long ts = (Long) entry.get('serverReceivedTimestamp');
                    String timestamp = ts != null ? 
                        Datetime.newInstance(ts).format('yyyy-MM-dd HH:mm:ss') : 'N/A';
                    
                    String line = '[' + role + ' | ' + timestamp + '] '
                                + senderName + ': ' + messageText.trim();
                    transcriptLines.add(line);
                }

                // Set phone number if found
                if (String.isNotBlank(endUserPhone)) {
                    output.senderPhone = endUserPhone;
                }

                if (transcriptLines.isEmpty()) {
                    output.hasError    = true;
                    output.errorMessage = 'No conversation messages found in the '
                                        + 'last 20 entries for session: '
                                        + input.messagingSessionId;
                } else {
                    String transcript = '';
                    for (String line : transcriptLines) {
                        if (String.isBlank(transcript)) {
                            transcript = line;
                        } else {
                            transcript += '\n' + line;
                        }
                    }
                    output.messageText = transcript;
                }

            } catch (QueryException qe) {
                output.hasError    = true;
                output.errorMessage = 'SOQL error — MessagingSession not found or '
                                    + 'missing ConversationIdentifier: ' + qe.getMessage();
            } catch (CalloutException ce) {
                output.hasError    = true;
                output.errorMessage = 'Callout failed: ' + ce.getMessage()
                                    + '. Ensure the user session is valid and org has API enabled.';
            } catch (Exception e) {
                output.hasError    = true;
                output.errorMessage = 'Unexpected error [' + e.getTypeName() + ']: '
                                    + e.getMessage();
            }

            outputs.add(output);
        }

        return outputs;
    }
}