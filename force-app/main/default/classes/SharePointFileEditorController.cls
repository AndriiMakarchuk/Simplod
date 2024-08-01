public with sharing class SharePointFileEditorController {
    public class NoFileURLException extends Exception {}

    /**
     * Const map of file extensions to mime type/application name
     */
    private static final Map<String, String> EXT_TO_MIMETYPE = new Map<String, String> {
        'doc' => 'word',
        'docx' => 'word',
        'xls' => 'excel',
        'xlsx' => 'excel',
        'ppt' => 'ppt',
        'pptx' => 'ppt',
        'pdf' => 'pdf'
    };
    
    /**
     * Builds a URL for opening the file in edit mode from download URL (OneDrive__URL__c)
     * @param controlledDocumentId `string` - Id of the controlled document 
     * @return  `string`
     * @author Danyil Mahalias
     */
    @AuraEnabled
    public static string getEmbedUrl(String controlledDocumentId){
        Simploud__Controlled_Document__c controlledDocument = [SELECT Id, Name, OneDrive_URL__c, Simploud__Template_Used__c, Uploaded_File_Extension__c FROM Simploud__Controlled_Document__c WHERE Id = :controlledDocumentId WITH SECURITY_ENFORCED];

        string oneDriveUrl = controlledDocument.OneDrive_URL__c;

        if (String.isBlank(oneDriveUrl) && String.isBlank(controlledDocument.Simploud__Template_Used__c)) throw new NoFileURLException('No file URL found for this controlled document');  
        else if (String.isBlank(oneDriveUrl) && String.isBlank(controlledDocument.Simploud__Template_Used__c)) return null;

        string filename = getFilename(controlledDocumentId);

        string embedUrl;
        if (controlledDocument.Uploaded_File_Extension__c == 'pdf') {
            embedUrl = oneDriveUrl.replace('download.aspx', 'embed.aspx');
        } else {
            embedUrl = oneDriveUrl.replace('.com', '.com/:w:/r')
                            .replace('download.aspx', 'Doc.aspx')
                            .replace('uniqueid=', 'sourcedoc={')
                            .replace('&', '}&');
            embedUrl += '&file=' + filename + '&action=embedview';
        }

        return embedUrl;
    }

    /**
     * Based on current user info returns a URL for opening the file in edit mode
     * For File admins it returns a direct link to the file in SharePoint
     * For the record owner it returns a value from the OneDrive_Owner_Shared_Link__c field
     * For a participant it returns a value from the OneDrive_Shared_Link__c field on the Document Participant object
     * @param controlledDocumentId `string` - Id of the controlled document
     * @return  `string`
     * @author Danyil Mahalias
     */
    @AuraEnabled
    public static string getEditorUrl(String controlledDocumentId) {
        Simploud__Controlled_Document__c controlledDocument = [SELECT Id, Name, Uploaded_File_Extension__c, OneDrive_URL__c, OwnerId, OneDrive_Owner_Shared_Link__c, OneDrive_Embed_URL__c FROM Simploud__Controlled_Document__c WHERE Id = :controlledDocumentId WITH SECURITY_ENFORCED];
        
        if (controlledDocument.Uploaded_File_Extension__c == 'pdf') {
            return controlledDocument.OneDrive_Embed_URL__c;
        }

        Id currentUserId = UserInfo.getUserId();

        if (currentUserId == controlledDocument.OwnerId) return controlledDocument.OneDrive_Owner_Shared_Link__c;

        Simploud__Document_Participant__c[] participant = [SELECT ID, OneDrive_Shared_Link__c, Simploud__Participant__c FROM Simploud__Document_Participant__c WHERE (Simploud__Document__c = :controlledDocumentId AND Simploud__Participant__c = :currentUserId) WITH SECURITY_ENFORCED];
        
        if (participant.size() > 0 && String.isNotBlank(participant[0].OneDrive_Shared_Link__c))
        return participant[0].OneDrive_Shared_Link__c;

        try {
            User u = [SELECT Id, File_Admin__c FROM User WHERE Id = :currentUserId WITH SECURITY_ENFORCED];
            if (u.File_Admin__c ==  true) return getEmbedUrl(controlledDocumentId).replace('&action=embedview', '');
        }   
        catch (Exception e) {
            // nothing here
        }

        return getEmbedUrl(controlledDocumentId).replace('&action=embedview', '');
    }

    /**
     * Utility method for getting a record name
     * @param controlledDocumentId `string` - Id of the controlled document
     * @return  `string`
     * @author Danyil Mahalias
     */
    @AuraEnabled
    public static string getRecordName(string controlledDocumentId) {
        Simploud__Controlled_Document__c controlledDocument = [SELECT Id, Name FROM Simploud__Controlled_Document__c WHERE Id = :controlledDocumentId WITH SECURITY_ENFORCED];
        return controlledDocument.Name;
    }

    /**
     * Method to be called from the UI to save the document to Salesforce (calls SharePointApiHandler.getDocuments)
     * @param controlledDocumentId `string` - Id of the controlled document
     * @author Danyil Mahalias
     */
    @AuraEnabled
    public static void saveDocumentToSF(string controlledDocumentId) {
        SharePointApiHandler.getDocuments(controlledDocumentId);
    }

    /**
     * Method to be called from the UI. Returns a value of the OneDrive_URL__c field
     * @param controlledDocumentId `string` - Id of the controlled document
     * @return  `string`
     * @author Danyil Mahalias
     */
    @AuraEnabled
    public static string getDownloadLink(string controlledDocumentId) {
        Simploud__Controlled_Document__c controlledDocument = [SELECT Id, Name, OneDrive_URL__c FROM Simploud__Controlled_Document__c WHERE Id = :controlledDocumentId WITH SECURITY_ENFORCED];
        return controlledDocument.OneDrive_URL__c;
    }

    /**
     * Method to be called from the UI. Calls SharePointApiHandler.uploadDocuments method
     * @param controlledDocumentId `string` - Id of the controlled document
     * @author Danyil Mahalias
     */
    @AuraEnabled
    public static void uploadFileToSharePoint(String controlledDocumentId) {
        SharePointApiHandler.uploadDocuments(new String[] { controlledDocumentId });
    }

    /**
     * Retuurns a mime type of the file based on the file extension
     * @param controlledDocumentId `string` - Id of the controlled document
     * @return  `string` -- value from the EXT_TO_MIMETYPE map or 'unknown' if no value found in the map for the file extension of the file
     * @author Danyil Mahalias
     */
    @AuraEnabled
    public static string getFileMimeType(String controlledDocumentId) {
        Simploud__Controlled_Document__c controlledDocument = [SELECT Id, Uploaded_File_Extension__c FROM Simploud__Controlled_Document__c WHERE Id = :controlledDocumentId WITH SECURITY_ENFORCED];
        if (!EXT_TO_MIMETYPE.containsKey(controlledDocument.Uploaded_File_Extension__c)) return 'unknown';

        return EXT_TO_MIMETYPE.get(controlledDocument.Uploaded_File_Extension__c);
    }

    /**
     * @param controlledDocumentId `string` - Id of the controlled document
     * @return  `boolean` -- true if the file is attached to the controlled document, false otherwise
     * @author Danyil Mahalias
     */
    @AuraEnabled
    public static boolean isFileAttached(string controlledDocumentId) {
        Simploud__Controlled_Document__c controlledDocument = [SELECT Id,  (SELECT Id, ContentDocumentId FROM ContentDocumentLinks) FROM Simploud__Controlled_Document__c WHERE Id = :controlledDocumentId WITH SECURITY_ENFORCED];
        return controlledDocument.ContentDocumentLinks.size() > 0;
    }

    /**
     * @param controlledDocumentId `string` - Id of the controlled document
     * @return  `boolean` returns true if the user is a system admin or the owner of the controlled document or a participant of the controlled document, false otherwise
     * @author Danyil Mahalias
     */
    @AuraEnabled
    public static boolean isUserHasAccessToDocument(string controlledDocumentId) {
        try {
            User currentUser = [SELECT Id, File_Admin__c FROM User WHERE Id = :UserInfo.getUserId() WITH SECURITY_ENFORCED];

            if (currentUser.File_Admin__c == true) return true;
        }
        catch (Exception e) { //exception fires if user is not a system admin and/or don't have an access to User object
            // nothing here
        }

        Simploud__Controlled_Document__c controlledDocument = [SELECT Id, OwnerId FROM Simploud__Controlled_Document__c WHERE Id = :controlledDocumentId WITH SECURITY_ENFORCED];
        
        if (controlledDocument.OwnerId == UserInfo.getUserId()) return true;

        Simploud__Document_Participant__c[] participants = [SELECT Id FROM Simploud__Document_Participant__c WHERE Simploud__Document__c = :controlledDocumentId AND Simploud__Participant__c = :UserInfo.getUserId() WITH SECURITY_ENFORCED];
    
        if (participants.size() > 0) return true;

        return false;
    }

    /**
     * Returns value of the Simploud__Status__c field of the controlled document
     * @param controlledDocumentId `string` - Id of the controlled document
     * @return  `string`
     * @author Danyil Mahalias
     */
    @AuraEnabled
    public static string getDocumentStatus(string controlledDocumentId) {
        Simploud__Controlled_Document__c doc = [SELECT Id, Simploud__Status__c FROM Simploud__Controlled_Document__c WHERE Id = :controlledDocumentId WITH SECURITY_ENFORCED];
        return doc.Simploud__Status__c;
    }

    /**
     * Requests a direct URL to the file in OneDrive. Used for opening the file in the desktop application
     * @param controlledDocumentId `string` - Id of the controlled document
     * @return  `string`
     * @author Danyil Mahalias
     */
    @AuraEnabled
    public static string getOneDriveDirectUrl(string controlledDocumentId) {
        Simploud__Controlled_Document__c controlledDocument = [SELECT Id, OneDrive_URL__c FROM Simploud__Controlled_Document__c WHERE Id = :controlledDocumentId WITH SECURITY_ENFORCED];
        String fileId = SharePointApiHandler.getFileId(controlledDocument.OneDrive_URL__c);

        if (fileId == null || fileId == '') throw new NoFileURLException('No file URL found for this controlled document');

        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('callout:SharePoint/me/drive/items/' + fileId);
        request.setHeader('Accept', 'application/json');
        request.setHeader('Content-Type', 'application/json');
        request.setMethod('GET');

        HttpResponse response = http.send(request);

        if (response.getStatusCode() != 200) throw new NoFileURLException(response.getStatusCode() + ': ' + response.getBody());

        OneDriveFileInfoWrapper fileInfo = (OneDriveFileInfoWrapper) JSON.deserialize(response.getBody(), OneDriveFileInfoWrapper.class);
        string root = fileInfo.webUrl.split('_layouts')[0];
        string path = '/Documents/Review/' + EncodingUtil.UrlEncode(fileInfo.name, 'UTF-8'); // TODO: looks like workaround

        return root + path;
    }

    /**
     * Builds a filename for the controlled document based on the file name and file extension of the file attached to the controlled document
     * @param controlledDocumentId `string` - Id of the controlled document
     * @return  `string`
     * @author Danyil Mahalias
     */
    public static string getFilename(String controlledDocumentId) {
        Simploud__Controlled_Document__c controlledDocument = [SELECT Id,  (SELECT Id, ContentDocumentId FROM ContentDocumentLinks) FROM Simploud__Controlled_Document__c WHERE Id = :controlledDocumentId WITH SECURITY_ENFORCED];
        ContentDocumentLink contentDocumentLink = controlledDocument.ContentDocumentLinks[0];
        ContentDocument contentDocument = [SELECT Id, Title, FileExtension FROM ContentDocument WHERE Id = :contentDocumentLink.ContentDocumentId WITH SECURITY_ENFORCED];
        System.debug(contentDocument);
        return contentDocument.Title + '.' + contentDocument.FileExtension;
    }

    @AuraEnabled
    public static boolean isCollaborationEnabled(String controlledDocumentId) {
        Simploud__Controlled_Document__c controlledDocument = [SELECT Id, Use_Document_Collaboration_Tool__c FROM Simploud__Controlled_Document__c WHERE Id = :controlledDocumentId WITH SECURITY_ENFORCED];

        return controlledDocument.Use_Document_Collaboration_Tool__c == 'Yes';
    }

    private class OneDriveFileInfoWrapper {
        public string id {get;set;}
        public string webUrl {get;set;}
        public string name {get;set;}
    }
}