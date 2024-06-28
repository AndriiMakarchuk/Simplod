/**
 * Non-static wrapper for SharePoint triggers helper.
 * @author Danyil Mahalias 
 * @since 22.09.2023
 */
public with sharing class SharePointCollaborationTool implements ICollaborationTool {
    public SharePointCollaborationTool() {}

    public void deleteDocuments(String[] docsUrls) {
        SharePointTriggersHelper.deleteDocuments(docsUrls);
    }

    public void uploadFiles(String[] docIds) {
        // if (system.isFuture() || system.isBatch()) {
        //     return;
        // }

        SharePointTriggersHelper.uploadFiles(docIds);
    }

    public void saveMinorVersion(Map<Id, String> docIdStatus) {
        SharePointTriggersHelper.saveMinorVersion(docIdStatus);
    }

    public void updatePermissions(Id[] docIds) {
        SharePointTriggersHelper.updatePermissions(docIds);
    }

    public void updateViewonly(Id[] docIds) {
        SharePointTriggersHelper.updateViewonly(docIds);
    }

    public void clearViewonly(Id[] docIds) {
        SharePointTriggersHelper.clearViewonly(docIds);
    }
}