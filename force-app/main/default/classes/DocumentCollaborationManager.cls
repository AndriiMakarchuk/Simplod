/**
 * Utility class to be called directly from the trigger. Selects the collaboration tool to be used based on the org settings.
 * @author Danyil Mahalias
 * @since 22.09.2023
 */
public with sharing class DocumentCollaborationManager {
    public class CollaborationToolException extends Exception {}

    ICollaborationTool collaborationTool;
    public String collaborationToolName;

    public DocumentCollaborationManager() {
        Simploud__SimploudOrgSettings__c settings = Simploud__SimploudOrgSettings__c.getOrgDefaults();

        string collaborationToolName = settings.Collaboration_Tool__c;

        if (collaborationToolName == 'SharePoint') {
            this.collaborationTool = new SharePointCollaborationTool();
            this.collaborationToolName = 'SharePoint';
        }
        else if (collaborationToolName == 'Google') {
            this.collaborationTool = new GoogleDocsCollaborationTool();
            this.collaborationToolName = 'Google';
        }
        else {
            throw new CollaborationToolException('Collaboration tool not supported');
        }

        try {
            scheduleRefreshJob();
        }
        catch (Exception e) {
            System.debug('Error scheduling refresh job: ' + e.getMessage());
        }
    }

    public Boolean isCollaborationFieldsGoogleOrSharepointSet(Simploud__Controlled_Document__c doc) {
        return this.collaborationToolName == 'SharePoint' && String.isNotBlank(doc.OneDrive_URL__c)
                || this.collaborationToolName == 'Google' && String.isNotBlank(doc.Google_Docs_Url__c);
    }

    public void deleteDocuments(String[] docsUrls) {
        this.collaborationTool.deleteDocuments(docsUrls);
    }

    public void uploadFiles(String[] docIds) {
        this.collaborationTool.uploadFiles(docIds);
    }

    public void saveMinorVersion(Map<Id, String> docIdStatus) {
        this.collaborationTool.saveMinorVersion(docIdStatus);
    }

    public void updatePermissions(Id[] docIds) {
        this.collaborationTool.updatePermissions(docIds);
    }

    public void updateViewonly(Id[] docIds) {
        this.collaborationTool.updateViewonly(docIds);
    }

    public void clearViewonly(Id[] docIds) {
        this.collaborationTool.clearViewonly(docIds);
    }

    public void markFilesUploaded(Id[] docIds) {
        Simploud__Controlled_Document__c[] docs = [SELECT Id, Simploud__File_In_Cloud__c, Simploud__File_Exist__c FROM Simploud__Controlled_Document__c WHERE Id IN :docIds];

        for (Simploud__Controlled_Document__c doc : docs) {
            doc.Simploud__File_In_Cloud__c = doc.Simploud__File_Exist__c;
        }

        update docs;
    }

    public void scheduleRefreshJob() {
        if ([SELECT count() FROM CronTrigger WHERE CronJobDetail.Name = 'NamedCredsRefreshJob'] > 0) {
            return;
        }

        NamedCredsRefreshJob job = new NamedCredsRefreshJob();

        system.schedule('NamedCredsRefreshJob', '0 0 0 * * ?', job);
    }
}