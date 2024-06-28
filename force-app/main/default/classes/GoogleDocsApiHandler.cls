/**
 * Class for interracting with the Google Drive API for uploading, updating and deleting files
 * @author Danyil Mahalias
 * @since 21.09.2023
 */
public with sharing class GoogleDocsApiHandler {
    public class GoogleDocsApiException extends Exception {}

    private static final Map<String, String> exToMimeType = new Map<String, String> {
        'docx' => 'application/vnd.google-apps.document',
        'doc' => 'application/vnd.google-apps.document',
        'xls' => 'application/vnd.google-apps.spreadsheet',
        'xlsx' => 'application/vnd.google-apps.spreadsheet',
        'ppt' => 'application/vnd.google-apps.presentation',
        'pptx' => 'application/vnd.google-apps.presentation'
    };

    private static final Map<String, String> extnToServiceUrl = new Map<String, String> {
        'docx' => 'https://docs.google.com/document/d/',
        'doc' => 'https://docs.google.com/document/d/',
        'xls' => 'https://docs.google.com/spreadsheets/d/',
        'xlsx' => 'https://docs.google.com/spreadsheets/d/',
        'ppt' => 'https://docs.google.com/presentation/d/',
        'pptx' => 'https://docs.google.com/presentation/d/'
    };

    private static final Map<String, String> extnToExportMimeType = new Map<String, String> {
        'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'doc' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'xls' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'ppt' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        'pdf' => 'application/pdf'
    };

    /**
     * Uploads files to Google Docs. To be called from trigger handler
     * @param recordIds The Controlled Document record Ids to upload to Google Docs
     * @return void
     * 
     * @author Danyil Mahalias
     */
    public static void uploadFile(Id[] recordIds) {
        if (recordIds == null) throw new GoogleDocsApiException('One or more parameters are null');
        if (recordIds.size() == 0) return;

        Map<Id, Simploud__Controlled_Document__c> controlledDocuments = new Map<Id, Simploud__Controlled_Document__c>(
            [
                SELECT Id, (SELECT Id, ContentDocumentId FROM ContentDocumentLinks), Google_Docs_URL__c, OwnerId
                FROM Simploud__Controlled_Document__c
                WHERE Id IN :recordIds 
                // AND Use_Document_Collaboration_Tool__c = 'Yes'
            ]
        );

        Map<Id, Simploud__Controlled_Document__c> contentDocumentIds = new Map<Id, Simploud__Controlled_Document__c>(); // ContentDocumentId -> Controlled Document
        for (Simploud__Controlled_Document__c cd : controlledDocuments.values()) {  
            if (cd.ContentDocumentLinks.size() == 0) continue;

            contentDocumentIds.put(cd.ContentDocumentLinks[0].ContentDocumentId, cd);
        }

        Map<Id, Simploud__Controlled_Document__c> contentDocuments = new Map<Id, Simploud__Controlled_Document__c>();
        List<Id> IdFromSet = new List<Id>(contentDocumentIds.keySet());

        for (ContentDocument cd : [SELECT Id, Title, FileExtension
                                    FROM ContentDocument
                                    WHERE Id IN :IdFromSet
                                    ]) {
            contentDocuments.put(cd.Id, contentDocumentIds.get(cd.Id));
        }

        Map<ContentVersion, Simploud__Controlled_Document__c> versions = new Map<ContentVersion, Simploud__Controlled_Document__c>(); // ContentVersion -> Controlled Document
        for (ContentVersion cv : [SELECT Id, VersionData, Title, ContentDocumentId, FileExtension
                                    FROM ContentVersion
                                    WHERE ContentDocumentId IN :contentDocuments.keySet() AND FileExtension IN ('docx', 'doc', 'xls', 'xlsx', 'ppt', 'pptx') 
                                    ORDER BY CreatedDate DESC
                                    ]) {
            if (versions.values().contains(contentDocuments.get(cv.ContentDocumentId))) continue;
            versions.put(cv, contentDocuments.get(cv.ContentDocumentId));
        }

        List<Simploud__Controlled_Document__c> toUpdate = new List<Simploud__Controlled_Document__c>();
        for (ContentVersion attach : versions.keySet()) {
            Blob docBody = attach.VersionData;

            string title = attach.Title;
            string extn = attach.FileExtension;
            Simploud__Controlled_Document__c record = versions.get(attach);

            if (attach.Title.contains('.')) {
                title = attach.Title.split('\\.')[0];
            }

            title = generateFileName(record.Id);

            // Update or create
            if (record.Google_Docs_URL__c != null 
                && record.Google_Docs_URL__c.length() != 0 
                && record.Google_Docs_URL__c.contains('https://docs.google.com/')) { // Update
                    string fileId = record.Google_Docs_URL__c.split('/')[5];
                    updateFile(
                        docBody,
                        fileId,
                        '10101010',
                        title,
                        extn
                    );
                    continue;
            }
            else { // Create
                Simploud__Controlled_Document__c cd;
                try {
                    cd = uploadFile(
                        docBody,
                        title,
                        extn,
                        record
                    );
                } catch (Exception e) {
                    continue;
                }

                if (cd != null) {
                    GoogleDocsPermissionApiHandler.addPermissionsForFileAdmins(cd.Google_Docs_URL__c);
                    GoogleDocsPermissionApiHandler.addPermissionForOwner(cd.Google_Docs_URL__c, cd.OwnerId);
                    toUpdate.add(cd);
                }
            }
        }

        if (toUpdate.size() != 0) {
            update toUpdate;
        }
    }

    /**
     * Uploads a file to Google Docs (internal method for interracting with the Google Drive API)
     * @param versionData The file content to upload
     * @param title The title of the file
     * @param extn The file extension
     * @param record The Controlled Document record to which the file is related
     * @return The Controlled Document record with updated Google_Docs_URL__c field
     * 
     * @author Danyil Mahalias
     */
    public static Simploud__Controlled_Document__c uploadFile(
        blob versionData,
        string title,
        string extn,
        Simploud__Controlled_Document__c record
    ) {
        if (versionData == null || title == null || extn == null || record == null) throw new GoogleDocsApiException('One or more parameters are null');
        if (title.length() == 0 || extn.length() == 0) throw new GoogleDocsApiException('One or more parameters are empty');
        if (title.contains('\n') || extn.contains('\n')) throw new GoogleDocsApiException('One or more parameters contain new line characters');
        // if (isFileAlreadyExists(title + '.' + extn)) throw new GoogleDocsApiException('File already exists');

        if ([SELECT Id FROM AsyncApexJob WHERE MethodName = 'uploadFiles' AND Status = 'Processing'].size() > 1) {
            throw new GoogleDocsApiException('Another upload is in progress');
        }

        Http http = new Http();
        HttpRequest request = new HttpRequest();
        string boundary = '10101010';

        request.setEndpoint('callout:GDocs' + '/upload/drive/v3/files?uploadType=multipart');
        request.setMethod('POST');
        request.setHeader('Content-Type', 'multipart/related;boundary='+boundary);

        string body = buildMultipartRelatedRequestBody(
            boundary,
            '{"name": "' + title + '.' + extn + '", "mimeType": "' + exToMimeType.get(extn) + '"}',
            versionData,
            extn
        );

        request.setBody(body);

        HttpResponse response = http.send(request);

        if (response.getStatusCode() != 200) {
            throw new GoogleDocsApiException('Google Docs API returned an error: ' + response.getStatusCode() + '\n\n' + response.getBody());
        }

        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());

        record.Google_Docs_URL__c = extnToServiceUrl.get(extn) + (String)result.get('id');
        record.File_In_Cloud__c = true;

        return record;
    }

    public static boolean isFileAlreadyExists(String filename) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();

        req.setEndpoint('callout:GDocs' + '/drive/v3/files?q=name%3D\'' + filename + '\'');
        req.setMethod('GET');

        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200) {
            throw new GoogleDocsApiException('Google Docs API returned an error: ' + res.getStatusCode() + '\n\n' + res.getBody());
        }

        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        return ((Object[])result.get('files')).size() > 0;
    }

    /**
     * Updates a file in Google Docs (internal method for interracting with the Google Drive API)
     * @param versionData blob of the file content to upload
     * @param fileId Id of the file to update
     * @param boundary boundary string for the request. Must be the same as the one in the Content-Type header. Can be any string
     * @param title file title
     * @param extn file extension
     * 
     * @author Danyil Mahalias
     */
    private static void updateFile(
        Blob versionData,
        String fileId,
        String boundary,
        String title,
        String extn
    ) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();

        request.setEndpoint('callout:GDocs' + '/upload/drive/v3/files/' + fileId + '?uploadType=multipart');
        request.setMethod('PATCH');
        request.setHeader('Content-Type', 'multipart/related;boundary='+boundary);

        string body = buildMultipartRelatedRequestBody(
            boundary,
            '{"name": "' + title + '.' + extn + '", "mimeType": "' + exToMimeType.get(extn) + '"}',
            versionData,
            extn
        );

        request.setBody(body);

        HttpResponse response = http.send(request);

        if (response.getStatusCode() != 200) {
            throw new GoogleDocsApiException('Google Docs API returned an error: ' + response.getStatusCode() + '\n\n' + response.getBody());
        }
    }

    /**
     * Builds the multipart/related request body for the Google Drive API. Utility method
     * @param boundary Boundary string for the request. Must be the same as the one in the Content-Type header. Can be any string
     * @param metadata The metadata of the file to upload. Must be a JSON string. See https://developers.google.com/drive/api/v3/reference/files/create
     * @param fileBody VersionData of the ContentVersion record
     * @param extn File extension
     * @return The request body
     * 
     * @author Danyil Mahalias
     */
    private static String buildMultipartRelatedRequestBody(String boundary, String metadata, Blob fileBody, String extn) {
        if (boundary == null || metadata == null || fileBody == null || extn == null) throw new GoogleDocsApiException('One or more parameters are null');
        if (boundary.length() == 0 || metadata.length() == 0 || extn.length() == 0) throw new GoogleDocsApiException('One or more parameters are empty');
        if (boundary.contains('\n') || metadata.contains('\n') || extn.contains('\n')) throw new GoogleDocsApiException('One or more parameters contain new line characters');
        if (boundary.contains('\r') || metadata.contains('\r') || extn.contains('\r')) throw new GoogleDocsApiException('One or more parameters contain carriage return characters'); 

        return '--' + boundary + '\n' +
                'Content-Type: application/json; charset=UTF-8\n\n' +
                metadata + '\n\n' +
                '--' + boundary + '\n' +
                'Content-Type: ' + exToMimeType.get(extn) + '\n' +
                'Content-Transfer-Encoding:base64\n\n' + '\n\n' +
                EncodingUtil.base64Encode(fileBody) + '\n\n' +
                '--' + boundary + '--';
    }

    /**
     * Deletes files from Google Docs. To be called from trigger handler
     * @param docUrls The Google Docs URLs of the files to delete
     * @return void
     * 
     * @author Danyil Mahalias
     */
    public static void deleteFile(String[] docUrls) {
        if (docUrls == null) throw new GoogleDocsApiException('One or more parameters are null');
        if (docUrls.size() == 0) return;

        for (String url : docUrls) {
            if (url != null && url.length() != 0 && url.contains('https://docs.google.com/')) {
                string fileId = url.split('/')[5];
                deleteFile(fileId);
            }
        }

        Simploud__Controlled_Document__c[] affectedDocs = [SELECT Id, Google_Docs_URL__c FROM Simploud__Controlled_Document__c WHERE Google_Docs_URL__c IN :docUrls];

        for (Simploud__Controlled_Document__c doc : affectedDocs) {
            doc.Google_Docs_URL__c = null;
            doc.File_In_Cloud__c = false;
        }

        if (affectedDocs.size() > 0) {
            update affectedDocs;
        }

    }

    /**
     * Deletes a file from Google Docs (internal method for interracting with the Google Drive API)
     * @param fileId Google Drive file Id
     * @param record The Controlled Document record to which the file is related
     * @return The Controlled Document record with updated Google_Docs_URL__c field
     * 
     * @author Danyil Mahalias
     */
    private static void deleteFile(String fileId) {
        if (fileId == null) throw new GoogleDocsApiException('One or more parameters are null');
        if (fileId.length() == 0) throw new GoogleDocsApiException('One or more parameters are empty');
        if (fileId.contains('\n')) throw new GoogleDocsApiException('One or more parameters contain new line characters');

        Http http = new Http();
        HttpRequest request = new HttpRequest();

        request.setEndpoint('callout:GDocs' + '/drive/v3/files/' + fileId);
        request.setMethod('DELETE');

        HttpResponse response = http.send(request);

        if (response.getStatusCode() != 204) {
            throw new GoogleDocsApiException('Google Docs API returned an error: ' + response.getStatusCode() + '\n\n' + response.getBody());
        }
    }
    
    /**
     * Saves files from Google Docs to Salesforce. To be called from trigger handler
     * @param controlledDocumentIds Ids of the Controlled Document records to save
     * @return void
     * 
     * @author Danyil Mahalias
     */
    public static void saveDocument(Id[] controlledDocumentIds) {
        Simploud__Controlled_Document__c[] docs = [
            SELECT Id, Google_Docs_URL__c, (SELECT Id, ContentDocumentId FROM ContentDocumentLinks), Simploud__Version__c
            FROM Simploud__Controlled_Document__c
            WHERE Id IN :controlledDocumentIds
        ];

        Id contentDocumentId = docs[0].ContentDocumentLinks[0].ContentDocumentId;

        ContentVersion[] versions = [
            SELECT Id, VersionData, Title, ContentDocumentId, FileExtension
            FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId AND FileExtension IN ('docx', 'doc', 'xls', 'xlsx', 'ppt', 'pptx') 
            ORDER BY CreatedDate DESC
        ];

        for (Simploud__Controlled_Document__c doc : docs) {
            if (doc.Google_Docs_URL__c == null || doc.Google_Docs_URL__c.length() == 0) continue;

            string fileId = doc.Google_Docs_URL__c.split('/')[5];
            saveDocument(fileId, doc, versions[0]);
        }
    }

    /**
     * Downloads a file from Google Docs (internal method for interracting with the Google Drive API)
     * @param fileId Id of the file to download
     * @param doc Controlled Document record to which the file is related
     * @param previousVersion ContentVersion record of the previous version of the file
     * 
     * @author Danyil Mahalias
     */
    private static void saveDocument(String fileId, Simploud__Controlled_Document__c doc, ContentVersion previousVersion) {
        if (fileId == null || doc == null || previousVersion == null) throw new GoogleDocsApiException('One or more parameters are null');
        if (doc.ContentDocumentLinks == null || doc.ContentDocumentLinks.size() == 0) throw new GoogleDocsApiException('One or more parameters are empty');

        Http http = new Http();
        HttpRequest request = new HttpRequest();

        request.setEndpoint('callout:GDocs' + '/drive/v3/files/' + fileId + '/export?mimeType=' + extnToExportMimeType.get(previousVersion.FileExtension));
        request.setMethod('GET');
        request.setTimeout(120000);

        HttpResponse response = http.send(request);

        if (response.getStatusCode() != 200) {
            throw new GoogleDocsApiException('Google Docs API returned an error: ' + response.getStatusCode() + '\n\n' + response.getBody());
        }

        Blob fileBody = response.getBodyAsBlob();

        ContentVersion cv = createContentVersion(
            previousVersion.Title + '.' + previousVersion.FileExtension,
            fileBody,
            doc.ContentDocumentLinks[0].ContentDocumentId
        );
        cv.ReasonForChange = 'Upload SharePoint Document';
        insert cv;

        doc.Simploud__Version__c += 0.1;
        update doc;
    }

    /** 
     *   Generate file name based on the document name format from Custom Setting
     *   @param recordId - Id of the document
     *   @return String - generated file name
     *   @author Danyil Mahalias
     */
    private static String generateFileName(String recordId) {
        Simploud__SimploudOrgSettings__c settings = Simploud__SimploudOrgSettings__c.getOrgDefaults();
        String nameFormat = settings.Document_Name_Format__c;
        Simploud__Controlled_Document__c doc;

        String[] substrings = new List<String>{};

        Integer dollarSignAppearsInNameFormat = 0;
        for (Integer i = 0; i < nameFormat.length(); i++) {
        if (nameFormat.charAt(i) == 36) { // 36 = $
            dollarSignAppearsInNameFormat++;
        }
        }

        if (Math.mod(dollarSignAppearsInNameFormat, 2) != 0) {
        throw new GoogleDocsApiException(
            'Document name format is not correct.'
        );
        }

        for (Integer i = 0; i < nameFormat.length(); i++) {
        String substring = '';
        if (nameFormat.charAt(i) == 36) { // 36 = $
            i++;
            while (nameFormat.charAt(i) != 36) {
            if (nameFormat.charAt(i) != 36 && nameFormat.charAt(i) != null)
                substring += String.fromCharArray(
                new List<Integer>{ nameFormat.charAt(i) }
                );
            i++;
            }
            substrings.add(substring);
        }
        }

        String query =
        'SELECT ' +
        String.join(substrings, ', ') +
        ' FROM Simploud__Controlled_Document__c WHERE Id=\'' +
        recordId +
        '\'';
        try {
        doc = (Simploud__Controlled_Document__c) Database.query(query);
        } catch (Exception e) {
        throw new GoogleDocsApiException('Error while querying Controlled Document record');
        }

        if (doc == null) {
        throw new GoogleDocsApiException('Controlled Document record not found');
        }

        String docName = nameFormat;
        for (String fieldName : substrings) {
        docName = docName.replaceAll(
            fieldName,
            String.valueOf(doc.get(fieldName))
        );
        }

        docName = docName.replaceAll('\\$', '');

        if (!nameFormat.contains('$Id$')) {
        // keep names unique everytime
        docName += '-' + recordId;
        }

        if (docName.length() > 255) {
        docName = docName.replace('-' + recordId, '');
        docName =
            docName.substring(0, 255 - String.valueOf(recordId).length() - 1) +
            '-' +
            recordId;
        }

        return EncodingUtil.urlEncode(docName,'UTF-8').replaceAll('\\+', '_');
    }

     /**
     * Utility method for creating ContentVersion record
     * @param name file name
     * @param body file body
     * @param parentId record to associate the file with
     * @return  `ContentVersion`
     * @author Danyil Mahalias
     */
    public static ContentVersion createContentVersion(
        String name,
        Blob body,
        String parentId
    ) {
        ContentVersion contentVersion = new ContentVersion();
        contentVersion.ContentLocation = 'S'; // S = Stored in Salesforce
        contentVersion.PathOnClient = name;
        contentVersion.Title = name;
        contentVersion.VersionData = body;
        contentVersion.ContentDocumentId = parentId;
        return contentVersion;
    }
}