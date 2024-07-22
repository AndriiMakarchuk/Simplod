trigger DocumentCollaboration_DocumentTrigger on Simploud__Controlled_Document__c (after insert, before update, after update, after delete) {

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


    if (Trigger.isBefore && Trigger.isUpdate) {
        for (Simploud__Controlled_Document__c doc : Trigger.new) {
            if (doc.Simploud__Checked_Out__c == true && Trigger.oldMap.get(doc.Id).Simploud__Checked_Out__c == false) {
                doc.OneDrive_URL__c = '';
                doc.OneDrive_Permission__c = '';
                doc.OneDrive_Owner_Shared_Link__c = '';
            }
        }
    } 

    if (Trigger.isAfter) {

        if (Trigger.isInsert || Trigger.isUpdate) {
            for (Simploud__Controlled_Document__c doc : Trigger.new) {
                if (
                    ((
                        (Trigger.oldMap != null && Trigger.oldMap.get(doc.Id) != null) &&
                        (
                            Trigger.oldMap.get(doc.Id).Simploud__File_Exist__c == false 
                            || 
                            Trigger.oldMap.get(doc.Id).Simploud__Checked_Out__c == true 
                        )
                    )
                    ||
                    (
                        Trigger.oldMap == null || Trigger.oldMap.get(doc.Id) == null
                    ))
                    && doc.Simploud__Checked_Out__c == false
                    && doc.Simploud__File_Exist__c == true
                    && doc.Simploud__File_In_Cloud__c == false
                    && doc.Use_Document_Collaboration_Tool__c == 'Yes'
                    && !nonCollaborativeStatuses.contains(doc.Simploud__Status__c)
                ) {
                    toUpload.add(String.valueOf(doc.Id));
                }
            }
        }

        if (Trigger.isInsert) {
            // for (Simploud__Controlled_Document__c doc : trigger.new) {
            //     if (doc.Use_Document_Collaboration_Tool__c == 'Yes'
            //         && doc.Simploud__File_In_Cloud__c == false
            //         && doc.Simploud__File_Exist__c == true) 
            //     {
            //         toUpload.add(String.valueOf(doc.Id));
            //     }
            // }
        }

        if (Trigger.isUpdate) {
            for (Simploud__Controlled_Document__c doc : Trigger.new) {
                for (String field : fieldsLeadsToUpdatePermissions) {
                    if (doc.get(field) != Trigger.oldMap.get(doc.Id).get(field)
                        && doc.Use_Document_Collaboration_Tool__c == 'Yes'
                        && collabManager.isCollaborationFieldsGoogleOrSharepointSet(doc)) 
                    {
                        toUpdateAccess.add(doc.Id);
                        break;
                    }
                }

                for (String field : fieldsLeadsToSaveMinorVersion) {
                    if (doc.get(field) != Trigger.oldMap.get(doc.Id).get(field)
                        && doc.Use_Document_Collaboration_Tool__c == 'Yes'
                        && collabManager.isCollaborationFieldsGoogleOrSharepointSet(doc)) 
                    {
                        toSaveMinorVersion.put(doc.Id, Trigger.oldMap.get(doc.Id).Simploud__Status__c);
                        break;
                    }
                }

                if (doc.Simploud__Status__c == trigger.oldMap.get(doc.Id).Simploud__Status__c 
                    && doc.Simploud__Button_Clicked__c != trigger.oldMap.get(doc.Id).Simploud__Button_Clicked__c
                    && doc.Use_Document_Collaboration_Tool__c == 'Yes'
                    && collabManager.isCollaborationFieldsGoogleOrSharepointSet(doc)) 
                {
                    toUpdateViewonly.add(doc.Id);
                }

                if (doc.Simploud__Status__c != trigger.oldMap.get(doc.Id).Simploud__Status__c
                    && doc.Use_Document_Collaboration_Tool__c == 'Yes'
                    && collabManager.isCollaborationFieldsGoogleOrSharepointSet(doc)) 
                {
                    toClearViewonly.add(doc.Id);
                }

                if (nonCollaborativeStatuses.contains(doc.Simploud__Status__c)
                    && (doc.Simploud__Status__c != Trigger.oldMap.get(doc.Id).Simploud__Status__c)
                    && collabManager.isCollaborationFieldsGoogleOrSharepointSet(doc)) 
                {
                    if (collabManager.collaborationToolName == 'SharePoint') {
                        toDelete.add(doc.Id);
                    } else {
                        toDelete.add(doc.Google_Docs_URL__c) ;
                    }
                    
                    if (toUpload.indexOf(String.valueOf(doc.Id)) > -1) toUpload.remove(toUpload.indexOf(String.valueOf(doc.Id)));
                    toUpdateAccess.remove(doc.Id);
                    toSaveMinorVersion.remove(doc.Id);
                    if (toUpdateViewonly.indexOf(doc.Id) > -1) toUpdateViewonly.remove(toUpdateViewonly.indexOf(doc.Id));
                    if (toClearViewonly.indexOf(doc.Id) > -1) toClearViewonly.remove(toClearViewonly.indexOf(doc.Id));
                }
            }
        }

        if (Trigger.isDelete) {
            for (Simploud__Controlled_Document__c doc : Trigger.old) {
                if (collabManager.isCollaborationFieldsGoogleOrSharepointSet(doc)
                    && doc.Use_Document_Collaboration_Tool__c == 'Yes'
                    ) 
                {
                    if (collabManager.collaborationToolName == 'SharePoint') {
                        toDelete.add(doc.Id);
                    } else {
                        toDelete.add(doc.Google_Docs_URL__c) ;
                    }
    
                    if (toUpload.indexOf(String.valueOf(doc.Id)) > -1) toUpload.remove(toUpload.indexOf(String.valueOf(doc.Id)));
                    toUpdateAccess.remove(doc.Id);
                    toSaveMinorVersion.remove(doc.Id);
                    if (toUpdateViewonly.indexOf(doc.Id) > -1) toUpdateViewonly.remove(toUpdateViewonly.indexOf(doc.Id));
                    if (toClearViewonly.indexOf(doc.Id) > -1) toClearViewonly.remove(toClearViewonly.indexOf(doc.Id));
                }
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