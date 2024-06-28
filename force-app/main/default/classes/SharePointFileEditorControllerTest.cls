@isTest
public with sharing class SharePointFileEditorControllerTest {
    @TestSetup
    static void makeData(){
        Simploud__SimploudOrgSettings__c settings = new Simploud__SimploudOrgSettings__c();
        settings.Simploud__IgnoreConfigTrigger__c = true;
        insert settings;

        Simploud__Controlled_Document__c doc = new Simploud__Controlled_Document__c();
        doc.Name = 'Test';
        doc.OneDrive_URL__c = 'https://compliansystems-my.sharepoint.com/personal/peeklogic_simploud_com/_layouts/15/download.aspx?uniqueid=3f54d3c2-3177-41f9-b067-4c411ef8b18a&translate=false';
        doc.OneDrive_Owner_Shared_Link__c = 'testowner';
        insert doc;

        ContentVersion cv = SharePointApiHandler.createContentVersion('test.docx', Blob.valueOf('test'));
        insert cv;
        ContentVersion insertedCV = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id=:cv.Id WITH SECURITY_ENFORCED];
        ContentDocumentLink cdl = SharePointApiHandler.createContentDocumentLink(insertedCV.ContentDocumentId, doc.Id);
        insert cdl;

        String uniqueUserName = 'standarduser' + DateTime.now().getTime() + '@testorg.com';
        // This code runs as the system user
        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator'];
        User u = new User(Alias = 'standt', Email='standarduser@testorg.com',
        EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
        LocaleSidKey='en_US', ProfileId = p.Id,
        TimeZoneSidKey='America/Los_Angeles',
         UserName=uniqueUserName);
         u.File_Admin__c = true;
        insert u;

        Simploud__Document_Participant__c part = new Simploud__Document_Participant__c();
        part.Simploud__Document__c = doc.Id;
        part.Simploud__Participant__c = u.Id;
        part.OneDrive_Shared_Link__c = 'testlink';
        insert part;
    }

    @isTest
    public static void getEmbedUrlTest() {
        Simploud__Controlled_Document__c doc = [SELECT Id FROM Simploud__Controlled_Document__c LIMIT 1];

        Test.startTest();
        String embedUrl = SharePointFileEditorController.getEmbedUrl(doc.Id);
        Test.stopTest();

        system.assertEquals(
            'https://compliansystems-my.sharepoint.com/:w:/r/personal/peeklogic_simploud_com/_layouts/15/Doc.aspx?sourcedoc={3f54d3c2-3177-41f9-b067-4c411ef8b18a}&translate=false&file=test.docx.docx&action=embedview',
            embedUrl
        );
    }

    @isTest
    public static void getRecordNameTest() {
        Simploud__Controlled_Document__c doc = [SELECT Id, Name FROM Simploud__Controlled_Document__c LIMIT 1];

        Test.startTest();
        String recordName = SharePointFileEditorController.getRecordName(doc.Id);
        Test.stopTest();

        system.assertEquals(
            'Test',
            recordName
        );
    }

    @isTest
    public static void getDownloadLinkTest() {
        Simploud__Controlled_Document__c doc = [SELECT Id FROM Simploud__Controlled_Document__c LIMIT 1];

        Test.startTest();
        String downloadLink = SharePointFileEditorController.getDownloadLink(doc.Id);
        Test.stopTest();

        system.assertEquals(
            'https://compliansystems-my.sharepoint.com/personal/peeklogic_simploud_com/_layouts/15/download.aspx?uniqueid=3f54d3c2-3177-41f9-b067-4c411ef8b18a&translate=false',
            downloadLink
        );
    }

    @isTest
    public static void getFileMimeTypeTest() {
        Simploud__Controlled_Document__c doc = [SELECT Id FROM Simploud__Controlled_Document__c LIMIT 1];

        Test.startTest();
        String fileMimeType = SharePointFileEditorController.getFileMimeType(doc.Id);
        Test.stopTest();

        system.assertEquals(
            'word',
            fileMimeType
        );
    }

    @isTest
    public static void getFileNameTest() {
        Simploud__Controlled_Document__c doc = [SELECT Id FROM Simploud__Controlled_Document__c LIMIT 1];

        Test.startTest();
        String fileName = SharePointFileEditorController.getFilename(doc.Id);
        Test.stopTest();

        system.assertEquals(
            'test.docx.docx',
            fileName
        );
    }

    @isTest
    public static void getEditorUrlTest() {
        Simploud__Controlled_Document__c doc = [SELECT Id FROM Simploud__Controlled_Document__c LIMIT 1];

        Test.startTest();
        String editorUrl = SharePointFileEditorController.getEditorUrl(doc.Id);
        Test.stopTest();

        system.assertEquals(
            'testowner',
            editorUrl
        );
    }

    @isTest
    public static void getEditorUrlTest_AnotherUser() {
        Simploud__Controlled_Document__c doc = [SELECT Id FROM Simploud__Controlled_Document__c LIMIT 1];

        User u = [SELECT Id FROM User WHERE Alias='standt' LIMIT 1];

        String editorUrl;
        System.runAs(u) {
            Test.startTest();
            editorUrl = SharePointFileEditorController.getEditorUrl(doc.Id);
            Test.stopTest();
        }

        system.assertEquals(
            'testlink',
            editorUrl
        );
    }

    @isTest
    public static void isUserHasAccessToDocumentTest() {
        Simploud__Controlled_Document__c doc = [SELECT Id FROM Simploud__Controlled_Document__c LIMIT 1];

        Test.startTest();
        Boolean hasAccess = SharePointFileEditorController.isUserHasAccessToDocument(doc.Id);
        Test.stopTest();

        system.assertEquals(
            true,
            hasAccess
        );
    }

    @isTest
    public static void getDocumentStatusTest() {
        Simploud__Controlled_Document__c doc = [SELECT Id FROM Simploud__Controlled_Document__c LIMIT 1];

        Test.startTest();
        String status = SharePointFileEditorController.getDocumentStatus(doc.Id);
        Test.stopTest();

        system.assertEquals(
            'Draft',
            status
        );
    }

    @isTest 
    public static void getOneDriveDirectUrlTest() {
        Simploud__Controlled_Document__c doc = [SELECT Id FROM Simploud__Controlled_Document__c LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new HttpMock(200, '{"webUrl": "https://test.com/_layouts/", "name": "test.docx", "id": "123456"}'));
        Test.startTest();
        String url = SharePointFileEditorController.getOneDriveDirectUrl(doc.Id);
        Test.stopTest();

        system.assertEquals(
            'https://test.com//Documents/Review/test.docx',
            url
        );
    }

    private class HttpMock implements HttpCalloutMock {
        private Integer code;
        private String body;

        public HttpMock(Integer code, String body) {
            this.code = code;
            this.body = body;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(code);
            res.setBody(body);
            return res;
        }
    }
}