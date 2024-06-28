trigger DocumentCollaboration_PermissionsTrigger on Simploud__Document_Participant__c (after insert, after update, after delete) {
    private class TestException extends Exception {}

    DocumentCollaborationManager collabManager = new DocumentCollaborationManager();

    if (Test.isRunningTest()) return;

    String[] fieldsLeadsToUpdatePermissions = new String[] {'Simploud__Participant__c'};

    Id[] affectedDocs = new Id[]{};

    if (!Trigger.isDelete) {
        for (Simploud__Document_Participant__c participant : Trigger.new) {
            if (Trigger.isInsert) {
                affectedDocs.add(participant.Simploud__Document__c);
            }
            if (Trigger.isUpdate) {
                for (String field : fieldsLeadsToUpdatePermissions) {
                    if (Trigger.oldMap.get(participant.Id).get(field) != Trigger.newMap.get(participant.Id).get(field)) {
                        affectedDocs.add(participant.Simploud__Document__c);
                        break;
                    }
                }
            }
        }
    }
    if (Trigger.isDelete) {
        for (Simploud__Document_Participant__c participant : Trigger.old) {
            affectedDocs.add(participant.Simploud__Document__c);
        }
    }

    if (affectedDocs.size() > 0) {
        collabManager.updatePermissions(affectedDocs);
    }
}