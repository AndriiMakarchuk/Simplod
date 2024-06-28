trigger DocumentCollaboration_DocumentTrigger on Simploud__Controlled_Document__c (after insert, after update, before delete) {

    DocumentCollaborationManager collabManager = new DocumentCollaborationManager();

    if (Test.isRunningTest()) return;

    // if any of these fields are updated, we need to update permissions
    String[] fieldsLeadsToUpdatePermissions = new String[]{'Simploud__Status__c', 'Simploud__Button_Clicked__c', 'OwnerId'};

    // if any of these fields are updated, we need to save a minor version
    String[] fieldsLeadsToSaveMinorVersion = new String[]{'Simploud__Button_Clicked__c'};

    // when going to these statuses files should be deleted
    Simploud__SimploudOrgSettings__c settings = Simploud__SimploudOrgSettings__c.getOrgDefaults();
    String[] nonCollaborativeStatuses = settings.Delete_File_In_Cloud__c != '' ? settings.Delete_File_In_Cloud__c.split(',') : new String[]{};

    String[] toUpload = new String[]{};
    Set<Id> toUpdateAccess = new Set<Id>();
    Map<Id, String> toSaveMinorVersion = new Map<Id, String>(); // Id => status
    Id[] toUpdateViewonly = new Id[]{};
    Id[] toClearViewonly = new Id[]{};
    String[] toDelete = new String[]{};

    // if (Trigger.isInsert) {
    //     for (Simploud__Controlled_Document__c doc : trigger.new) {
    //         if (doc.Use_Document_Collaboration_Tool__c == 'Yes' && doc.File_In_Cloud__c == false) {
    //             toUpload.add(String.valueOf(doc.Id));
    //         }
    //     }
    // } 

    if (Trigger.isInsert || Trigger.isUpdate) {
        for (Simploud__Controlled_Document__c doc : Trigger.new) {
            
            if (
                (doc.Simploud__File_Exist__c == true || (trigger.oldMap == null || trigger.oldMap.get(doc.Id) == null || trigger.oldMap.get(doc.Id).Simploud__File_Exist__c == false))
                && doc.File_In_Cloud__c == false
                // && doc.Use_Document_Collaboration_Tool__c == 'Yes'
                && !nonCollaborativeStatuses.contains(doc.Simploud__Status__c)
                || (trigger.oldMap != null && trigger.oldMap.get(doc.Id) != null 
                    && (((nonCollaborativeStatuses.contains(trigger.oldMap.get(doc.Id).Simploud__Status__c) && !nonCollaborativeStatuses.contains(doc.Simploud__Status__c))
                    && doc.File_In_Cloud__c == false
                    // && doc.Use_Document_Collaboration_Tool__c == 'Yes'
                    )))) {
                        System.debug('Add to Upload ' + doc.id);
                toUpload.add(String.valueOf(doc.Id));
            }
        }
        
        if (Trigger.isUpdate && Trigger.isAfter && Trigger.old != null) {
            for (Simploud__Controlled_Document__c doc : trigger.new) {
                for (String field : fieldsLeadsToUpdatePermissions) {
                    if (doc.get(field) != trigger.oldMap.get(doc.Id).get(field)
                        // && doc.Use_Document_Collaboration_Tool__c == 'Yes'
                        && ((doc.OneDrive_URL__c != null && doc.OneDrive_URL__c != ''
                            && doc.OneDrive_Permission__c != null && doc.OneDrive_Permission__c != '' && collabManager.collaborationToolName == 'SharePoint')
                            || (doc.Google_Docs_Url__c != null && doc.Google_Docs_Url__c != '' && collabManager.collaborationToolName == 'Google'))) {
                        toUpdateAccess.add(doc.Id);
                        break;
                    }
                }
            }
        }

        if (Trigger.isUpdate && Trigger.isBefore && Trigger.old != null) {
            for (Simploud__Controlled_Document__c doc : trigger.new) {
                for (String field : fieldsLeadsToSaveMinorVersion) {
                    if (doc.get(field) != trigger.oldMap.get(doc.Id).get(field)
                        // && doc.Use_Document_Collaboration_Tool__c == 'Yes'
                        && ((doc.OneDrive_URL__c != null && doc.OneDrive_URL__c != '' && doc.OneDrive_Permission__c != null && doc.OneDrive_Permission__c != '' && collabManager.collaborationToolName == 'SharePoint')
                            ||  (doc.Google_Docs_Url__c != null && doc.Google_Docs_Url__c != '' && collabManager.collaborationToolName == 'Google'))) {
                        toSaveMinorVersion.put(doc.Id, Trigger.oldMap.get(doc.Id).Simploud__Status__c);
                        break;
                    }
                }

                if (doc.Simploud__Status__c == trigger.oldMap.get(doc.Id).Simploud__Status__c && doc.Simploud__Button_Clicked__c != trigger.oldMap.get(doc.Id).Simploud__Button_Clicked__c
                    // && doc.Use_Document_Collaboration_Tool__c == 'Yes'
                    && ((doc.OneDrive_URL__c != null && doc.OneDrive_URL__c != ''
                            && doc.OneDrive_Permission__c != null && doc.OneDrive_Permission__c != '' && collabManager.collaborationToolName == 'SharePoint')
                            || (doc.Google_Docs_Url__c != null && doc.Google_Docs_Url__c != '' && collabManager.collaborationToolName == 'Google'))) {
                    toUpdateViewonly.add(doc.Id);
                }

                if (doc.Simploud__Status__c != trigger.oldMap.get(doc.Id).Simploud__Status__c
                    // && doc.Use_Document_Collaboration_Tool__c == 'Yes'
                    && ((doc.OneDrive_URL__c != null && doc.OneDrive_URL__c != ''
                            && doc.OneDrive_Permission__c != null && doc.OneDrive_Permission__c != '' && collabManager.collaborationToolName == 'SharePoint')
                            || (doc.Google_Docs_Url__c != null && doc.Google_Docs_Url__c != '' && collabManager.collaborationToolName == 'Google'))) {
                    toClearViewonly.add(doc.Id);
                }
            }

            for (Simploud__Controlled_Document__c doc : Trigger.new) {
                if (nonCollaborativeStatuses.contains(doc.Simploud__Status__c)
                    && ((doc.OneDrive_URL__c != null && doc.OneDrive_URL__c != '' && collabManager.collaborationToolName == 'SharePoint') || (doc.Google_Docs_Url__c != null && doc.Google_Docs_Url__c != '' && collabManager.collaborationToolName == 'Google'))) {
                    toDelete.add(doc.Google_Docs_URL__c);
                    
                    if (toUpload.indexOf(String.valueOf(doc.Id)) > -1) toUpload.remove(toUpload.indexOf(String.valueOf(doc.Id)));
                    toUpdateAccess.remove(doc.Id);
                    toSaveMinorVersion.remove(doc.Id);
                    if (toUpdateViewonly.indexOf(doc.Id) > -1) toUpdateViewonly.remove(toUpdateViewonly.indexOf(doc.Id));
                    if (toClearViewonly.indexOf(doc.Id) > -1) toClearViewonly.remove(toClearViewonly.indexOf(doc.Id));
                }
            }
        }
    }

    else if (trigger.isDelete) {
        for (Simploud__Controlled_Document__c doc : trigger.old) {
            if (((doc.OneDrive_URL__c != null && doc.OneDrive_URL__c != '' && collabManager.collaborationToolName == 'SharePoint') || (doc.Google_Docs_Url__c != null && doc.Google_Docs_Url__c != '' && collabManager.collaborationToolName == 'Google'))
                // && doc.Use_Document_Collaboration_Tool__c == 'Yes'
                ) {
                toDelete.add(doc.Google_Docs_URL__c);

                if (toUpload.indexOf(String.valueOf(doc.Id)) > -1) toUpload.remove(toUpload.indexOf(String.valueOf(doc.Id)));
                toUpdateAccess.remove(doc.Id);
                toSaveMinorVersion.remove(doc.Id);
                if (toUpdateViewonly.indexOf(doc.Id) > -1) toUpdateViewonly.remove(toUpdateViewonly.indexOf(doc.Id));
                if (toClearViewonly.indexOf(doc.Id) > -1) toClearViewonly.remove(toClearViewonly.indexOf(doc.Id));
            }
        }
    }

    if (toDelete.size() > 0) {
        collabManager.deleteDocuments(toDelete);
    }

    if (toUpload.size() > 0) {
        collabManager.uploadFiles(toUpload);
    }

    if (toUpdateAccess.size() > 0) {
        collabManager.updatePermissions(new List<Id>(toUpdateAccess));
    }

    if (toSaveMinorVersion.size() > 0) {
        collabManager.saveMinorVersion(toSaveMinorVersion);
    }

    if (toUpdateViewonly.size() > 0) {
        collabManager.updateViewonly(toUpdateViewonly);
    }

    if (toClearViewonly.size() > 0) {
        collabManager.clearViewonly(toClearViewonly);
    }
}