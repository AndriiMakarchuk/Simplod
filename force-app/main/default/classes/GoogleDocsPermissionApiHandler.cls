/**
 * Class to handle Google Docs Permission API. Responsible for giving, removing and updating permissions on Google Docs.
 * @author Danyil Mahalias
 * @since 21.09.2023
 */
public with sharing class GoogleDocsPermissionApiHandler {
    public class GoogleDocsApiException extends Exception {}
    public class CantDeletePermissionException extends Exception {}

    public enum PermissionType {
        VIEW,
        EDIT,
        COMMENT,
        NOACCESS
    }

    private static final Map<PermissionType, String> permissionTypeToGoogleDocsPermission = new Map<PermissionType, String> {
        PermissionType.VIEW => 'reader',
        PermissionType.EDIT => 'writer',
        PermissionType.COMMENT => 'commenter'
    };

    /**
     * Adds a permission to a document for a user.
     * @param controlledDocumentId Id of the document to add permission to.
     * @param userId Id of the user to add permission for.
     * @param permission view, edit or comment.
     * @return updated Google_Docs_Permissions__c field value.
     * 
     * @author Danyil Mahalias
     */
    public static String addPermissionForUser(Id controlledDocumentId, Id userId, PermissionType permission) {
        Simploud__Controlled_Document__c doc = [SELECT Id, Google_Docs_URL__c, Google_Docs_Permissions__c, OwnerId
                                                FROM Simploud__Controlled_Document__c 
                                                WHERE Id = :controlledDocumentId 
                                                WITH SECURITY_ENFORCED];

        User[] fileAdmins = [SELECT Id, Email, File_Admin__c FROM User WHERE File_Admin__c = true WITH SECURITY_ENFORCED];

        Id[] fileAdminIds = new Id[]{};

        for (User fileAdmin : fileAdmins) {
            fileAdminIds.add(fileAdmin.Id);
        }
        
        if (doc == null || doc.Google_Docs_URL__c == null) {
            throw new GoogleDocsApiException('Document not found or Google Drive URL is not set for Id ' + controlledDocumentId);
        }

        Map<String, String> permissionsMap = generatePermissionMap(doc.Google_Docs_Permissions__c);
        
        User targetUser = [SELECT Id, Email FROM User WHERE Id = :userId WITH SECURITY_ENFORCED];

        if (targetUser == null) {
            throw new GoogleDocsApiException('User not found or email is not set for Id ' + userId);
        }

        if (permissionsMap.containsKey(targetUser.Id) && targetUser.Id != doc.OwnerId && !fileAdminIds.contains(targetUser.Id)) {
            Http http = new Http();
            HttpRequest request = new HttpRequest();

            request.setEndpoint('callout:GDocs' + '/drive/v3/files/' + doc.Google_Docs_URL__c.split('/')[5] + '/permissions/' + permissionsMap.get(targetUser.Id));
            request.setMethod('DELETE');

            HttpResponse response = http.send(request);

            if (response.getStatusCode() != 204 && response.getStatusCode() != 404) {
                throw new CantDeletePermissionException('Error deleting permission for document ' + controlledDocumentId + ' and participant ' + userId + '. Response: ' + response.getBody());
            }

            permissionsMap.remove(targetUser.Id);
        }

        String googleDocsPermission = permissionTypeToGoogleDocsPermission.get(permission);

        if (googleDocsPermission == null) {
            throw new GoogleDocsApiException('Permission type not found for ' + permission);
        }

        GoogleDocumentParticipant toAddPemission = new GoogleDocumentParticipant(targetUser.Email, googleDocsPermission);

        Http http = new Http();
        HttpRequest request = new HttpRequest();

        string googleDocId = doc.Google_Docs_URL__c.split('/')[5];

        request.setEndpoint('callout:GDocs' + '/drive/v3/files/' + googleDocId + '/permissions?sendNotificationEmail=' + (targetUser.email.contains('gmail.com') ? 'false' : 'true'));
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');

        request.setBody(toAddPemission.toString());

        HttpResponse response = http.send(request);

        if (response.getStatusCode() != 200) {
            throw new GoogleDocsApiException('Error adding permission for document ' + controlledDocumentId + ' and participant ' + userId + '. Response: ' + response.getBody());
        }

        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());

        if (responseMap.get('id') == null) {
            throw new GoogleDocsApiException('Error adding permission for document ' + controlledDocumentId + ' and participant ' + userId + '. Response: ' + response.getBody());
        }

        permissionsMap.put(targetUser.Id, (String) responseMap.get('id'));

        return joinPermissionString(permissionsMap);
    }  

    /**
     * Deletes permission for a participant on a document.
     * @param documentId Id of the controlled document to delete permission from.
     * @param userId Id of the user to delete permission for.
     * @return updated Google_Docs_Permissions__c field value.
     * 
     * @author Danyil Mahalias
     */
    public static String deletePermissionsForUser(Id documentId, Id userId) {
        Simploud__Controlled_Document__c doc = [SELECT Id, Google_Docs_URL__c, Google_Docs_Permissions__c
                                                FROM Simploud__Controlled_Document__c 
                                                WHERE Id = :documentId 
                                                WITH SECURITY_ENFORCED];
        
        if (doc == null || doc.Google_Docs_URL__c == null) {
            throw new GoogleDocsApiException('Document not found or Google Drive URL is not set for Id ' + documentId);
        }

        Map<String, String> permissionsMap = generatePermissionMap(doc.Google_Docs_Permissions__c);

        if (permissionsMap.containsKey(userId)) {
            Http http = new Http();
            HttpRequest request = new HttpRequest();

            request.setEndpoint('callout:GDocs' + '/drive/v3/files/' + doc.Google_Docs_URL__c.split('/')[5] + '/permissions/' + permissionsMap.get(userId));
            request.setMethod('DELETE');

            HttpResponse response = http.send(request);

            if (response.getStatusCode() != 204) {
                throw new CantDeletePermissionException('Error deleting permission for document ' + documentId + ' and participant ' + userId + '. Response: ' + response.getBody());
            }
        }

        permissionsMap.remove(userId);

        return joinPermissionString(permissionsMap);
    }

    /**
     * Wrapper method to update permissions for a user. If permission is NOACCESS, deletes permission. Otherwise, adds or updates permission.
     * @param documentId Id of the controlled document to update permissions for.
     * @param userId Id of the user to update permissions for.
     * @param permission Permission to be set
     * @return updated Google_Docs_Permissions__c field value.
     * 
     * @author Danyil Mahalias
     */
    public static String updatePermissionsForUser(Id documentId, Id userId, PermissionType permission) {
        if (permission == PermissionType.NOACCESS) {
            return deletePermissionsForUser(documentId, userId);
        }

        else {
            return addPermissionForUser(documentId, userId, permission);
        }
    }

    /**
     * Gives permissions to all file admins for a document.
     * @param googleDocsUrl Url of the document to give permissions to. Url used since this method should be called right after record is created and Id is not available.
     * 
     * @author Danyil Mahalias
     */
    public static void addPermissionsForFileAdmins(String googleDocsUrl) {
        User[] fileAdmins = [SELECT Id, Email, File_Admin__c FROM User WHERE File_Admin__c = true WITH SECURITY_ENFORCED];

        for (User fileAdmin : fileAdmins) {
            GoogleDocumentParticipant toAddPemission = new GoogleDocumentParticipant(fileAdmin.Email, 'writer');

            Http http = new Http();
            HttpRequest request = new HttpRequest();

            string googleDocId = googleDocsUrl.split('/')[5];

            request.setEndpoint('callout:GDocs' + '/drive/v3/files/' + googleDocId + '/permissions?sendNotificationEmail=' + (fileAdmin.email.contains('gmail.com') ? 'false' : 'true'));
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/json');

            request.setBody(toAddPemission.toString());

            HttpResponse response = http.send(request);

            if (response.getStatusCode() != 200) {
                throw new GoogleDocsApiException('Error adding permission for file admins for document ' + googleDocsUrl + '. Response: ' + response.getBody());
            }
        }
    }

    /**
     * Adds permission for owner of the document. To be called when document is still in creation process.
     * @param docUrl Url of the document to add permission to. Url used since this method should be called right after record is created and Id is not available.
     * @param ownerId Id of the owner to add permission for.
     * 
     * @author Danyil Mahalias
     */
    public static void addPermissionForOwner(String docUrl, Id ownerId) {
        User owner = [SELECT Id, Email FROM User WHERE Id = :ownerId WITH SECURITY_ENFORCED];

        if (owner == null) {
            throw new GoogleDocsApiException('Owner not found or email is not set for Id ' + ownerId);
        }

        GoogleDocumentParticipant toAddPemission = new GoogleDocumentParticipant(owner.Email, 'writer');

        Http http = new Http();
        HttpRequest request = new HttpRequest();

        string googleDocId = docUrl.split('/')[5];

        request.setEndpoint('callout:GDocs' + '/drive/v3/files/' + googleDocId + '/permissions?sendNotificationEmail=' + (owner.email.contains('gmail.com') ? 'false' : 'true'));
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');

        request.setBody(toAddPemission.toString());

        HttpResponse response = http.send(request);

        if (response.getStatusCode() != 200) {
            throw new GoogleDocsApiException('Error adding permission for owner for document ' + docUrl + '. Response: ' + response.getBody());
        }

        /* 
            may be useful in some cases. will try to transfer file ownership to owner of the record
            yet this won't work in case of current file owner (the user used to authorize named creds)
            and owner of the record are in different domains
        */

        // request.setMethod('PUT');
        // request.setEndpoint('callout:GDocs' + '/drive/v3/files/' + googleDocId + '?transferOwnership=true');

        // response = http.send(request);
    }

    /**
     * Deletes all permissions for a document except for file admins.
     * @param docId Id of the controlled document to delete permissions from.
     * 
     * @author Danyil Mahalias
     */
    public static void deleteAllPermissions(Id docId) {
        Simploud__Controlled_Document__c doc = [SELECT Id, Google_Docs_URL__c, Google_Docs_Permissions__c
                                                FROM Simploud__Controlled_Document__c 
                                                WHERE Id = :docId 
                                                WITH SECURITY_ENFORCED];

        User[] fileAdmins = [SELECT Id FROM User WHERE File_Admin__c = true WITH SECURITY_ENFORCED];

        Id[] fileAdminIds = new Id[]{};

        for (User fileAdmin : fileAdmins) {
            fileAdminIds.add(fileAdmin.Id);
        }

        if (doc == null || doc.Google_Docs_URL__c == null) {
            throw new GoogleDocsApiException('Document not found or Google Drive URL is not set for Id ' + docId);
        }

        Map<String, String> permissionsMap = generatePermissionMap(doc.Google_Docs_Permissions__c);

        for (String userId : permissionsMap.keySet()) {
            if (fileAdminIds.contains(userId)) {
                continue;
            }

            Http http = new Http();
            HttpRequest request = new HttpRequest();

            request.setEndpoint('callout:GDocs' + '/drive/v3/files/' + doc.Google_Docs_URL__c.split('/')[5] + '/permissions/' + permissionsMap.get(userId));
            request.setMethod('DELETE');

            HttpResponse response = http.send(request);

            if (response.getStatusCode() != 204 && response.getStatusCode() != 404) {
                // throw new CantDeletePermissionException('Error deleting permission for document ' + docId + ' and participant ' + userId + '. Response: ' + response.getBody());
            }
        }
    }

    /**
     * Utility method. Generates a map of permissions from a string.
     * @param googleDocsPermissions Google_Docs_Permissions__c field value.
     * @return  `Map<String, String>`
     * 
     * @author Danyil Mahalias
     */
    private static Map<String, String> generatePermissionMap(String googleDocsPermissions) {
        if (googleDocsPermissions == null || googleDocsPermissions == '') {
            return new Map<String, String>();
        }

        String[] permissionsPairs = googleDocsPermissions.split(';');
        Map<String, String> permissionsMap = new Map<String, String>(); // UserId => Permission

        if (permissionsPairs.size() == 0) {
            return permissionsMap;
        }

        for (String permissionPair : permissionsPairs) {
            if (permissionPair == null || permissionPair == '' || !permissionPair.contains(':')) {
                continue;
            }

            String[] permissionPairSplit = permissionPair.split(':');
            permissionsMap.put(permissionPairSplit[0], permissionPairSplit[1]);
        }

        return permissionsMap;
    }

    /**
     * Utility method. Joins permission map into a string.
     * @param permissionsMap Map of permissions to join.
     * @return  `String`
     * 
     * @author Danyil Mahalias
     */
    private static String joinPermissionString(Map<String, String> permissionsMap) {
        String permissionsJoined = '';

        for (String key : permissionsMap.keySet()) {
            permissionsJoined += key + ':' + permissionsMap.get(key) + ';';
        }

        return permissionsJoined;
    }

    /**
     * Wrapper class for request body to create a permission.
     * 
     * @author Danyil Mahalias
     */
    private class GoogleDocumentParticipant {
        public String emailAddress {get; set;}
        public String role {get; set;}
        public String type {get; set;}

        public GoogleDocumentParticipant(String email, String role) {
            this.emailAddress = email;
            this.role = role;
            this.type = 'user';
        }

        public override String toString() {
            return JSON.serialize(this);
        }
    }
}