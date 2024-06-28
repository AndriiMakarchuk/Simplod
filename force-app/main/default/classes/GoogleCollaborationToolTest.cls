@isTest
public with sharing class GoogleCollaborationToolTest {
    // @TestSetup
    // static void makeData() {
    //     Simploud__SimploudOrgSettings__c settings = Simploud__SimploudOrgSettings__c.getOrgDefaults();
    //     settings.Collaboration_Tool__c = 'Google';
    //     settings.Simploud__IgnoreConfigTrigger__c = true;
    //     upsert settings;

    //     Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator'];

    //     User user = new User();
    //     user.FirstName = 'Test';
    //     user.LastName = 'User';
    //     user.Email = 'testemailunique@unique.com';
    //     user.Username = 'testemailunique@unique.com';
    //     user.Alias = 'test';
    //     user.ProfileId = p.Id;
    //     user.TimeZoneSidKey = 'America/Los_Angeles';
    //     user.LocaleSidKey = 'en_US';
    //     user.EmailEncodingKey = 'UTF-8';
    //     user.LanguageLocaleKey = 'en_US';
    //     insert user;

    //     Simploud__Compliance_Configuration__c configDraft = new Simploud__Compliance_Configuration__c();
    //     configDraft.Simploud__Enable_Collaboration__c = true;
    //     configDraft.Simploud__Required_Participants__c = 'Field:OwnerId';
    //     configDraft.Simploud__Upload_Buttons__c = 'Complete Draft;';
    //     configDraft.Simploud__On_Status_Value__c = 'Draft';
    //     configDraft.Simploud__Object_API_Name__c = 'Simploud__Controlled_Document__c';
    //     configDraft.Simploud__Flow_Type__c = 'Status Changing';
    //     insert configDraft;

    //     Simploud__Compliance_Configuration__c configReview = new Simploud__Compliance_Configuration__c();
    //     configReview.Simploud__Enable_Collaboration__c = true;
    //     configReview.Simploud__Required_Participants__c = 'Participant:Reviewer';
    //     configReview.Simploud__Upload_Buttons__c = 'Complete Draft;';
    //     configReview.Simploud__On_Status_Value__c = 'Review';
    //     configReview.Simploud__Object_API_Name__c = 'Simploud__Controlled_Document__c';
    //     configReview.Simploud__Flow_Type__c = 'Status Changing';
    //     insert configReview;
    // }

    // @isTest
    // public static void constructorTest() {
    //     Simploud__SimploudOrgSettings__c settings = Simploud__SimploudOrgSettings__c.getOrgDefaults();
    //     settings.Collaboration_Tool__c = 'SharePoint';
    //     update settings;

    //     DocumentCollaborationManager manager = new DocumentCollaborationManager();
    //     System.assertEquals('SharePoint', manager.collaborationToolName);

    //     settings.Collaboration_Tool__c = 'Google';
    //     update settings;

    //     manager = new DocumentCollaborationManager();
    //     System.assertEquals('Google', manager.collaborationToolName);

    //     settings.Collaboration_Tool__c = 'Invalid Tool';
    //     update settings;

    //     try {
    //         manager = new DocumentCollaborationManager();
    //         System.assert(false, 'Expected CollaborationToolException to be thrown');
    //     } catch (DocumentCollaborationManager.CollaborationToolException e) {
    //         System.assertEquals('Collaboration tool not supported', e.getMessage());
    //     }

    //     settings.Collaboration_Tool__c = 'Google';
    //     update settings;
    // }

    // @isTest
    // public static void deleteDocumentsTest() {
    //     Test.setMock(HttpCalloutMock.class, new GoogleDocsHttpMockGenerator());

    //     Simploud__Controlled_Document__c cd = new Simploud__Controlled_Document__c();
    //     cd.Name = 'test';
    //     cd.Google_Docs_URL__c = 'https://docs.google.com/document/d/1';
    //     insert cd;

    //     Test.startTest();
    //     DocumentCollaborationManager manager = new DocumentCollaborationManager();
    //     manager.deleteDocuments(new List<String> { cd.Google_Docs_URL__c });
    //     Test.stopTest();

    //     Simploud__Controlled_Document__c updatedDoc = [SELECT Id, Google_Docs_URL__c, File_In_Cloud__c FROM Simploud__Controlled_Document__c WHERE Id = :cd.Id];
    //     system.assertEquals(null, updatedDoc.Google_Docs_URL__c);
    //     system.assertEquals(false, updatedDoc.File_In_Cloud__c);

    //     delete updatedDoc;
    // }

    // @isTest 
    // public static void uploadFilesTest() {
    //     string filecontent = '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';

    //     Simploud__Controlled_Document__c cd = new Simploud__Controlled_Document__c();
    //     cd.Name = 'test';
    //     cd.Use_Document_Collaboration_Tool__c = 'Yes';
    //     insert cd;

    //     ContentVersion cv = SharePointApiHandler.createContentVersion('test.docx', EncodingUtil.base64Decode(filecontent));
    //     insert cv;
    //     ContentVersion insertedCV = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id=:cv.Id WITH SECURITY_ENFORCED];
    //     ContentDocumentLink cdl = SharePointApiHandler.createContentDocumentLink(insertedCV.ContentDocumentId, cd.Id);
    //     insert cdl;

    //     Id[] recordIds = new Id[] { cd.Id };

    //     Test.setMock(HttpCalloutMock.class, new GoogleDocsHttpMockGenerator());

    //     Test.startTest();
    //     DocumentCollaborationManager manager = new DocumentCollaborationManager();
    //     manager.uploadFiles(recordIds);
    //     Test.stopTest();

    //     Simploud__Controlled_Document__c updatedDoc = [SELECT Id, Google_Docs_URL__c, File_In_Cloud__c FROM Simploud__Controlled_Document__c WHERE Id = :cd.Id];
    //     system.assertEquals('https://docs.google.com/document/d/1', updatedDoc.Google_Docs_URL__c);
    //     system.assertEquals(true, updatedDoc.File_In_Cloud__c);

    //     delete updatedDoc;
    // }

    // @isTest
    // public static void uploadFile_FileExistsTest() {
    //     string filecontent = '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';

    //     Simploud__Controlled_Document__c cd = new Simploud__Controlled_Document__c();
    //     cd.Name = 'test';
    //     cd.Use_Document_Collaboration_Tool__c = 'Yes';
    //     cd.Google_Docs_URL__c = 'https://docs.google.com/document/d/3';
    //     cd.File_In_Cloud__c = true;
    //     insert cd;

    //     ContentVersion cv = SharePointApiHandler.createContentVersion('test.docx', EncodingUtil.base64Decode(filecontent));
    //     insert cv;
    //     ContentVersion insertedCV = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id=:cv.Id WITH SECURITY_ENFORCED];
    //     ContentDocumentLink cdl = SharePointApiHandler.createContentDocumentLink(insertedCV.ContentDocumentId, cd.Id);
    //     insert cdl;

    //     Id[] recordIds = new Id[] { cd.Id };

    //     Test.setMock(HttpCalloutMock.class, new GoogleDocsHttpMockGenerator());

    //     Test.startTest();
    //     DocumentCollaborationManager manager = new DocumentCollaborationManager();
    //     manager.uploadFiles(recordIds);
    //     Test.stopTest();

    //     Simploud__Controlled_Document__c updatedDoc = [SELECT Id, Google_Docs_URL__c, File_In_Cloud__c FROM Simploud__Controlled_Document__c WHERE Id = :cd.Id];
    //     system.assertEquals('https://docs.google.com/document/d/3', updatedDoc.Google_Docs_URL__c);
    //     system.assertEquals(true, updatedDoc.File_In_Cloud__c);

    //     delete updatedDoc;
    // }

    // @isTest
    // public static void saveMinorVersionTest() {
    //     Simploud__Controlled_Document__c cd = new Simploud__Controlled_Document__c();
    //     cd.Name = 'test';
    //     cd.Google_Docs_URL__c = 'https://docs.google.com/document/d/1';
    //     cd.Use_Document_Collaboration_Tool__c = 'Yes';
    //     insert cd;

    //     ContentVersion cv = SharePointApiHandler.createContentVersion('test.docx', Blob.valueOf('test'));
    //     insert cv;
    //     ContentVersion insertedCV = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id=:cv.Id WITH SECURITY_ENFORCED];
    //     ContentDocumentLink cdl = SharePointApiHandler.createContentDocumentLink(insertedCV.ContentDocumentId, cd.Id);
    //     insert cdl;

    //     Test.setMock(HttpCalloutMock.class, new GoogleDocsHttpMockGenerator());

    //     Test.startTest();
    //     DocumentCollaborationManager manager = new DocumentCollaborationManager();
    //     manager.saveMinorVersion(new Map<Id, String> { cd.Id => 'Draft' });
    //     Test.stopTest();

    //     Simploud__Controlled_Document__c updatedCd = [SELECT Id, (SELECT Id, ContentDocumentId FROM ContentDocumentLinks) FROM Simploud__Controlled_Document__c WHERE Id=:cd.Id];
    //     ContentDocumentLink contentDocumentLink = updatedCd.ContentDocumentLinks[0];
    //     ContentDocument contentDocument = [SELECT Id, Title, FileExtension FROM ContentDocument WHERE Id = :contentDocumentLink.ContentDocumentId];

    //     List<ContentVersion> versions=[SELECT VersionData,Title,ContentDocumentId,FileExtension FROM ContentVersion WHERE ContentDocumentId = :contentDocument.Id ORDER BY CreatedDate];

    //     System.assertEquals('test', versions[versions.size() - 1].VersionData.toString());
    // }

    // @isTest
    // public static void updatePermissionsTest() {
    //     User u = [SELECT Id FROM User WHERE Username = 'testemailunique@unique.com'];

    //     Simploud__Controlled_Document__c cd = new Simploud__Controlled_Document__c();
    //     cd.Name = 'test';
    //     cd.Google_Docs_URL__c = 'https://docs.google.com/document/d/1';
    //     cd.Google_Docs_Permissions__c = u.Id + ':234;' + UserInfo.getUserId() + ':2345678;';
    //     cd.Use_Document_Collaboration_Tool__c = 'Yes';
    //     cd.OwnerId = UserInfo.getUserId();

    //     insert cd;

    //     Simploud__Document_Participant__c part = new Simploud__Document_Participant__c();
    //     part.Simploud__Document__c = cd.Id;
    //     part.Simploud__Participant__c = u.Id;
    //     insert part;

    //     Test.setMock(HttpCalloutMock.class, new GoogleDocsHttpMockGenerator());

    //     Test.startTest();
    //     DocumentCollaborationManager manager = new DocumentCollaborationManager();
    //     manager.updatePermissions(new Id[] { cd.Id });
    //     Test.stopTest();

    //     Simploud__Controlled_Document__c updatedDoc = [SELECT Id, Google_Docs_Permissions__c FROM Simploud__Controlled_Document__c WHERE Id = :cd.Id];
    //     system.assertEquals(true , updatedDoc.Google_Docs_Permissions__c.contains(u.Id));
    // }

    // @isTest
    // public static void updateViewonlyTest() {
    //     Simploud__Controlled_Document__c cd = new Simploud__Controlled_Document__c();
    //     cd.Name = 'test';
    //     cd.Google_Docs_URL__c = 'https://docs.google.com/document/d/1';
    //     cd.Use_Document_Collaboration_Tool__c = 'Yes';
    //     insert cd;

    //     User u = [SELECT Id FROM User WHERE Username = 'testemailunique@unique.com'];

    //     Simploud__Document_Participant__c part = new Simploud__Document_Participant__c();
    //     part.Simploud__Document__c = cd.Id;
    //     part.Simploud__Participant__c = u.Id;
    //     insert part;

    //     Test.setMock(HttpCalloutMock.class, new GoogleDocsHttpMockGenerator());

    //     Test.startTest();
    //     DocumentCollaborationManager manager = new DocumentCollaborationManager();
    //     manager.updateViewonly(new Id[] { cd.Id });
    //     Test.stopTest();

    //     Simploud__Document_Participant__c updatedPart = [SELECT Id, ViewOnly__c FROM Simploud__Document_Participant__c WHERE Id = :part.Id];
    //     system.assertEquals(false, updatedPart.ViewOnly__c);
    // }

    // @isTest
    // public static void clearViewonlyTest() {
    //     Simploud__Controlled_Document__c cd = new Simploud__Controlled_Document__c();
    //     cd.Name = 'test';
    //     cd.Google_Docs_URL__c = 'https://docs.google.com/document/d/1';
    //     cd.Use_Document_Collaboration_Tool__c = 'Yes';
    //     insert cd;

    //     User u = [SELECT Id FROM User WHERE Username = 'testemailunique@unique.com'];

    //     Simploud__Document_Participant__c part = new Simploud__Document_Participant__c();
    //     part.Simploud__Document__c = cd.Id;
    //     part.Simploud__Participant__c = u.Id;
    //     insert part;

    //     Test.setMock(HttpCalloutMock.class, new GoogleDocsHttpMockGenerator());

    //     Test.startTest();
    //     DocumentCollaborationManager manager = new DocumentCollaborationManager();
    //     manager.clearViewonly(new Id[] { cd.Id });
    //     Test.stopTest();

    //     Simploud__Document_Participant__c updatedPart = [SELECT Id, ViewOnly__c FROM Simploud__Document_Participant__c WHERE Id = :part.Id];
    //     system.assertEquals(false, updatedPart.ViewOnly__c);
    // }

    // @isTest
    // public static void markFilesUploadedTest() {
    //     Simploud__Controlled_Document__c doc = new Simploud__Controlled_Document__c();
    //     doc.Name = 'test';
    //     doc.Google_Docs_URL__c = 'https://docs.google.com/document/d/1';
    //     doc.Use_Document_Collaboration_Tool__c = 'Yes';
    //     insert doc;

    //     Test.startTest();
    //     DocumentCollaborationManager manager = new DocumentCollaborationManager();
    //     manager.markFilesUploaded(new Id[] { doc.Id });
    //     Test.stopTest();

    //     Simploud__Controlled_Document__c updatedDoc = [SELECT Id, File_In_Cloud__c FROM Simploud__Controlled_Document__c WHERE Id = :doc.Id];

    //     system.assertEquals(false, updatedDoc.File_In_Cloud__c);
    // }

    // /* GoogleEditorController */

    // @isTest
    // public static void getEditorUrlTest() {
    //     Simploud__Controlled_Document__c doc = new Simploud__Controlled_Document__c();
    //     doc.Name = 'test';
    //     doc.Google_Docs_URL__c = 'https://docs.google.com/document/d/1';
    //     doc.Use_Document_Collaboration_Tool__c = 'Yes';
    //     insert doc;

    //     Test.startTest();
    //     String url = GoogleEditorController.getEditorUrl(doc.Id);
    //     Test.stopTest();

    //     system.assertEquals(doc.Google_Docs_URL__c, url);
    // }

    // @isTest
    // public static void getDownloadLinkTest() {
    //     Simploud__Controlled_Document__c cd = new Simploud__Controlled_Document__c();
    //     cd.Name = 'test';
    //     cd.Google_Docs_URL__c = 'https://docs.google.com/document/d/1';
    //     cd.Use_Document_Collaboration_Tool__c = 'Yes';
    //     insert cd;

    //     ContentVersion cv = SharePointApiHandler.createContentVersion('test.docx', Blob.valueOf('test'));
    //     insert cv;
    //     ContentVersion insertedCV = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id=:cv.Id WITH SECURITY_ENFORCED];
    //     ContentDocumentLink cdl = SharePointApiHandler.createContentDocumentLink(insertedCV.ContentDocumentId, cd.Id);
    //     insert cdl;

    //     Test.startTest();
    //     String url = GoogleEditorController.getDownloadLink(cd.Id);
    //     Test.stopTest();

    //     system.assertEquals('https://docs.google.com/document/d/1/export?format=docx', url);
    // }

    // @isTest
    // public static void saveDocumentTest() {
    //     Simploud__Controlled_Document__c cd = new Simploud__Controlled_Document__c();
    //     cd.Name = 'test';
    //     cd.Google_Docs_URL__c = 'https://docs.google.com/document/d/1';
    //     cd.Use_Document_Collaboration_Tool__c = 'Yes';
    //     insert cd;

    //     ContentVersion cv = SharePointApiHandler.createContentVersion('test.docx', Blob.valueOf('test'));
    //     insert cv;
    //     ContentVersion insertedCV = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id=:cv.Id WITH SECURITY_ENFORCED];
    //     ContentDocumentLink cdl = SharePointApiHandler.createContentDocumentLink(insertedCV.ContentDocumentId, cd.Id);
    //     insert cdl;

    //     Test.setMock(HttpCalloutMock.class, new GoogleDocsHttpMockGenerator());

    //     Test.startTest();
    //     GoogleEditorController.saveDocument(cd.Id);
    //     Test.stopTest();

    //     Simploud__Controlled_Document__c updatedCd = [SELECT Id, (SELECT Id, ContentDocumentId FROM ContentDocumentLinks) FROM Simploud__Controlled_Document__c WHERE Id=:cd.Id];
    //     ContentDocumentLink contentDocumentLink = updatedCd.ContentDocumentLinks[0];
    //     ContentDocument contentDocument = [SELECT Id, Title, FileExtension FROM ContentDocument WHERE Id = :contentDocumentLink.ContentDocumentId];

    //     List<ContentVersion> versions=[SELECT VersionData,Title,ContentDocumentId,FileExtension FROM ContentVersion WHERE ContentDocumentId = :contentDocument.Id ORDER BY CreatedDate];

    //     System.assertEquals('Hello World', versions[versions.size() - 1].VersionData.toString());
    // }

    // /* GoogleDocsPermissionApiHandler */

    // @isTest
    // public static void deletePermissionsForUserTest() {
    //     User u = [SELECT Id FROM User WHERE Username = 'testemailunique@unique.com'];

    //     Simploud__Controlled_Document__c cd = new Simploud__Controlled_Document__c();
    //     cd.Name = 'test';
    //     cd.Google_Docs_URL__c = 'https://docs.google.com/document/d/1';
    //     cd.Google_Docs_Permissions__c = u.Id + ':234;' + UserInfo.getUserId() + ':2345678;';
    //     cd.Use_Document_Collaboration_Tool__c = 'Yes';
    //     cd.OwnerId = UserInfo.getUserId();

    //     insert cd;

    //     Simploud__Document_Participant__c part = new Simploud__Document_Participant__c();
    //     part.Simploud__Document__c = cd.Id;
    //     part.Simploud__Participant__c = u.Id;
    //     insert part;

    //     Test.setMock(HttpCalloutMock.class, new GoogleDocsHttpMockGenerator());

    //     Test.startTest();
    //     String result = GoogleDocsPermissionApiHandler.deletePermissionsForUser(cd.Id, u.Id);
    //     Test.stopTest();    

    //     system.assertEquals(UserInfo.getUserId() + ':2345678;', result);
    // }
}