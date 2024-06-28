/**
 * Controller for LWC DocumentCollaborationTool
 * @author Danyil Mahalias
 * @since 22.09.2023
 */
public with sharing class DocumentCollaborationToolHelper {
    @AuraEnabled
    public static string getSelectedCollaboration() {
        Simploud__SimploudOrgSettings__c settings = Simploud__SimploudOrgSettings__c.getOrgDefaults();

        return settings.Collaboration_Tool__c;
    }
}