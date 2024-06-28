public with sharing class GoogleEditorController {

    @AuraEnabled
    public static string getEditorUrl(String recordId) {
        Simploud__Controlled_Document__c doc = [SELECT Id, Google_Docs_URL__c FROM Simploud__Controlled_Document__c WHERE Id = :recordId];

        return doc.Google_Docs_URL__c;
    }

    @AuraEnabled
    public static void saveDocument(String recordId) {
        GoogleDocsApiHandler.saveDocument(new Id[] { Id.valueOf(recordId) });
    }

    @AuraEnabled
    public static string getDownloadLink(String recordId) {
        Simploud__Controlled_Document__c doc = [SELECT Id, Google_Docs_URL__c, (SELECT Id, ContentDocumentId FROM ContentDocumentLinks) FROM Simploud__Controlled_Document__c WHERE Id = :recordId];

        ContentDocument cd = [SELECT Id, FileExtension FROM ContentDocument WHERE Id = :doc.ContentDocumentLinks[0].ContentDocumentId];

        return doc.Google_Docs_URL__c + '/export?format=' + cd.FileExtension;
    }
}