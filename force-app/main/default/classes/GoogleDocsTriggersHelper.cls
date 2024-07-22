public with sharing class GoogleDocsTriggersHelper {
    public class GoogleDocsException extends Exception {}
    public class InvalidQueryException extends Exception {}
    public class MisconfigurationException extends Exception {}

    /**
     * Deletes documents from Google Drive.
     * @param docsUrls List of document urls to delete.
     * 
     * @author Danyil Mahalias
     */
    @future(callout=true)
    public static void deleteDocuments(String[] docsUrls) {
        try {
            GoogleDocsApiHandler.deleteFile(docsUrls);
        }
        catch (Exception e) {
            throw new GoogleDocsException(e.getMessage());
        }
    }

    /**
     * Uploads files to Google Drive.
     * @param docIds Ids of documents to upload.
     * 
     * @author Danyil Mahalias
     */
    @future(callout=true)
    public static void uploadFiles(String[] docIds) {
        Simploud__Controlled_Document__c[] docs = [SELECT Id, Simploud__Status__c 
                                                    FROM Simploud__Controlled_Document__c 
                                                    WHERE Id IN :docIds 
                                                    WITH SECURITY_ENFORCED];

        Set<String> filteredIds = new Set<String>(docIds);

        for (Simploud__Controlled_Document__c doc : docs) {
            //if (!isCollaborationEnabled('Simploud__Controlled_Document__c', doc.Simploud__Status__c)) {
                //filteredIds.remove(String.valueOf(doc.Id));
            //}
        }

        Id[] filteredIdsAsIds = new Id[]{};

        for (String id : filteredIds) {
            filteredIdsAsIds.add(id);
        }

        try {
            GoogleDocsApiHandler.uploadFile(filteredIdsAsIds);
        }
        catch (Exception e) {
            // there is nothing to do here
        }
    }

    /**
     * Saves minor version of the document.
     * @param docIdStatus Map of document Ids and their statuses.
     * 
     * @author Danyil Mahalias
     */
    @future(callout=true)
    public static void saveMinorVersion(Map<Id, String> docIdStatus) {
        Simploud__Controlled_Document__c[] docs = [SELECT Id, Simploud__Status__c, Simploud__Button_Clicked__c 
                                                FROM Simploud__Controlled_Document__c 
                                                WHERE Id IN :docIdStatus.keySet()
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
                continue;
            }

            if (config == null) continue;
            if (!isCollaborationEnabled('Simploud__Controlled_Document__c', doc.Simploud__Status__c)) continue;

            GoogleDocsApiHandler.saveDocument(new Id[] { doc.Id });
        }
    }

    /**
     * Calculates and updates permissions for the documents.
     * @param docIds Ids of documents to update permissions for.
     * 
     * @author Danyil Mahalias
     */
    @future(callout=true)
    public static void updatePermissions(Id[] docIds) {
        Simploud__Controlled_Document__c[] docs = [SELECT Id, Simploud__Status__c, Simploud__Button_Clicked__c, OwnerId, Use_Document_Collaboration_Tool__c, OneDrive_Permission__c,
                                                        (SELECT Id, Simploud__Participant__c, Simploud__Participant_Type__c, Viewonly__c FROM Simploud__Document_Participants__r)
                                                    FROM Simploud__Controlled_Document__c 
                                                    WHERE Id IN :docIds 
                                                    // AND Use_Document_Collaboration_Tool__c = 'Yes'
                                                    WITH SECURITY_ENFORCED];

        Simploud__Compliance_Configuration__c[] configs = [SELECT Id, Simploud__Enable_Collaboration__c, Simploud__On_Status_Value__c, Simploud__Required_Participants__c, Simploud__Upload_Buttons__c
                                                            FROM Simploud__Compliance_Configuration__c 
                                                            WHERE Simploud__Flow_Type__c = 'Status Changing' 
                                                                AND Simploud__Object_API_Name__c = 'Simploud__Controlled_Document__c' 
                                                                WITH SECURITY_ENFORCED];

        User[] fileAdmins = [SELECT Id, Email FROM User WHERE File_Admin__c = True];

        if (docs == null) throw new InvalidQueryException('Document not found');
        if (configs == null) throw new MisconfigurationException('Compliance configuration not found');

        Map<Id, Map<GoogleDocsPermissionApiHandler.PermissionType, Set<Id>>> accessTypeForPartcipantsForDoc = new Map<Id, Map<GoogleDocsPermissionApiHandler.PermissionType, Set<Id>>>(); // documentId => GoogleDocsPermissionApiHandler.PermissionType => participantsIds

        for (Simploud__Controlled_Document__c doc : docs) {
            // if (doc.Use_Document_Collaboration_Tool__c != 'Yes') continue; // skip if collaboration is disabled for the document

            GoogleDocsPermissionApiHandler.deleteAllPermissions(doc.Id); // delete all permissions for the document

            accessTypeForPartcipantsForDoc.put(doc.Id, getAccessTypeForPartcipants(doc, configs)); // (0)
        }

        Map<Id, String> toUpdate = new Map<Id, String>(); // documentId => new Google_Docs_Permissions__c value

        for (Id docId : accessTypeForPartcipantsForDoc.keySet()) {
            for (GoogleDocsPermissionApiHandler.PermissionType permission : accessTypeForPartcipantsForDoc.get(docId).keySet()) {
                if (accessTypeForPartcipantsForDoc.get(docId).get(permission).size() == 0) continue; // skip if no participants for the permission type

                for (Id userId : accessTypeForPartcipantsForDoc.get(docId).get(permission)) {
                    try {
                        if (toUpdate.get(docId) == null) {
                            toUpdate.put(docId, GoogleDocsPermissionApiHandler.updatePermissionsForUser(docId, userId, permission));
                        }
                        else {
                            String currentPermissions = toUpdate.get(docId);
                            String updatedPermissions = GoogleDocsPermissionApiHandler.updatePermissionsForUser(docId, userId, permission);

                            if (!currentPermissions.contains(updatedPermissions)) {
                                toUpdate.put(docId, currentPermissions + updatedPermissions);
                            }
                        }
                    }
                    catch (Exception e) {
                        throw new GoogleDocsException(e.getMessage());
                    }
                }
            }
        }

        if (toUpdate.size() > 0) {
            Simploud__Controlled_Document__c[] docsToUpdate = [SELECT Id, Google_Docs_Permissions__c 
                                                                FROM Simploud__Controlled_Document__c 
                                                                WHERE Id IN :toUpdate.keySet() 
                                                                WITH SECURITY_ENFORCED];

            for (Simploud__Controlled_Document__c doc : docsToUpdate) {
                doc.Google_Docs_Permissions__c = toUpdate.get(doc.Id);
            }

            update docsToUpdate;
        }
    }

    /**
    *   Returns access type for the participants of the document
    *   @param document Document to get access type for
    *   @param configs Compliance configurations to get access type from
    *   @returns Map<GoogleDocsPermissionApiHandler.PermissionType, Set<Id>> -- access type => user ids (participants)
    *   @throws InvalidQueryException if no participants found
    *   @author Danyil Mahalias
    */
    public static Map<GoogleDocsPermissionApiHandler.PermissionType, Set<Id>> getAccessTypeForPartcipants(Simploud__Controlled_Document__c document, Simploud__Compliance_Configuration__c[] configs) {
        // the result will be stored here. then in the udatePermissions method 3 callouts will be performed:
        // 1. delete all permissions
        // 2. add permissions for editors (list of user Ids from result.get(GoogleDocsPermissionApiHandler.PermissionType.COMMENT))
        // 3. add permissions for readers (list of user Ids from result.get(GoogleDocsPermissionApiHandler.PermissionType.VIEW))
        Map<GoogleDocsPermissionApiHandler.PermissionType, Set<Id>> result = new Map<GoogleDocsPermissionApiHandler.PermissionType, Set<Id>> { // GoogleDocsPermissionApiHandler.PermissionType => Simploud__Participant__c
            GoogleDocsPermissionApiHandler.PermissionType.NOACCESS => new Set<Id>(),
            GoogleDocsPermissionApiHandler.PermissionType.VIEW => new Set<Id>(),
            GoogleDocsPermissionApiHandler.PermissionType.COMMENT => new Set<Id>(),
            GoogleDocsPermissionApiHandler.PermissionType.EDIT => new Set<Id>()
        };

        // group participants by type
        // e.g.
        // 'Reviewer' => [Id1, Id2, Id3]
        // 'Approver' => [Id4, Id5]
        Map<String, Id[]> participantsByType = groupParticipantsByType(document);

        String buttonClickedValue;

        if (document.Simploud__Button_Clicked__c != null && document.Simploud__Button_Clicked__c != '') {
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
                result.get(GoogleDocsPermissionApiHandler.PermissionType.COMMENT).addAll(participantsForCurrentStatus); 
            }

            // if current configuration from the loop is related to any other status of the document
            // then add participants to the result
            else {
                result.get(GoogleDocsPermissionApiHandler.PermissionType.VIEW).addAll(participantsForCurrentStatus);
            }
        }

        // for those who clicked the button -- remove from edit and add to VIEW
        for (Id editParticipantId : result.get(GoogleDocsPermissionApiHandler.PermissionType.COMMENT)) {
            if (editParticipantId == buttonClickedValue) {
                result.get(GoogleDocsPermissionApiHandler.PermissionType.COMMENT).remove(editParticipantId);
                result.get(GoogleDocsPermissionApiHandler.PermissionType.VIEW).add(editParticipantId);
            }
        }

        // for those who are viewonly -- remove from edit and add to VIEW
        for (Simploud__Document_Participant__c participant : document.Simploud__Document_Participants__r) {
            if (participant.Viewonly__c == true) {
                result.get(GoogleDocsPermissionApiHandler.PermissionType.VIEW).add(participant.Simploud__Participant__c);
                result.get(GoogleDocsPermissionApiHandler.PermissionType.COMMENT).remove(participant.Simploud__Participant__c);
            }
        }

        // owner is always editor
        result.get(GoogleDocsPermissionApiHandler.PermissionType.EDIT).add(document.OwnerId);

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
     * Updates Viewonly__c field for the participants of the document.
     * @param docIds Ids of documents to update permissions for.
     * 
     * @author Danyil Mahalias
     */
    public static void updateViewonly(Id[] docIds) {
        Simploud__Controlled_Document__c[] docs = [SELECT Id, Simploud__Button_Clicked__c, 
                                                        (SELECT Id, Simploud__Participant__c, Viewonly__c FROM Simploud__Document_Participants__r) 
                                                    FROM Simploud__Controlled_Document__c 
                                                    WHERE Id IN :docIds 
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
     * Clears Viewonly__c field for the participants of the document.
     * @param docIds Ids of documents to update permissions for.
     * 
     * @author Danyil Mahalias
     */
    public static void clearViewonly(Id[] docIds) {
        Simploud__Controlled_Document__c[] docs = [SELECT Id, Simploud__Button_Clicked__c, 
                                                        (SELECT Id, Simploud__Participant__c, Viewonly__c FROM Simploud__Document_Participants__r) 
                                                    FROM Simploud__Controlled_Document__c 
                                                    WHERE Id IN :docIds 
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


    /**
    *    Returns true if collaboration is enabled for the object and status
    *    @param sObjectName Name of the object
    *    @param status Status of the object
    *    @returns Boolean -- true if collaboration is enabled for the object and status, false otherwise
    * 
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
}