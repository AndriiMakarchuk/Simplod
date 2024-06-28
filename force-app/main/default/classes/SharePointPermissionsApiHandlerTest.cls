@isTest
public with sharing class SharePointPermissionsApiHandlerTest {
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

        Simploud__Document_Participant__c part1 = new Simploud__Document_Participant__c();
        part1.Simploud__Document__c = doc.Id;
        part1.Simploud__Participant__c = UserInfo.getUserId();
        part1.OneDrive_Shared_Link__c = 'testlink';
        insert part1;
    }

    @isTest
    public static void addPermissionToUsersTest_Overload() {
        Simploud__Controlled_Document__c doc = [SELECT Id, OneDrive_URL__c, OneDrive_Owner_Shared_Link__c FROM Simploud__Controlled_Document__c LIMIT 1];
        List<Simploud__Document_Participant__c> parts = [SELECT Id, OneDrive_Shared_Link__c FROM Simploud__Document_Participant__c WHERE Simploud__Document__c=:doc.Id];
        User u = [SELECT Id, Email FROM User WHERE Alias = 'standt' LIMIT 1];
        User currentUser = [SELECT Id, Email FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        string recordId = doc.Id;

        HttpCalloutMock mock = new ManualMock(265, '{"error": {"code": "InvalidAuthenticationToken","message": "Access token has expired."}}');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        try {
            SharePointPermissionsApiHandler.addPermissionToUsers(recordId, new User[] { u, currentUser }, 'write');
        }
        catch (Exception e) {
            System.assertEquals('{"error": {"code": "InvalidAuthenticationToken","message": "Access token has expired."}}', e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    public static void viewPermissionsTest() {
        Simploud__Controlled_Document__c doc = [SELECT Id, OneDrive_URL__c, OneDrive_Owner_Shared_Link__c FROM Simploud__Controlled_Document__c LIMIT 1];

        HttpMock mock = new HttpMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        SharePointPermissionsApiHandler.viewPermissions(new String[] { doc.Id });
        Test.stopTest();

        Simploud__Controlled_Document__c docAfter = [SELECT Id, OneDrive_URL__c, OneDrive_Owner_Shared_Link__c FROM Simploud__Controlled_Document__c LIMIT 1];
        Simploud__Document_Participant__c[] part = [SELECT Id, OneDrive_Shared_Link__c FROM Simploud__Document_Participant__c WHERE Simploud__Document__c=:doc.Id];
        System.assertEquals('https://compliansystems-my.sharepoint.com/:w:/g/personal/peeklogic_simploud_com/EcLTVD93MflBsGdMQR74sYoBaRcO53ix_srtB0MMhioyaA', part[0].OneDrive_Shared_Link__c);
    }

    @isTest
    public static void addPermissionToOwnerTest() {
        Simploud__Controlled_Document__c doc = [SELECT Id, OneDrive_URL__c, OneDrive_Owner_Shared_Link__c FROM Simploud__Controlled_Document__c LIMIT 1];

        HttpMock mock = new HttpMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        SharePointPermissionsApiHandler.addPermissionToOwner(doc.OneDrive_URL__c, doc.Id);
        Test.stopTest();

        Simploud__Controlled_Document__c docAfter = [SELECT Id, OneDrive_URL__c, OneDrive_Owner_Shared_Link__c FROM Simploud__Controlled_Document__c LIMIT 1];
        System.assertEquals('testowner', docAfter.OneDrive_Owner_Shared_Link__c);
    }

    private class HttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            
            if (req.getEndpoint().contains('invite') && req.getMethod() == 'POST') {
                res.setStatusCode(200);
                res.setBody('{ "@odata.context": "https://graph.microsoft.com/v1.0/$metadata#users(\'89c3c2cd-3d39-477d-9bfa-3462dcedf392\')/drive/items(\'3f54d3c2-3177-41f9-b067-4c411ef8b18a\')/permissions", "value": [  { "id": "5cac876d-226b-482b-ac47-7e4904571925", "roles": [  "write" ], "shareId": "u!aHR0cHM6Ly9jb21wbGlhbnN5c3RlbXMtbXkuc2hhcmVwb2ludC5jb20vOnc6L2cvcGVyc29uYWwvcGVla2xvZ2ljX3NpbXBsb3VkX2NvbS9FY0xUVkQ5M01mbEJzR2RNUVI3NHNZb0JhUmNPNTNpeF9zcnRCME1NaGlveWFB", "hasPassword": false, "grantedToIdentitiesV2": [  { "user": {  "@odata.type": "#microsoft.graph.sharePointIdentity",  "displayName": "danyil.m@peeklogic.com",  "email": "danyil.m@peeklogic.com" }  },  { "user": {  "@odata.type": "#microsoft.graph.sharePointIdentity",  "displayName": "standarduser@testorg.com",  "email": "standarduser@testorg.com" }  } ], "grantedToIdentities": [  { "user": {  "displayName": "danyil.m@peeklogic.com",  "email": "danyil.m@peeklogic.com" }  },  { "user": {  "displayName": "standarduser@testorg.com",  "email": "standarduser@testorg.com" }  } ], "link": {  "scope": "users",  "type": "edit",  "webUrl": "https://compliansystems-my.sharepoint.com/:w:/g/personal/peeklogic_simploud_com/EcLTVD93MflBsGdMQR74sYoBaRcO53ix_srtB0MMhioyaA",  "preventsDownload": false }  },  { "id": "aTowIy5mfG1lbWJlcnNoaXB8cGVla2xvZ2ljQHNpbXBsb3VkLmNvbQ", "roles": [  "owner" ], "shareId": "aTowIy5mfG1lbWJlcnNoaXB8cGVla2xvZ2ljQHNpbXBsb3VkLmNvbQ", "grantedToV2": {  "user": { "@odata.type": "#microsoft.graph.sharePointIdentity", "displayName": "Peeklogic Test User", "email": "peeklogic@simploud.com", "id": "89c3c2cd-3d39-477d-9bfa-3462dcedf392"  },  "siteUser": { "displayName": "Peeklogic Test User", "email": "peeklogic@simploud.com", "id": "3", "loginName": "i:0#.f|membership|peeklogic@simploud.com"  } }, "grantedTo": {  "user": { "displayName": "Peeklogic Test User", "email": "peeklogic@simploud.com", "id": "89c3c2cd-3d39-477d-9bfa-3462dcedf392"  } }  } ]}');
            }

            if (req.getEndpoint().contains('permissions') && req.getMethod() == 'GET') {
                res.setStatusCode(200);
                res.setBody('{ "@odata.context": "https://graph.microsoft.com/v1.0/$metadata#users(\'89c3c2cd-3d39-477d-9bfa-3462dcedf392\')/drive/items(\'3f54d3c2-3177-41f9-b067-4c411ef8b18a\')/permissions", "value": [  { "id": "2499632e-b662-4af0-8840-186d8170a012", "roles": [  "read" ], "shareId": "u!aHR0cHM6Ly9jb21wbGlhbnN5c3RlbXMtbXkuc2hhcmVwb2ludC5jb20vOnc6L2cvcGVyc29uYWwvcGVla2xvZ2ljX3NpbXBsb3VkX2NvbS9FY0xUVkQ5M01mbEJzR2RNUVI3NHNZb0JLY1l5T01rQUFlVlZIODkxWW1ZUExn", "hasPassword": false, "grantedToIdentitiesV2": [], "grantedToIdentities": [], "link": {  "scope": "organization",  "type": "view",  "webUrl": "https://compliansystems-my.sharepoint.com/:w:/g/personal/peeklogic_simploud_com/EcLTVD93MflBsGdMQR74sYoBKcYyOMkAAeVVH891YmYPLg",  "preventsDownload": false }  },  { "id": "5cac876d-226b-482b-ac47-7e4904571925", "roles": [  "write" ], "shareId": "u!aHR0cHM6Ly9jb21wbGlhbnN5c3RlbXMtbXkuc2hhcmVwb2ludC5jb20vOnc6L2cvcGVyc29uYWwvcGVla2xvZ2ljX3NpbXBsb3VkX2NvbS9FY0xUVkQ5M01mbEJzR2RNUVI3NHNZb0JhUmNPNTNpeF9zcnRCME1NaGlveWFB", "hasPassword": false, "grantedToIdentitiesV2": [  { "user": {  "@odata.type": "#microsoft.graph.sharePointIdentity",  "displayName": "danyil.m@peeklogic.com",  "email": "danyil.m@peeklogic.com" }  },  { "user": {  "@odata.type": "#microsoft.graph.sharePointIdentity",  "displayName": "standarduser@testorg.com",  "email": "standarduser@testorg.com" }  } ], "grantedToIdentities": [  { "user": {  "displayName": "danyil.m@peeklogic.com",  "email": "danyil.m@peeklogic.com" }  },  { "user": {  "displayName": "standarduser@testorg.com",  "email": "standarduser@testorg.com" }  } ], "link": {  "scope": "users",  "type": "edit",  "webUrl": "https://compliansystems-my.sharepoint.com/:w:/g/personal/peeklogic_simploud_com/EcLTVD93MflBsGdMQR74sYoBaRcO53ix_srtB0MMhioyaA",  "preventsDownload": false }  },  { "id": "aTowIy5mfG1lbWJlcnNoaXB8cGVla2xvZ2ljQHNpbXBsb3VkLmNvbQ", "roles": [  "owner" ], "shareId": "aTowIy5mfG1lbWJlcnNoaXB8cGVla2xvZ2ljQHNpbXBsb3VkLmNvbQ", "grantedToV2": {  "user": { "@odata.type": "#microsoft.graph.sharePointIdentity", "displayName": "Peeklogic Test User", "email": "peeklogic@simploud.com", "id": "89c3c2cd-3d39-477d-9bfa-3462dcedf392"  },  "siteUser": { "displayName": "Peeklogic Test User", "email": "peeklogic@simploud.com", "id": "3", "loginName": "i:0#.f|membership|peeklogic@simploud.com"  } }, "grantedTo": {  "user": { "displayName": "Peeklogic Test User", "email": "peeklogic@simploud.com", "id": "89c3c2cd-3d39-477d-9bfa-3462dcedf392"  } }  } ]}');
            }

            return res;
        }
    }

    private class ManualMock implements HttpCalloutMock {
        public Integer code;
        public String body;

        public ManualMock(Integer code, String body) {
            this.code = code;
            this.body = body;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.code);
            res.setBody(this.body);
            return res;
        }
    }
}