trigger UserEmailTrigger on UserChangeEvent (after insert) {
    // 0. Get the old and new values for comparison
    // if email changed:
    // 1. find document participants associated with the user
    // 2. find documents associated with the participants
    // 3. update permissions

    DocumentCollaborationManager collabManager = new DocumentCollaborationManager();

    Id[] whereEmailChanged = new Id[]{}; // list of user Ids where email changed
    Map<Id, Simploud__Document_Participant__c[]> affectedParticipants = new Map<Id, Simploud__Document_Participant__c[]>(); // map (userId => document participants) of document participants affected by email change
    Id[] affectedDocumentsIds = new Id[]{}; // map (userId => controlled documents (ids)) of controlled documents affected by email change

    // 0:
    for (UserChangeEvent event : Trigger.new) {
        EventBus.ChangeEventHeader header = event.ChangeEventHeader;
        if (header == null) continue;
        if (!header.changedFields.contains('Email')) continue;
        whereEmailChanged.addAll(header.recordIds);
    }

    if (whereEmailChanged.size() == 0) return;

    // if the user if File_Admin__c == True, all docs are affected
    User[] users = [SELECT Id, File_Admin__c FROM User WHERE Id IN :whereEmailChanged];

    Simploud__Controlled_Document__c[] docs = [SELECT Id FROM Simploud__Controlled_Document__c 
                                                WHERE 
                                                    (Simploud__Is_Closed__c = False 
                                                    AND Simploud__Is_Locked__c = False 
                                                    AND Use_Document_Collaboration_Tool__c = 'Yes')
                                                WITH SECURITY_ENFORCED
                                                ORDER BY CreatedDate DESC NULLS LAST
                                                LIMIT 10];
    for (User user : users) {
        if (user.File_Admin__c) {
            for (Simploud__Controlled_Document__c doc : docs) {
                affectedDocumentsIds.add(doc.Id);
            }
        }
    }

    // 1:
    for (Simploud__Document_Participant__c participant : [SELECT Id, Simploud__Participant__c, Simploud__Document__c FROM Simploud__Document_Participant__c WHERE Simploud__Participant__c IN :whereEmailChanged WITH SECURITY_ENFORCED]) {
        if (affectedParticipants.get(participant.Id) == null) {
            affectedParticipants.put(participant.Id, new Simploud__Document_Participant__c[]{participant});
        } 
        else {
            affectedParticipants.get(participant.Id).add(participant);
        }
    }

    // 2:
    for (Simploud__Document_Participant__c[] participants : affectedParticipants.values()) {
        for (Simploud__Document_Participant__c participant : participants) {
            affectedDocumentsIds.add(participant.Simploud__Document__c);
        }
    }

    if (affectedDocumentsIds.size() == 0) return;

    // 3: 
    try {
        // try to assign permission set to the automated process user
        // if it fails, it means that the permission set is already assigned
        insert new PermissionSetAssignment(
            AssigneeId = [SELECT Id FROM User WHERE alias = 'autoproc'].Id,
            PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'sharepoint_integration_access' LIMIT 1].Id
        );
    }
    catch (Exception e) {
        // do nothing
    }
    finally {
        Set<Id> affectedDocumentsIdsSet = new Set<Id>(affectedDocumentsIds);
        affectedDocumentsIds = new Id[]{};

        for (Id affectedDocumentId : affectedDocumentsIdsSet) {
            affectedDocumentsIds.add(affectedDocumentId);
        }

        collabManager.updatePermissions(affectedDocumentsIds);
    }
}