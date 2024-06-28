public class SharePointApiHandler {
  private class AccessTokenException extends Exception {
  }
  private class CannotGenerateEmbedLinkException extends Exception {
  }
  private class DocumentNotFoundException extends Exception {
  }
  private class DocumentNameFormatException extends Exception {
  }
  private class CannotDeleteDocumentException extends Exception {
  }

  /**
   * Constant map of content types accordingly to OneDrive API
   * @param fileType extension of the file
   * @return  content type of the file accordingly to OneDrive API
   * @author Anastasiia Stetsenko
   */
  public static string returnContentType(string fileType) {
    Map<String, String> contentTypeMap = new Map<String, String> {
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'doc' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' => 'application/vnd.ms-excel',
      'csv' => 'application/vnd.ms-excel',
      'ppt' => 'application/vnd.ms-powerpoint',
      'pptx' => 'application/vnd.ms-powerpoint'
    };

    return contentTypeMap.get(fileType);
  }

  /**
   * Miscellaneous method to send request via HTTP
   * @param method GET/POST/DELETE
   * @param url target url
   * @param headers map of headers for the request (key - header name, value - header value)
   * @param body request body (plain text)
   * @param blobBody (optional) binary body
   * @return response of the request (HTTPResponse object) or null if request failed (e.g. 401 error)
   * @author Anastasiia Stetsenko
   */
  public static HTTPResponse sendRequest(
    String method,
    string url,
    Map<String, String> headers,
    string body,
    Blob blobBody
  ) {
    HttpRequest req = new HttpRequest();

    req.setEndpoint(url);
    req.setMethod(method);

    if (headers != null && headers.size() > 0)
      for (String header : headers.keySet()) {
        if (headers.get(header) != null)
          req.setHeader(header, headers.get(header));
      }

    if (body != null) {
      req.setBody(body);
    } else if (blobBody != null) {
      req.setBodyAsBlob(blobBody);
    }

    req.setTimeout(120000);

    Http http = new Http();
    HTTPResponse res = tryToSend(http, req, true);

    return res;
  }

  /**
   * Miscellaneous method to send request via HTTP. Handles HTTP error 401 (Unauthorized) and retries request
   * @param http instance of Http class
   * @param req HttpRequest instance
   * @param retry used for recursion
   * @return  `HttpResponse` -- response of the request (HTTPResponse object) or null if request failed (e.g. 401 error)
   * @exception AccessTokenException -- if request failed with 401 error after retrying
   * @author Anastasiia Stetsenko
   * @see sendRequest
   */
  public static HttpResponse tryToSend (
    Http http,
    HttpRequest req,
    boolean retry
  ) {
    HttpResponse res = http.send(req);
    // System.debug(res.getStatusCode() + ': ' + res.getBody());
    if (res.getStatusCode() == 401 && !retry)
      throw new AccessTokenException();
    else if (res.getStatusCode() == 401) {
      res = http.send(req);
    }
    return res;
  }

  /**
   * Method to delete documents from OneDrive by associated Controlled Documents
   * @param recordIds array/list of Controlled Document Ids to delete documents from OneDrive
   * @return void
   * @author Anastasiia Stetsenko
   */
  public static void deleteDocuments(List<Id> recordIds) {
    for (String probablyRecordId : recordIds) {
      try {
        Id.valueOf(probablyRecordId);
      }
      catch (Exception e) {
        return;
      }
    }

    List<Simploud__Controlled_Document__c> controlledDocuments = [
      SELECT OneDrive_URL__c
      FROM Simploud__Controlled_Document__c
      WHERE Id IN :recordIds
    ];

    List<Simploud__Controlled_Document__c> toUpdate = new List<Simploud__Controlled_Document__c>();
    for (Simploud__Controlled_Document__c cd : controlledDocuments) {
      String fileId = getFileId(cd.OneDrive_URL__c);
      if (fileId == null)
        continue;

      string endpoint = 'callout:SharePoint/me/drive/items/{item-id}';
      endpoint = endpoint.replace('{item-id}', fileId);

      HTTPResponse res = sendRequest(
        'DELETE',
        endpoint,
        new Map<String, String>(),
        null,
        null
      );

      if (res.getStatusCode() == 204) {
        cd.OneDrive_URL__c = '';
        cd.OneDrive_Permission__c = '';
        toUpdate.add(cd);
      }
    }
    if (toUpdate.size() != 0) {
      update toUpdate;
    }
  }

  /**
   * Overloaded method to delete documents from OneDrive by document URLs (OneDrive_URL__c field of Controlled Document)
   * @param documentsUrls array/list of document URLs to delete documents from OneDrive
   * @return void
   * @see deleteDocuments(List<Id> recordIds)
   * @author Anastasiia Stetsenko
   */
  public static void deleteDocuments(String[] documentsUrls) {
    for (String url : documentsUrls) {
      if (!url.contains('http')) continue;

      String fileId = getFileId(url);
      if (fileId == null)
        continue;

      string endpoint = 'callout:SharePoint/me/drive/items/{item-id}';
      endpoint = endpoint.replace('{item-id}', fileId);

      if (endpoint == null)
        continue;
        
      HTTPResponse res = sendRequest(
        'DELETE',
        endpoint,
        new Map<String, String>(),
        null,
        null
      );

      if (res.getStatusCode() != 204) {
        throw new CannotDeleteDocumentException('Cannot delete document: ' + res.getStatusCode() + ' | ' + res.getBody());
      }
    }
  }

  /**
   * Downloads document from OneDrive and creates new version of the document in Salesforce
   * @param recordId Id of the Controlled Document record
   * @return void
   * @author Anastasiia Stetsenko
   */
  public static void getDocuments(string recordId) {
    try {
      Simploud__Controlled_Document__c controlledDocument = [
        SELECT
          Id,
          OneDrive_URL__c,
          (SELECT Id, ContentDocumentId FROM ContentDocumentLinks),
          Simploud__Version__c
        FROM Simploud__Controlled_Document__c
        WHERE Id = :recordId
      ];

      ContentDocumentLink contentDocumentLink = controlledDocument.ContentDocumentLinks[0];
      ContentDocument contentDocument = [
        SELECT Id, Title, FileExtension
        FROM ContentDocument
        WHERE Id = :contentDocumentLink.ContentDocumentId
      ];

      ContentVersion[] versions = [
        SELECT VersionData, Title, ContentDocumentId, FileExtension
        FROM ContentVersion
        WHERE ContentDocumentId = :contentDocument.Id
        ORDER BY CreatedDate
      ];

      String fileId = getFileId(controlledDocument.OneDrive_URL__c);

      string endpoint = 'callout:SharePoint/me/drive/items/{item-id}/content';
      endpoint = endpoint.replace('{item-id}', fileId);

      HTTPResponse res = sendRequest(
        'GET',
        endpoint,
        new Map<String, String>(),
        null,
        null
      );

      string location = res.getHeader('Location'); // OneDrive returns temporary link to download the document in the header 'Location'

      res = sendRequest('GET', location, new Map<String, String>(), null, null);

      if (res.getStatusCode() == 200) {
        ContentVersion cv = createContentVersion(
          versions[0].Title + '.' + versions[0].FileExtension,
          res.getBodyAsBlob(),
          contentDocument.Id
        );
        cv.ReasonForChange = 'Upload SharePoint Document';
        insert cv;

        controlledDocument.Simploud__Version__c += 0.1;
        update controlledDocument;
      }
    } catch (Exception e) {
      System.debug(e.getMessage() + ' Line: ' + e.getLineNumber());
    }
  }

  /**
   * Uploads documents to OneDrive and updates Controlled Document records with OneDrive URLs
   * @param recordIds list of id of the Controlled Document records to upload documents to OneDrive
   * @return void
   * @author Anastasiia Stetsenko
   */
  public static void uploadDocuments(List<Id> recordIds) {
    Map<Id, Simploud__Controlled_Document__c> controlledDocuments = new Map<Id, Simploud__Controlled_Document__c>(
      [
        SELECT Id, (SELECT Id, ContentDocumentId FROM ContentDocumentLinks)
        FROM Simploud__Controlled_Document__c
        WHERE Id IN :recordIds
      ]
    );

    Map<Id, Simploud__Controlled_Document__c> ids = new Map<Id, Simploud__Controlled_Document__c>();
    for (Simploud__Controlled_Document__c cd : controlledDocuments.values()) {
      ids.put(cd.ContentDocumentLinks[0].ContentDocumentId, cd);
    }
    Map<Id, Simploud__Controlled_Document__c> contentDocuments = new Map<Id, Simploud__Controlled_Document__c>();
    List<Id> IdFromSet = new List<Id>(ids.keySet());
    for (ContentDocument cd : [
      SELECT Id, Title, FileExtension
      FROM ContentDocument
      WHERE Id IN :IdFromSet
    ]) {
      contentDocuments.put(cd.Id, ids.get(cd.Id));
    }

    Map<ContentVersion, Simploud__Controlled_Document__c> versions = new Map<ContentVersion, Simploud__Controlled_Document__c>();
    
    for (ContentVersion cv : [
      SELECT Id, VersionData, Title, ContentDocumentId, FileExtension
      FROM ContentVersion
      WHERE ContentDocumentId IN :contentDocuments.keySet() AND FileExtension IN ('docx', 'doc', 'xls', 'xlsx', 'ppt', 'pptx') 
      ORDER BY CreatedDate DESC
    ]) {
      if (versions.values().contains(contentDocuments.get(cv.ContentDocumentId))) continue;
      versions.put(cv, contentDocuments.get(cv.ContentDocumentId));
    }

    List<Simploud__Controlled_Document__c> toUpdate = new List<Simploud__Controlled_Document__c>();
    for (ContentVersion attach : versions.keySet()) {
      Blob docBody = WordUtils.enableTrackChangesForDocument(attach.Id);
      Simploud__Controlled_Document__c cd = uploadFile(
        docBody,
        attach.Title,
        attach.FileExtension,
        versions.get(attach)
      );

      if (cd != null) {
        String embedLink = generateEmbedLink(cd.OneDrive_URL__c, cd.Id);
        cd.OneDrive_Embed_URL__c = embedLink + '?action=embedview';

        toUpdate.add(cd);

        cd.OneDrive_Owner_Shared_Link__c = SharePointPermissionsApiHandler.addPermissionToOwner(
          cd.OneDrive_URL__c,
          cd.Id
        );
      }
    }

    if (toUpdate.size() != 0) {
      update toUpdate;
    }
  }

  /**
   * Utility method for uploadDocuments. Uploads a single document to OneDrive and updates Controlled Document record with OneDrive URL
   * @param versionData content of the document
   * @param title name for the document
   * @param extn file extension
   * @param record Controlled Document record to update with OneDrive URL
   * @return  `Simploud__Controlled_Document__c` updated record
   * @author Anastasiia Stetsenko
   */
  public static Simploud__Controlled_Document__c uploadFile(
    blob versionData,
    string title,
    string extn,
    Simploud__Controlled_Document__c record
  ) {
    String attachmentBody = EncodingUtil.base64Encode(versionData);

    String filename = 'document_' + record.Id;

    try {
      filename = generateFileName(record.Id);
    } catch (Exception e) {
    }

    string contentType = returnContentType(extn);

    string endpointUrl = 'callout:SharePoint/me/drive/root:/Review/{file}:/content';
    string file = EncodingUtil.URLENCODE(filename, 'UTF-8').replaceAll('\\+', '_');
    endpointUrl = endpointUrl.replace('{file}', file + '.' + extn);

    Map<String, String> headers = new Map<String, String>();
    headers.put('Content-Encoding', 'UTF-8');
    headers.put('Content-type', contentType);
    headers.put('accept', 'application/json');

    HTTPResponse res = sendRequest(
      'PUT',
      endpointUrl,
      headers,
      null,
      versionData
    );

    if (res.getStatusCode() == 201 || res.getStatusCode() == 200) {
      record.OneDrive_URL__c = saveLink(res.getBody()).toLowerCase();
      return record;
    }

    return null;
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
      throw new DocumentNameFormatException(
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
      throw new DocumentNotFoundException();
    }

    if (doc == null) {
      throw new DocumentNotFoundException();
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
   * Generates embed link (for iFrame) for the document using the OneDrive API
   * @param documentUrl OneDrive_URL__c
   * @param documentId Id of the Controlled Document to update
   * @return  `String` embed link for the document or null if request failed (e.g. 401 error)
   * @author Anastasiia Stetsenko
   */
  public static String generateEmbedLink(
    String documentUrl,
    String documentId
  ) {
    String id = getFileId(documentUrl);

    String endpoint = 'callout:SharePoint/me/drive/items/{item-id}/createLink';
    endpoint = endpoint.replace('{item-id}', id);

    Map<String, String> headers = new Map<String, String>();
    headers.put('Content-type', 'application/json');
    headers.put('accept', 'application/json');

    String body = '{"type": "view", "scope": "organization"}';

    HTTPResponse res = sendRequest('POST', endpoint, headers, body, null);

    if (res.getStatusCode() == 201 || res.getStatusCode() == 200) {
      return res.getBody().substringAfter('"webUrl":"').substringBefore('"');
    }

    throw new CannotGenerateEmbedLinkException();
  }

  /**
   * Utility method for link formatting
   * @param body response from OneDrive API
   * @return  `String` the link
   * @author Anastasiia Stetsenko
   */
  public static String saveLink(String body) {
    String link = body.substringAfter('"@microsoft.graph.downloadUrl":"')
      .toLowerCase();
    link = link.substringBefore('&tempauth');
    return link;
  }

  /**
   * Utility method for getting file id from the OneDrive URL
   * @param url OneDrive_URL__c
   * @return  `String` file id in OneDrive
   * @author Anastasiia Stetsenko
   */
  public static String getFileId(string url) {
    if (url == null)
      return null;
    url = url.toLowerCase();
    String fileId = url.substringAfter('download.aspx?uniqueid=');
    fileId = fileId.substringBefore('&');
    return fileId;
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

  /**
   * Overload for createContentVersion. Creates ContentVersion record without ContentDocumentId
   * @param name file name
   * @param body file body
   * @return  `ContentVersion`
   * @author Danyil Mahalias
   */
  public static ContentVersion createContentVersion(String name, Blob body) {
    ContentVersion contentVersion = new ContentVersion();
    contentVersion.ContentLocation = 'S'; // S = Stored in Salesforce
    contentVersion.PathOnClient = name;
    contentVersion.Title = name;
    contentVersion.VersionData = body;
    return contentVersion;
  }

  /**
   * Creates ContentDocumentLink record
   * @param contentDocumentId Id of the Content Document to associate the file with
   * @param parentId Id of any record to associate the Content Document with
   * @return  `ContentDocumentLink`
   * @author Danyil Mahalias
   */
  public static ContentDocumentLink createContentDocumentLink(
    Id contentDocumentId,
    Id parentId
  ) {
    ContentDocumentLink contentDocumentLink = new ContentDocumentLink();
    contentDocumentLink.ContentDocumentId = contentDocumentId;
    contentDocumentLink.LinkedEntityId = parentId;
    contentDocumentLink.ShareType = 'I'; // Inferred permission
    contentDocumentLink.Visibility = 'AllUsers';
    return contentDocumentLink;
  }
}
