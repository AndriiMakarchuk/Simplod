/**
 * Non-static wrapper for GoogleDocsTriggersHelper. To be called from DocumentCollaborationManager
 * @author Danyil Mahalias
 * @since 22.09.2023
 */
public with sharing class GoogleDocsCollaborationTool implements ICollaborationTool {
    public GoogleDocsCollaborationTool() {}

    public void deleteDocuments(String[] docsUrls) {
        GoogleDocsTriggersHelper.deleteDocuments(docsUrls);
    }

    public void uploadFiles(String[] docIds) {
        try {
            GoogleDocsTriggersHelper.uploadFiles(docIds);
        } catch (Exception e) {
            // there is nothing we should do here
        }
    }

    public void saveMinorVersion(Map<Id, String> docIdStatus) {
        GoogleDocsTriggersHelper.saveMinorVersion(docIdStatus);
    }

    public void updatePermissions(Id[] docIds) {
        GoogleDocsTriggersHelper.updatePermissions(docIds);
    }

    public void updateViewonly(Id[] docIds) {
        GoogleDocsTriggersHelper.updateViewonly(docIds);
    }

    public void clearViewonly(Id[] docIds) {
        GoogleDocsTriggersHelper.clearViewonly(docIds);
    }
}