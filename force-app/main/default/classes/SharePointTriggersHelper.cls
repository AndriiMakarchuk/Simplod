public with sharing class SharePointTriggersHelper {
    public class RequiredPartcipantIsFieldException extends Exception {}
    public class MisconfigurationException extends Exception {}
    public class InvalidQueryException extends Exception {}

    public enum AccessType {
        EDIT,
        REVIEW,
        READ,
        NOACCESS
    }

    public static Map<AccessType, String> accessTypeToPermission = new Map<AccessType, String> {
        AccessType.NOACCESS => 'none',
        AccessType.READ => 'read',
        AccessType.REVIEW => 'review',
        AccessType.EDIT => 'write'
    }; // accessType => permission

    @future(callout=true)
    public static void uploadFiles(String[] ids) {
        if (system.isFuture() || system.isBatch()) return;

        Simploud__Controlled_Document__c[] docs = [SELECT Id, Simploud__Status__c 
                                                    FROM Simploud__Controlled_Document__c 
                                                    WHERE Id IN :ids 
                                                    WITH SECURITY_ENFORCED];

        Set<String> filteredIds = new Set<String>(ids);

        for (Simploud__Controlled_Document__c doc : docs) {
            if (!isCollaborationEnabled('Simploud__Controlled_Document__c', doc.Simploud__Status__c)) {
                filteredIds.remove(String.valueOf(doc.Id));
            }
        }

        try {
            SharePointApiHandler.uploadDocuments(new List<String>(filteredIds));
        }
        catch (Exception e) {
            handleException(e);
        }
    }

    @future(callout=true)
    public static void deleteDocuments(Id[] docIds) {
        try {
            SharePointApiHandler.deleteDocuments(docIds);
        }
        catch (Exception e) {
            handleException(e);
        }
    }

    /** 
    *    The main method of the class. It is called when a document is created or updated, participant is created or updated, etc. Calculates and gives access to the document for the participants
    *    @param controlledDocumentsIds Ids of the documents to update permissions for
    *    @returns void
    *    @throws InvalidQueryException if no documents found
    *    @throws MisconfigurationException if no compliance configuration found
    *    @author Danyil Mahalias
    */
    @future(callout=true)
    public static void updatePermissions(Id[] controlledDocumentsIds) {
        // 0: get participants/users grouped by access type
        // 1: remove all permissions from the document
        // 2: give permissions to the document for the participants
        // with such a flow we can always keep the permissions up to date
        // method's logic isn't related to any particular situation within the doc/org
        // this method can be called whenever document permissions need to be updated

        Simploud__Controlled_Document__c[] docs = [SELECT Id, Simploud__Status__c, Simploud__Button_Clicked__c, OwnerId, Use_Document_Collaboration_Tool__c, OneDrive_Permission__c,
                                                        (SELECT Id, Simploud__Participant__c, Simploud__Participant_Type__c, Viewonly__c FROM Simploud__Document_Participants__r)
                                                    FROM Simploud__Controlled_Document__c 
                                                    WHERE Id IN :controlledDocumentsIds 
                                                    AND Use_Document_Collaboration_Tool__c = 'Yes'
                                                    WITH SECURITY_ENFORCED];

        Simploud__Compliance_Configuration__c[] configs = [SELECT Id, Simploud__Enable_Collaboration__c, Simploud__On_Status_Value__c, Simploud__Required_Participants__c, Simploud__Upload_Buttons__c
                                                            FROM Simploud__Compliance_Configuration__c 
                                                            WHERE Simploud__Flow_Type__c = 'Status Changing' 
                                                                AND Simploud__Object_API_Name__c = 'Simploud__Controlled_Document__c' 
                                                                WITH SECURITY_ENFORCED];

        User[] fileAdmins = [SELECT Id, Email FROM User WHERE File_Admin__c = True];

        if (docs == null) throw new InvalidQueryException('Document not found');
        if (configs == null) throw new MisconfigurationException('Compliance configuration not found');

        Map<Id, Map<AccessType, Set<Id>>> accessTypeForPartcipantsForDoc = new Map<Id, Map<AccessType, Set<Id>>>(); // documentId => accessType => participantsIds

        for (Simploud__Controlled_Document__c doc : docs) {
            if (doc.Use_Document_Collaboration_Tool__c != 'Yes') continue; // skip if collaboration is disabled for the document

            accessTypeForPartcipantsForDoc.put(doc.Id, getAccessTypeForPartcipants(doc, configs)); // (0)
        }

        Id[] toDeletePermissions = new Id[]{};
        for (Simploud__Controlled_Document__c doc : docs) {
            if (doc.OneDrive_Permission__c != null && doc.OneDrive_Permission__c != '')
            toDeletePermissions.add(doc.Id);
        }
        SharePointPermissionsApiHandler.DeletePermissions(toDeletePermissions); // (1)

        for (Id docId : accessTypeForPartcipantsForDoc.keySet()) {
            for (AccessType accessType : accessTypeForPartcipantsForDoc.get(docId).keySet()) {
                if (accessTypeToPermission.get(accessType) == 'none') continue; // users that should have no access to the document just won't be processed

                String[] userIds = new String[]{};

                for (Id userId : accessTypeForPartcipantsForDoc.get(docId).get(accessType)) {
                    userIds.add(userId);
                }

                if (userIds.size() == 0) continue;

                User[] users = [SELECT Id, Email FROM User WHERE Id IN :userIds];

                String accessLabel = accessTypeToPermission.get(accessType);
                
                if (docId != null && users != null && users.size() > 0 && accessLabel != null)
                SharePointPermissionsApiHandler.addPermissionToUsers(docId, users, accessLabel); // (2)
            }
        }

        if (fileAdmins.size() > 0) {
            for (Id docId : controlledDocumentsIds) {
                SharePointPermissionsApiHandler.addPermissionToUsers(docId, fileAdmins, 'write'); // give access to file admins
            }
        }

        SharePointPermissionsApiHandler.ViewPermissions(controlledDocumentsIds); // update links, permission ids, etc.
    }

    /**
    *    Returns true if collaboration is enabled for the object and status
    *    @param sObjectName Name of the object
    *    @param status Status of the object
    *    @returns Boolean -- true if collaboration is enabled for the object and status, false otherwise
    *    @author Danyil Mahalias
    */
    public static boolean isCollaborationEnabled(String sObjectName, String status) {
        Simploud__Compliance_Configuration__c config = [SELECT Id, Simploud__Enable_Collaboration__c 
                                                        FROM Simploud__Compliance_Configuration__c 
                                                        WHERE Simploud__Flow_Type__c = 'Status Changing' 
                                                            AND Simploud__Object_API_Name__c = :sObjectName 
                                                            AND Simploud__On_Status_Value__c = :status
                                                            WITH SECURITY_ENFORCED
                                                            LIMIT 1];

        if (config == null) throw new MisconfigurationException('Compliance configuration not found');

        return config.Simploud__Enable_Collaboration__c;
    }

    /**
    *   Returns access type for the participants of the document
    *   @param document Document to get access type for
    *   @param configs Compliance configurations to get access type from
    *   @returns Map<AccessType, Set<Id>> -- access type => user ids (participants)
    *   @throws InvalidQueryException if no participants found
    *   @author Danyil Mahalias
    */
    public static Map<AccessType, Set<Id>> getAccessTypeForPartcipants(Simploud__Controlled_Document__c document, Simploud__Compliance_Configuration__c[] configs) {
        // the result will be stored here. then in the udatePermissions method 3 callouts will be performed:
        // 1. delete all permissions
        // 2. add permissions for editors (list of user Ids from result.get(AccessType.EDIT))
        // 3. add permissions for readers (list of user Ids from result.get(AccessType.READ))
        Map<AccessType, Set<Id>> result = new Map<AccessType, Set<Id>> { // accessType => Simploud__Participant__c
            AccessType.REVIEW => new Set<Id>(),
            AccessType.NOACCESS => new Set<Id>(),
            AccessType.READ => new Set<Id>(),
            AccessType.EDIT => new Set<Id>()
        };

        // group participants by type
        // e.g.
        // 'Reviewer' => [Id1, Id2, Id3]
        // 'Approver' => [Id4, Id5]
        Map<String, Id[]> participantsByType = groupParticipantsByType(document);

        String buttonClickedValue;

        if (String.isNotBlank(document.Simploud__Button_Clicked__c)) {
            try {
                buttonClickedValue = document.Simploud__Button_Clicked__c.split(':')[2]; // e.g. 'Status' => 'Approve Review:Id1' -> 'Id1'
            }
            catch (Exception e) {
                buttonClickedValue = null;
            }
        }

        for (Simploud__Compliance_Configuration__c config : configs) {
            if (validateConfiguration(config) == false) continue; // skip if configuration is invalid. e.g. if Required Participants is not set, etc.

            String requiredParticipantLabel = config.Simploud__Required_Participants__c.split(':')[0]; // 'Participant' or 'Field'
            String requiredParticipantValue = config.Simploud__Required_Participants__c.split(':')[1]; // 'Reviewer' or 'Simploud__Approver__c'

            Id[] participantsForCurrentStatus = new Id[]{};

            if (requiredParticipantLabel == 'Participant') {
                if (participantsByType.get(requiredParticipantValue) != null) {
                    participantsForCurrentStatus.addAll(participantsByType.get(requiredParticipantValue));
                }
            }
            else if (requiredParticipantLabel == 'Field') {
                if (getParticipantIdByField(document, requiredParticipantValue) != null) { // getParticipantIdByField returns value only if the field is a lookup to User object
                    participantsForCurrentStatus.add(getParticipantIdByField(document, requiredParticipantValue));
                }
            }

            // the main part of the method
            // if current configuration from the loop is related to the current status of the document
            // then add participants to the result
            if (config.Simploud__On_Status_Value__c == document.Simploud__Status__c) {
                result.get(AccessType.EDIT).addAll(participantsForCurrentStatus); 
            }

            // if current configuration from the loop is related to any other status of the document
            // then add participants to the result
            else {
                result.get(AccessType.READ).addAll(participantsForCurrentStatus);
            }
        }

        // for those who clicked the button -- remove from edit and add to read
        for (Id editParticipantId : result.get(AccessType.EDIT)) {
            if (editParticipantId == buttonClickedValue) {
                result.get(AccessType.EDIT).remove(editParticipantId);
                result.get(AccessType.READ).add(editParticipantId);
            }
        }

        // for those who are viewonly -- remove from edit and add to read
        for (Simploud__Document_Participant__c participant : document.Simploud__Document_Participants__r) {
            if (participant.Viewonly__c == true) {
                result.get(AccessType.READ).add(participant.Simploud__Participant__c);
                result.get(AccessType.EDIT).remove(participant.Simploud__Participant__c);
            }
        }

        // owner is always editor
        result.get(AccessType.EDIT).add(document.OwnerId);

        return result;
    }

    /**
    *   Returns user id by field defined in Simploud__Required_Participants__c with type Field
    *   @param document Document to get user id from
    *   @param field Field to get user id from
    *   @returns Id -- user id
    *   @author Danyil Mahalias
    */
    public static Id getParticipantIdByField(Simploud__Controlled_Document__c document, String field) {
        String query = 'SELECT ' 
                        + 'Id, ' + field + ' '
                        + 'FROM Simploud__Controlled_Document__c '
                        + 'WHERE Id = \'' + document.Id + '\'';
        
        Simploud__Controlled_Document__c docWithRequiredFields = Database.query(query);
        String value = String.valueOf(docWithRequiredFields.get(field));
        Id idValue;

        try {
            idValue = Id.valueOf(value);
        }
        catch (Exception e) {
            return null; // field isn't a lookup
        }

        if (idValue.getSObjectType().getDescribe().getName() == 'User') {
            return idValue;
        }
        else {
            return null; // field isn't a lookup to the User object
        }
    }

    /**
    *   Builds a Map of participants grouped by type
    *   @param document Document to get participants from
    *   @returns Map<String, Simploud__Document_Participant__c> -- participantType => participants
    *   @author Danyil Mahalias
    */
    public static Map<String, Id[]> groupParticipantsByType(Simploud__Controlled_Document__c document) {
        Map<String, Id[]> participantsByType = new Map<String, Id[]>(); // participantType => participants

        if (document.Simploud__Document_Participants__r == null) throw new InvalidQueryException('No participants found');

        for (Simploud__Document_Participant__c participant : document.Simploud__Document_Participants__r) {
            if (!participantsByType.containsKey(participant.Simploud__Participant_Type__c)) {
                participantsByType.put(participant.Simploud__Participant_Type__c, new Id[]{});
            }
            participantsByType.get(participant.Simploud__Participant_Type__c).add(participant.Simploud__Participant__c);
        }

        return participantsByType;
    }

    /**
    *   Validates compliance configuration
    *   @param config Compliance configuration to validate
    *   @returns Boolean -- true if configuration is valid, false otherwise
    *   @author Danyil Mahalias
    */
    public static boolean validateConfiguration(Simploud__Compliance_Configuration__c config) {
        if (config.Simploud__Enable_Collaboration__c == false) return false;
        if (config.Simploud__Required_Participants__c == null || config.Simploud__Required_Participants__c == '') return false;
        if (config.Simploud__Required_Participants__c.split(':').size() != 2) return false;

        return true;
    }

    /**
    *   Downloads a minor version of the document based on Compliance Configuration
    *   @param controlledDocumentId Id of the document
    *   @returns void
    *   @author Danyil Mahalias
    */
    @future(callout=true) // a little workaround
    public static void saveMinorVersion(Map<Id, String> controlledDocumentId) {
        Simploud__Controlled_Document__c[] docs = [SELECT Id, Simploud__Status__c, Simploud__Button_Clicked__c 
                                                FROM Simploud__Controlled_Document__c 
                                                WHERE Id IN :controlledDocumentId.keySet()
                                                WITH SECURITY_ENFORCED];

        if (docs == null) throw new InvalidQueryException('Document not found');

        for (Simploud__Controlled_Document__c doc : docs) {
            if (doc.Simploud__Button_Clicked__c == null || doc.Simploud__Button_Clicked__c == '') continue; // if no button clicked - no minor version created

            String buttonClickedStatus = doc.Simploud__Button_Clicked__c.split(':')[0];
            String buttonClickedLabel = doc.Simploud__Button_Clicked__c.split(':')[1];
            String buttonClickedQueryParam = '%' + buttonClickedLabel + '%';
            Simploud__Compliance_Configuration__c config;

            try {
                config = [SELECT Id, Simploud__Upload_Buttons__c, Simploud__Enable_Collaboration__c
                        FROM Simploud__Compliance_Configuration__c 
                        WHERE Simploud__Flow_Type__c = 'Status Changing' 
                            AND Simploud__Object_API_Name__c = 'Simploud__Controlled_Document__c' 
                            AND Simploud__On_Status_Value__c = :buttonClickedStatus
                            AND Simploud__Upload_Buttons__c LIKE :buttonClickedQueryParam
                            WITH SECURITY_ENFORCED
                            LIMIT 1];
            }
            catch (Exception e) {
                handleException(e);
                continue;
            }

            if (config == null) continue;
            if (!isCollaborationEnabled('Simploud__Controlled_Document__c', controlledDocumentId.get(doc.Id))) continue;

            SharePointApiHandler.getDocuments(doc.Id);
        }
    }

    /**
     * Updates Viewonly__c field on the participant when button is clicked
     * @param docsIds Ids of the documents to update participants for
     * @returns void
     * @author Danyil Mahalias
     */
    public static void updateViewonly(Id[] docsIds) {
        Simploud__Controlled_Document__c[] docs = [SELECT Id, Simploud__Button_Clicked__c, 
                                                        (SELECT Id, Simploud__Participant__c, Viewonly__c FROM Simploud__Document_Participants__r) 
                                                    FROM Simploud__Controlled_Document__c 
                                                    WHERE Id IN :docsIds 
                                                    WITH SECURITY_ENFORCED];

        if (docs == null) return;

        for (Simploud__Controlled_Document__c doc : docs) {
            if (doc.Simploud__Button_Clicked__c == null || doc.Simploud__Button_Clicked__c == '') continue;

            String buttonClickedValue = doc.Simploud__Button_Clicked__c.split(':')[2];

            for (Simploud__Document_Participant__c participant : doc.Simploud__Document_Participants__r) {
                if (participant.Simploud__Participant__c == buttonClickedValue) {
                    participant.Viewonly__c = true;
                }
            }
        } 

        Simploud__Document_Participant__c[] parts = new Simploud__Document_Participant__c[]{};
        
        for (Simploud__Controlled_Document__c doc : docs) {
            parts.addAll(doc.Simploud__Document_Participants__r);
        }

        update parts;
    }

    /**
     * Sets Viewonly__c field on each participant of the document to false
     * @param docsIds Ids of the documents to update participants for
     * @returns void
     * @author Danyil Mahalias
     */
    public static void clearViewonly(Id[] docsIds) {
        Simploud__Controlled_Document__c[] docs = [SELECT Id, Simploud__Button_Clicked__c, 
                                                        (SELECT Id, Simploud__Participant__c, Viewonly__c FROM Simploud__Document_Participants__r) 
                                                    FROM Simploud__Controlled_Document__c 
                                                    WHERE Id IN :docsIds 
                                                    WITH SECURITY_ENFORCED];

        if (docs == null) return;

        for (Simploud__Controlled_Document__c doc : docs) {
            for (Simploud__Document_Participant__c participant : doc.Simploud__Document_Participants__r) {
                participant.Viewonly__c = false;
            }
        }

        Simploud__Document_Participant__c[] parts = new Simploud__Document_Participant__c[]{};
        
        for (Simploud__Controlled_Document__c doc : docs) {
            parts.addAll(doc.Simploud__Document_Participants__r);
        }

        update parts;
    }

    public static void handleException(Exception e) {
        String errorMessage = 'Error occured in org: ' 
                            + UserInfo.getOrganizationId()
                            + ' ( ' + UserInfo.getOrganizationName() + ' ) '    + '\n'
                            + ' with user: ' + UserInfo.getUserId()
                            + ' ( ' + UserInfo.getUserName() + ' ) '            + '\n'
                            + ' --------------------------------------- '       + '\n'
                            + ' Error message: ' + e.getMessage()               + '\n'
                            + ' in class ' + e.getTypeName()                    + '\n'
                            + ' on line: ' + e.getLineNumber()                  + '\n'
                            + ' --------------------------------------- '       + '\n'
                            + ' Stack trace: ' + e.getStackTraceString()        + '\n';

        system.debug(System.LoggingLevel.ERROR, errorMessage);
    }
    
}