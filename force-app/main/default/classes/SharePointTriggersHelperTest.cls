@isTest
public with sharing class SharePointTriggersHelperTest {
    @TestSetup
    static void makeData(){
        Simploud__SimploudOrgSettings__c settings = new Simploud__SimploudOrgSettings__c();
        settings.Simploud__IgnoreConfigTrigger__c = true;
        insert settings;

        Simploud__Controlled_Document__c doc = new Simploud__Controlled_Document__c();
        doc.Name = 'Test';
        doc.OneDrive_URL__c = 'https://compliansystems-my.sharepoint.com/personal/peeklogic_simploud_com/_layouts/15/download.aspx?uniqueid=3f54d3c2-3177-41f9-b067-4c411ef8b18a&translate=false';
        doc.OneDrive_Owner_Shared_Link__c = 'testowner';
        doc.OneDrive_Permission__c = 'roles: (read), id: 35765ead-7251-4674-9dfa-a933e97591d2;roles: (write), id: 6259cd12-b7a0-4d33-81a8-2aa9827b552d;roles: (write), id: aTowIy5mfG1lbWJlcnNoaXB8c3VsaW1hbkBzaW1wbG91ZC5jb20;';
        doc.Simploud__Button_Clicked__c = 'Complete Draft:' + UserInfo.getUserId();
        insert doc;

        Simploud__Controlled_Document__c doc1 = new Simploud__Controlled_Document__c();
        doc1.Name = 'Test1';
        doc1.OneDrive_URL__c = 'https://compliansystems-my.sharepoint.com/personal/peeklogic_simploud_com/_layouts/15/download.aspx?uniqueid=3f54d3c2-3177-41f9-b067-4c411ef8b18a&translate=false';
        doc1.OneDrive_Owner_Shared_Link__c = 'testowner';
        doc1.OneDrive_Permission__c = 'roles: (read), id: 35765ead-7251-4674-9dfa-a933e97591d2;roles: (write), id: 6259cd12-b7a0-4d33-81a8-2aa9827b552d;roles: (write), id: aTowIy5mfG1lbWJlcnNoaXB8c3VsaW1hbkBzaW1wbG91ZC5jb20;';
        insert doc1;

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
        part.Simploud__Participant_Type__c = 'Reviewer';
        insert part;

        Simploud__Document_Participant__c part1 = new Simploud__Document_Participant__c();
        part1.Simploud__Document__c = doc.Id;
        part1.Simploud__Participant__c = UserInfo.getUserId();
        part1.OneDrive_Shared_Link__c = 'testlink';
        part1.Simploud__Participant_Type__c = 'Approver';
        insert part1;

        Simploud__Compliance_Configuration__c configDraft = new Simploud__Compliance_Configuration__c();
        configDraft.Simploud__Enable_Collaboration__c = true;
        configDraft.Simploud__Required_Participants__c = 'Field:OwnerId';
        configDraft.Simploud__Upload_Buttons__c = 'Complete Draft;';
        configDraft.Simploud__On_Status_Value__c = 'Draft';
        configDraft.Simploud__Object_API_Name__c = 'Simploud__Controlled_Document__c';
        configDraft.Simploud__Flow_Type__c = 'Status Changing';
        insert configDraft;

        Simploud__Compliance_Configuration__c configReview = new Simploud__Compliance_Configuration__c();
        configReview.Simploud__Enable_Collaboration__c = true;
        configReview.Simploud__Required_Participants__c = 'Participant:Reviewer';
        configReview.Simploud__Upload_Buttons__c = 'Complete Draft;';
        configReview.Simploud__On_Status_Value__c = 'Review';
        configReview.Simploud__Object_API_Name__c = 'Simploud__Controlled_Document__c';
        configReview.Simploud__Flow_Type__c = 'Status Changing';
        insert configReview;
    }

    @isTest
    public static void validateConfigurationTest() {
        Simploud__Compliance_Configuration__c configReview = [SELECT Id, Simploud__Enable_Collaboration__c, Simploud__Required_Participants__c FROM Simploud__Compliance_Configuration__c WHERE Simploud__On_Status_Value__c = 'Review' LIMIT 1];
    
        Test.startTest();
        boolean result = SharePointTriggersHelper.validateConfiguration(configReview);
        Test.stopTest();

        System.assertEquals(true, result);
    }

    @isTest
    public static void groupParticipantsByTypeTest() {
        Simploud__Controlled_Document__c doc = [SELECT Id, (SELECT Id, Simploud__Participant__c, Simploud__Participant_Type__c FROM Simploud__Document_Participants__r) FROM Simploud__Controlled_Document__c LIMIT 1];
        Simploud__Document_Participant__c reviewer = [SELECT Id, Simploud__Participant__c FROM Simploud__Document_Participant__c WHERE Simploud__Participant_Type__c = 'Reviewer' LIMIT 1];

        Test.startTest();
        Map<String, Id[]> result = SharePointTriggersHelper.groupParticipantsByType(doc);
        Test.stopTest();

        System.assertEquals(2, result.size());
        System.assertEquals(new Id[]{ reviewer.Simploud__Participant__c }, result.get('Reviewer'));
    }

    @isTest
    public static void getParticipantIdByFieldTest(){
        Simploud__Controlled_Document__c doc = [SELECT Id, OwnerId FROM Simploud__Controlled_Document__c LIMIT 1];

        Test.startTest();
        Id result = SharePointTriggersHelper.getParticipantIdByField(doc, 'OwnerId');
        Test.stopTest();

        System.assertEquals(doc.OwnerId, result);
    }

    @isTest
    public static void getAccessTypeForPartcipantsTest() {
        Simploud__Controlled_Document__c doc = [SELECT Id, Simploud__Status__c, Simploud__Button_Clicked__c, OwnerId, (SELECT Id, Simploud__Participant__c, Simploud__Participant_Type__c, Viewonly__c FROM Simploud__Document_Participants__r) FROM Simploud__Controlled_Document__c LIMIT 1];
        Simploud__Compliance_Configuration__c[] configs = [SELECT Id, Simploud__Enable_Collaboration__c, Simploud__Required_Participants__c, Simploud__On_Status_Value__c FROM Simploud__Compliance_Configuration__c];

        Test.startTest();
        Map<SharePointTriggersHelper.AccessType, Set<Id>> result = SharePointTriggersHelper.getAccessTypeForPartcipants(doc, configs);
        Test.stopTest();

        System.assertEquals(new Set<Id>{ doc.OwnerId }, result.get(SharePointTriggersHelper.AccessType.EDIT));
    }

    @isTest
    public static void isCollaborationEnabledTest() {
        Test.startTest();
        boolean result = SharePointTriggersHelper.isCollaborationEnabled('Simploud__Controlled_Document__c', 'Draft');
        Test.stopTest();

        System.assertEquals(true, result);
    }

    @isTest
    public static void saveMinorVersionTest() {
        Simploud__Controlled_Document__c[] docs = [SELECT Id, Simploud__Status__c, Simploud__Button_Clicked__c, OwnerId, (SELECT Id, Simploud__Participant__c, Simploud__Participant_Type__c FROM Simploud__Document_Participants__r) FROM Simploud__Controlled_Document__c LIMIT 1];
        Map<Id, String> docIds = new Map<Id, String>{ docs[0].Id => docs[0].Simploud__Status__c };
        
        Test.setMock(HttpCalloutMock.class, new getFileHttpMock());
        Test.startTest();
        SharePointTriggersHelper.saveMinorVersion(docIds);
        Test.stopTest();

        Simploud__Controlled_Document__c docWithCV = [SELECT Id, (SELECT Id, ContentDocumentId FROM ContentDocumentLinks) FROM Simploud__Controlled_Document__c WHERE Id = :docs[0].Id];

        ContentDocumentLink contentDocumentLink = docWithCV.ContentDocumentLinks[0];
        ContentDocument cd = [SELECT Id, LatestPublishedVersionId FROM ContentDocument WHERE Id=:contentDocumentLink.ContentDocumentId WITH SECURITY_ENFORCED];
        ContentVersion[] cv = [SELECT Id, ContentDocumentId, VersionData FROM ContentVersion WHERE ContentDocumentId = :cd.Id];

        Blob body = cv[cv.size() - 1].VersionData;
        String bodyString = body.toString();

        System.assertEquals('test', bodyString);

        Simploud__Controlled_Document__c updatedDoc = [SELECT Id, Simploud__Version__c FROM Simploud__Controlled_Document__c WHERE Id = :docs[0].Id];

        System.assertEquals(0.1, updatedDoc.Simploud__Version__c);
    }

    @isTest
    public static void updatePermissionsTest() {
        Simploud__Controlled_Document__c doc = [SELECT Id FROM Simploud__Controlled_Document__c LIMIT 1];
        Id[] docId = new Id[]{ doc.Id };

        Test.setMock(HttpCalloutMock.class, new UpdatePermissionsHttpMock());
        Test.startTest();
        SharePointTriggersHelper.updatePermissions(docId);
        Test.stopTest();

        Simploud__Controlled_Document__c docAfter = [SELECT Id, OneDrive_URL__c, OneDrive_Owner_Shared_Link__c FROM Simploud__Controlled_Document__c WHERE Id = :doc.Id];
        Simploud__Document_Participant__c[] part = [SELECT Id, OneDrive_Shared_Link__c FROM Simploud__Document_Participant__c WHERE Simploud__Document__c=:doc.Id];
        System.assertEquals('https://compliansystems-my.sharepoint.com/:w:/g/personal/peeklogic_simploud_com/EcLTVD93MflBsGdMQR74sYoBaRcO53ix_srtB0MMhioyaA', part[0].OneDrive_Shared_Link__c);
    }

    private class UpdatePermissionsHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();

            if (req.getMethod() == 'DELETE') { // delete permissions
                res.setStatusCode(204);
            }
            if (req.getMethod() == 'POST') { // give permissions
                res.setStatusCode(200);
            }
            if (req.getMethod() == 'GET') { // view permissions
                res.setStatusCode(200);
                res.setBody('{ "@odata.context": "https://graph.microsoft.com/v1.0/$metadata#users(\'89c3c2cd-3d39-477d-9bfa-3462dcedf392\')/drive/items(\'3f54d3c2-3177-41f9-b067-4c411ef8b18a\')/permissions", "value": [  { "id": "2499632e-b662-4af0-8840-186d8170a012", "roles": [  "read" ], "shareId": "u!aHR0cHM6Ly9jb21wbGlhbnN5c3RlbXMtbXkuc2hhcmVwb2ludC5jb20vOnc6L2cvcGVyc29uYWwvcGVla2xvZ2ljX3NpbXBsb3VkX2NvbS9FY0xUVkQ5M01mbEJzR2RNUVI3NHNZb0JLY1l5T01rQUFlVlZIODkxWW1ZUExn", "hasPassword": false, "grantedToIdentitiesV2": [], "grantedToIdentities": [], "link": {  "scope": "organization",  "type": "view",  "webUrl": "https://compliansystems-my.sharepoint.com/:w:/g/personal/peeklogic_simploud_com/EcLTVD93MflBsGdMQR74sYoBKcYyOMkAAeVVH891YmYPLg",  "preventsDownload": false }  },  { "id": "5cac876d-226b-482b-ac47-7e4904571925", "roles": [  "write" ], "shareId": "u!aHR0cHM6Ly9jb21wbGlhbnN5c3RlbXMtbXkuc2hhcmVwb2ludC5jb20vOnc6L2cvcGVyc29uYWwvcGVla2xvZ2ljX3NpbXBsb3VkX2NvbS9FY0xUVkQ5M01mbEJzR2RNUVI3NHNZb0JhUmNPNTNpeF9zcnRCME1NaGlveWFB", "hasPassword": false, "grantedToIdentitiesV2": [  { "user": {  "@odata.type": "#microsoft.graph.sharePointIdentity",  "displayName": "danyil.m@peeklogic.com",  "email": "danyil.m@peeklogic.com" }  },  { "user": {  "@odata.type": "#microsoft.graph.sharePointIdentity",  "displayName": "standarduser@testorg.com",  "email": "standarduser@testorg.com" }  } ], "grantedToIdentities": [  { "user": {  "displayName": "danyil.m@peeklogic.com",  "email": "danyil.m@peeklogic.com" }  },  { "user": {  "displayName": "standarduser@testorg.com",  "email": "standarduser@testorg.com" }  } ], "link": {  "scope": "users",  "type": "edit",  "webUrl": "https://compliansystems-my.sharepoint.com/:w:/g/personal/peeklogic_simploud_com/EcLTVD93MflBsGdMQR74sYoBaRcO53ix_srtB0MMhioyaA",  "preventsDownload": false }  },  { "id": "aTowIy5mfG1lbWJlcnNoaXB8cGVla2xvZ2ljQHNpbXBsb3VkLmNvbQ", "roles": [  "owner" ], "shareId": "aTowIy5mfG1lbWJlcnNoaXB8cGVla2xvZ2ljQHNpbXBsb3VkLmNvbQ", "grantedToV2": {  "user": { "@odata.type": "#microsoft.graph.sharePointIdentity", "displayName": "Peeklogic Test User", "email": "peeklogic@simploud.com", "id": "89c3c2cd-3d39-477d-9bfa-3462dcedf392"  },  "siteUser": { "displayName": "Peeklogic Test User", "email": "peeklogic@simploud.com", "id": "3", "loginName": "i:0#.f|membership|peeklogic@simploud.com"  } }, "grantedTo": {  "user": { "displayName": "Peeklogic Test User", "email": "peeklogic@simploud.com", "id": "89c3c2cd-3d39-477d-9bfa-3462dcedf392"  } }  } ]}');
            }

            return res;
        }
    }


    private class getFileHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getEndpoint().contains('content')) {
                res.setStatusCode(304);
                res.setHeader('Location', 'https://test.com/download');
            }

            if (req.getEndpoint().contains('download')) {
                res.setStatusCode(200);
                res.setBodyAsBlob(Blob.valueOf('test'));
            }
            
            return res;
        }
    }
}