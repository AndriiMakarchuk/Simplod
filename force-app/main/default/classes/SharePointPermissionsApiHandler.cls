public class SharePointPermissionsApiHandler {
  private class CannotRemovePermissionException extends Exception {
  }
  private class CannotAddPermissionException extends Exception {
  }

  private class PermissionBodyWrapper {
    public EmailWrapper[] recipients { get; set; }
    public string message { get; set; }
    public Boolean requireSignIn { get; set; }
    public boolean sendInvitation { get; set; }
    public String[] roles { get; set; }
    public String type = 'review';
    public Boolean sendNotification = true;
    public Boolean retainInheritedPermissions = false;
    public String scope = 'anonymous';
    
    PermissionBodyWrapper(
      Boolean requireSignIn,
      boolean sendInvitation,
      String[] roles,
      EmailWrapper[] recipients,
      string message
    ) {
      this.requireSignIn = requireSignIn;
      this.sendInvitation = sendInvitation;
      this.roles = roles;
      this.recipients = recipients;
      this.message = message;
    }

    PermissionBodyWrapper() {
    }

    public void setRecipients(EmailWrapper[] recipients) {
      this.recipients = recipients;
    }

    public void setMessage(string message) {
      this.message = message;
    }

    public void setRequireSignIn(Boolean requireSignIn) {
      this.requireSignIn = requireSignIn;
    }

    public void setSendInvitation(boolean sendInvitation) {
      this.sendInvitation = sendInvitation;
    }

    public void setRoles(String[] roles) {
      this.roles = roles;
    }

    public override String toString() {
      return JSON.serialize(this);
    }
  }

  private class EmailWrapper {
    public String email { get; set; }

    EmailWrapper(string email) {
      this.email = email;
    }
  }

  private class SharePointValueWrapper {
    public string id { get; set; }
    public string[] roles { get; set; }
    public SharePointGranted[] grantedToIdentities { get; set; }
    public SharePointGranted grantedTo { get; set; }
    public SharePointLinkWrapper link { get; set; }
  }

  private class SharePointLinkWrapper {
    public string webUrl { get; set; }
  }

  private class SharePointAcessWrapper {
    public SharePointValueWrapper[] value { get; set; }
  }

  private class SharePointGranted {
    public SharePointUser user { get; set; }
  }

  private class SharePointUser {
    public String email { get; set; }
  }

  private class PermissionUser {
    public string permissionId { get; set; }
    public string[] emails { get; set; }
    public string link { get; set; }
  }

  /**
   * Makes a request to the SharePoint API to add permissions to a document for a list of users
   * @param recordId `string` - the id of the Controlled Document record
   * @param users `User[]` - list of users to add permissions to
   * @param permission `string` (read/write) - the permission to add to the users
   * @author Anastasiia Stetsenko
   */
  public static void addPermissionToUsers(
    Id recordId,
    User[] users,
    String permission
  ) {
    // if (system.isFuture() || system.isBatch()) {
    //   return;
    // }
    if (permission == 'review') {
      addReviewPermissionToUsers(recordId, users);
      return;
    }

    Simploud__Controlled_Document__c controlledDocument = getControlledDocumentsByIds(new List<Id>{recordId}).get(0);

    Map<Id, User> usersMap = new Map<Id, User>(users);
    List<Simploud__Document_Participant__c> participants = getDocumentParticipantsByParicipantAndDocumentsIds(usersMap.keySet(), new List<Id>{recordId});

    List<EmailWrapper> emailWrapperList = getEmailsFromUsers(users);

    PermissionBodyWrapper bodyWrap = new PermissionBodyWrapper();
    bodyWrap.setRequireSignIn(true);
    bodyWrap.setSendInvitation(false);
    bodyWrap.setRoles(new List<String>{ permission });
    bodyWrap.setRecipients(emailWrapperList);
    bodyWrap.setMessage('msg');

    String body = bodyWrap.toString();
    system.debug(body);

    String itemId = SharePointApiHandler.getFileId(
      controlledDocument.OneDrive_URL__c
    );

    string endpointUrl = 'callout:SharePoint/me/drive/items/{item-id}/invite';

    if (itemId == null) return;

    endpointUrl = endpointUrl.replace('{item-id}', itemId);

    Map<String, String> headers = new Map<String, String>();
    headers.put('Content-Type', 'application/json');
    headers.put('Accept', 'application/json, text/plain');

    HttpResponse res = SharePointApiHandler.sendRequest(
      'POST',
      endpointUrl,
      headers,
      body,
      null
    );

    if (res.getStatusCode() != 200) {
      throw new CannotAddPermissionException(res.getBody());
    }
  }

  public static void addReviewPermissionToUsers(Id recordId, List<User> users) {
    Simploud__Controlled_Document__c controlledDocument = getControlledDocumentsByIds(new List<Id>{recordId}).get(0);

    Map<Id, User> usersMap = new Map<Id, User>(users);
    List<Simploud__Document_Participant__c> participants = getDocumentParticipantsByParicipantAndDocumentsIds(usersMap.keySet(), new List<Id>{recordId});

    List<EmailWrapper> emailWrapperList = getEmailsFromUsers(users);

    PermissionBodyWrapper bodyWrap = new PermissionBodyWrapper();
    bodyWrap.setRecipients(emailWrapperList);

    String body = bodyWrap.toString();

    String itemId = SharePointApiHandler.getFileId(
      controlledDocument.OneDrive_URL__c
    );

    string endpointUrl = 'callout:SharePoint/me/drive/items/{item-id}/createLink';

    if (itemId == null) return;

    endpointUrl = endpointUrl.replace('{item-id}', itemId);

    Map<String, String> headers = new Map<String, String>();
    headers.put('Content-Type', 'application/json');
    headers.put('Accept', 'application/json, text/plain');

    HttpResponse res = SharePointApiHandler.sendRequest(
      'POST',
      endpointUrl,
      headers,
      body,
      null
    );

    if (res.getStatusCode() != 201) {
      throw new CannotAddPermissionException(res.getBody());
    }
  }

  /**
   * Makes a request to the SharePoint API to add permissions to a document for the record owner and all users with the File Admin field checked
   * @param documentUrl `string` - the url of the document
   * @param documentId `Id` - the id of the Controlled Document record
   * @author Anastasiia Stetsenko
   */
  public static String addPermissionToOwner(String documentUrl, Id documentId) {
    Simploud__Controlled_Document__c controlledDocument = getControlledDocumentsByIds(new List<Id>{documentId}).get(0);

    Id[] participantsIds = new List<Id>();
    for (Simploud__Document_Participant__c part : controlledDocument.Simploud__Document_Participants__r) {
      participantsIds.add(part.Simploud__Participant__c);
    }

    List<User> users = getUsersByIdsAndFileAdmins(new List<Id>{controlledDocument.OwnerId});

    List<EmailWrapper> emailWrapperList = getEmailsFromUsers(users);

    PermissionBodyWrapper bodyWrap = new PermissionBodyWrapper();
    bodyWrap.setRequireSignIn(true);
    bodyWrap.setSendInvitation(false);
    bodyWrap.setRoles(new List<String>{ 'write' });
    bodyWrap.setRecipients(emailWrapperList);
    bodyWrap.setMessage('msg');

    String body = bodyWrap.toString();

    String itemId = SharePointApiHandler.getFileId(documentUrl);

    string endpointUrl = 'callout:SharePoint/me/drive/items/{item-id}/invite';
    endpointUrl = endpointUrl.replace('{item-id}', itemId);

    Map<String, String> headers = new Map<String, String>();
    headers.put('Content-Type', 'application/json');
    headers.put('Accept', 'application/json, text/plain');

    HttpResponse res = SharePointApiHandler.sendRequest(
      'POST',
      endpointUrl,
      headers,
      body,
      null
    );

    if (res.getStatusCode() == 200) {
      SharePointAcessWrapper wrap = (SharePointAcessWrapper) JSON.deserialize(
        res.getBody(),
        SharePointAcessWrapper.class
      );

      // viewPermissions(documentUrl, documentId);

      User owner = getUsersByIds(new List<Id>{controlledDocument.OwnerId}).get(0);
      String ownerEmail = owner.Email;
      integer findingIndex = 0;
      boolean goFurther = true;
      boolean found = false;

      for (SharePointValueWrapper value : wrap.value) {
        if (!goFurther)
          break;

        findingIndex++;
        if (
          value.grantedToIdentities == null ||
          value.grantedToIdentities.size() == 0
        )
          continue;
        for (SharePointGranted grantedTo : value.grantedToIdentities) {
          if (grantedTo.user.email == ownerEmail) {
            goFurther = false;
            found = true;
            break;
          }
        }
      }

      if ( // in this case owner in an external user
        found == true &&
        wrap.value[findingIndex - 1]?.link?.webUrl != null
      ) {
        controlledDocument.OneDrive_Owner_Shared_Link__c = wrap.value[
            findingIndex - 1
          ]
          .link.webUrl;
      } else { // owner is an internal user
        controlledDocument.OneDrive_Owner_Shared_Link__c = embededLink(
          documentUrl
        );
      }

      List<User> participantsUsers = getUsersByIds(participantsIds);

      emailWrapperList = getEmailsFromUsers(participantsUsers);

      bodyWrap = new PermissionBodyWrapper();
      bodyWrap.setRequireSignIn(true);
      bodyWrap.setSendInvitation(false);
      bodyWrap.setRoles(new List<String>{ 'read' });
      bodyWrap.setRecipients(emailWrapperList);
      bodyWrap.setMessage('msg');

      body = bodyWrap.toString();

      system.debug(body);

      endpointUrl = 'callout:SharePoint/me/drive/items/{item-id}/invite';
      endpointUrl = endpointUrl.replace('{item-id}', itemId);

      headers = new Map<String, String>();
      headers.put('Content-Type', 'application/json');
      headers.put('Accept', 'application/json, text/plain');

      res = SharePointApiHandler.sendRequest(
        'POST',
        endpointUrl,
        headers,
        body,
        null
      );

      return controlledDocument.OneDrive_Owner_Shared_Link__c;
    }

    return null;
  }

  /**
   * Retrieves the permissions for files associated with Controlled Document records, parses the permissions, and updates the fields on the Controlled Document and Document Participant records:
   * - OneDrive_Permission__c (on Controlled Document)
   * - OneDrive_Shared_Link__c (on Document Participant)
   * - OneDrive_Owner_Shared_Link__c (on Controlled Document)
   * @param recordIds `string[]` - the ids of the Controlled Document records to update permissions for
   * @author Anastasiia Stetsenko
   */
  public static void viewPermissions(String[] recordIds) {
    Map<Id, List<PermissionUser>> parsingMap = new Map<Id, List<PermissionUser>>();
    List<Simploud__Controlled_Document__c> controlledDocuments = getControlledDocumentsByIds(recordIds);
    List<Id> ownerIds = new List<Id>{};

    Simploud__Controlled_Document__c[] toUpdate = new List<Simploud__Controlled_Document__c>();
    for (Simploud__Controlled_Document__c controlledDocument : controlledDocuments) {
      ownerIds.add(controlledDocument.OwnerId);

      String itemId = SharePointApiHandler.getFileId(
        controlledDocument.OneDrive_URL__c
      );

      string endpointUrl = 'callout:SharePoint/me/drive/items/{item-id}/permissions';
      endpointUrl = endpointUrl.replace('{item-id}', itemId);

      Map<String, String> headers = new Map<String, String>();
      headers.put('Accept', 'application/json');

      HttpResponse res = SharePointApiHandler.sendRequest(
        'GET',
        endpointUrl,
        headers,
        null,
        null
      );
      if (res.getStatusCode() == 200) {
        List<PermissionUser> parsingList = new List<PermissionUser>();

        controlledDocument.OneDrive_Permission__c = '';

        SharePointAcessWrapper wrap = (SharePointAcessWrapper) JSON.deserialize(
          res.getBody(),
          SharePointAcessWrapper.class
        );
        for (SharePointValueWrapper unit : wrap.value) {
          if (!unit.roles.contains('owner') && unit.roles.size() != 0) {
            if (String.isNotBlank(controlledDocument.OneDrive_Permission__c))
              controlledDocument.OneDrive_Permission__c += '\n';

            controlledDocument.OneDrive_Permission__c +=
              'roles: ' +
              unit.roles +
              ', id: ' +
              unit.id +
              ';';

            PermissionUser pm = new PermissionUser();
            String[] emails = new List<String>();
            if (unit.grantedToIdentities != null) {
              for (SharePointGranted u : unit.grantedToIdentities) {
                emails.add(u.user.email);
              }
              pm.emails = emails;
              pm.link = unit.link.webUrl;
              pm.permissionId = unit.Id;
            } else if (unit.grantedTo != null) {
              emails.add(unit.grantedTo.user.email);
              pm.emails = emails;
              pm.link = embededLink(controlledDocument.OneDrive_URL__c);
              pm.permissionId = unit.Id;
            }

            if (pm.permissionId != null)
              parsingList.add(pm);
          }
        }
        if(String.isBlank(controlledDocument.OneDrive_Permission__c))
        controlledDocument.OneDrive_Permission__c = ';';

        parsingMap.put(controlledDocument.Id, parsingList);
      }
    }

    List<Simploud__Controlled_Document__c> toUpdateDocs = new List<Simploud__Controlled_Document__c>();
    List<Simploud__Document_Participant__c> toUpdatePart = new List<Simploud__Document_Participant__c>();

    List<Simploud__Document_Participant__c> participants = getDocumentParticipantsByDocumentsIds(parsingMap.keySet());

    Id[] userIds = new List<Id>();
    for (Simploud__Document_Participant__c part : participants) {
      userIds.add(part.Simploud__Participant__c);
    }

    userIds.addAll(ownerIds);

    List<User> users = getUsersByIds(userIds);
    Map<String, Id> userEmails = new Map<String, Id>();
    for (User user : users) {
      userEmails.put(user.Email, user.Id);
    }

    for (Simploud__Controlled_Document__c controlledDocument : controlledDocuments) {
      String Owner = null;
      Map<Id, Simploud__Document_Participant__c> participantsOfDoc = new Map<Id, Simploud__Document_Participant__c>();
      for (Simploud__Document_Participant__c part : participants) {
        if (part.Simploud__Document__c == controlledDocument.Id) {
          participantsOfDoc.put(part.Simploud__Participant__c, part);
        }
      }

      for (PermissionUser pu : parsingMap.get(controlledDocument.Id)) {
        String link = null;
        if (pu.link != null) {
          link = pu.link;

          for (String em : pu.emails) {
            em = em.toLowerCase();
            if (participantsOfDoc.keySet().contains(userEmails.get(em))) {
              participantsOfDoc.get(userEmails.get(em)).OneDrive_Shared_Link__c = link;
              toUpdatePart.add(participantsOfDoc.get(userEmails.get(em)));
            }
            if (controlledDocument.OwnerId == userEmails.get(em)) {
              controlledDocument.OneDrive_Owner_Shared_Link__c = link;
            }
          }
        }
      }
      toUpdateDocs.add(controlledDocument);
    }

    Set<Simploud__Document_Participant__c> filteredParts = new Set<Simploud__Document_Participant__c>();
    filteredParts.addAll(toUpdatePart);
    toUpdatePart = new List<Simploud__Document_Participant__c>(filteredParts);

    Set<Simploud__Controlled_Document__c> filteredDocs = new Set<Simploud__Controlled_Document__c>();
    filteredDocs.addAll(toUpdateDocs);
    toUpdateDocs = new List<Simploud__Controlled_Document__c>(filteredDocs);

    update toUpdatePart;
    update toUpdateDocs;
  }

  public static void viewPermissions(String documentUrl, Id recordId) {
    Simploud__Controlled_Document__c controlledDocument = getControlledDocumentsByIds(new List<Id>{recordId}).get(0);

    String itemId = SharePointApiHandler.getFileId(documentUrl);

    string endpointUrl = 'callout:SharePoint/me/drive/items/{item-id}/permissions';
    endpointUrl = endpointUrl.replace('{item-id}', itemId);

    Map<String, String> headers = new Map<String, String>();
    headers.put('Accept', 'application/json');

    HttpResponse res = SharePointApiHandler.sendRequest(
      'GET',
      endpointUrl,
      headers,
      null,
      null
    );

    if (res.getStatusCode() == 200) {
      controlledDocument.OneDrive_Permission__c = '';

      SharePointAcessWrapper wrap = (SharePointAcessWrapper) JSON.deserialize(
        res.getBody(),
        SharePointAcessWrapper.class
      );
      for (SharePointValueWrapper unit : wrap.value) {
        if (!unit.roles.contains('owner') && unit.roles.size() != 0) {
          if (!String.isBlank(controlledDocument.OneDrive_Permission__c))
            controlledDocument.OneDrive_Permission__c += '\n';
          controlledDocument.OneDrive_Permission__c +=
            'roles: ' +
            unit.roles +
            ', id: ' +
            unit.id +
            ';';
        }
      }
      update controlledDocument;
    }
  }

  /**
   * Makes a request to the SharePoint API to delete permissions for a list of files
   * @param recordIds `string[]` - the ids of the Controlled Document records to delete permissions for
   * @author Anastasiia Stetsenko
   */
  public static void deletePermissions(String[] recordIds) {
    List<Simploud__Controlled_Document__c> controlledDocuments = getControlledDocumentsByIds(recordIds);
    for (Simploud__Controlled_Document__c controlledDocument : controlledDocuments) {
      List<String> permissions = controlledDocument.OneDrive_Permission__c.split(';');
      if (permissions.size()==0) continue;
      for (String permission : permissions) {
        if (String.isBlank(permission)) continue;
        deletePermissionsAPI(controlledDocument, permission.substringAfter('id: '));
      }
    }
  }

  /**
   * Utility method to make a request to the SharePoint API to delete permissions for a file
   * @param controlledDocument `Simploud__Controlled_Document__c` - the Controlled Document record to delete permissions for
   * @param permissionId `string` - the id of the permission to delete (from the OneDrive_Permission__c field on the Controlled Document record)
   * @author Anastasiia Stetsenko
   */
  public static void deletePermissionsAPI(
    Simploud__Controlled_Document__c controlledDocument,
    string permissionId
  ) {
    String itemId = SharePointApiHandler.getFileId(
      controlledDocument.OneDrive_URL__c
    );
    string endpointUrl = 'callout:SharePoint/me/drive/items/{item-id}/permissions/{perm-id}';
    endpointUrl = endpointUrl.replace('{item-id}', itemId);
    endpointUrl = endpointUrl.replace('{perm-id}', permissionId);
    HttpResponse res = SharePointApiHandler.sendRequest(
      'DELETE',
      endpointUrl,
      new Map<String, String>(),
      null,
      null
    );
    if (res.getStatusCode() != 204) {
      throw new CannotRemovePermissionException(res.getBody());
    }
  }

  /**
   * Utility method to convert a download url to a Doc link
   * @param url `string` - the download url (OneDrive_URL__c field on the Controlled Document record)
   * @return  `string`
   * @author Anastasiia Stetsenko
   */
  private static string embededLink(String url) {
    return url
      .replace('.com', '.com/:w:/r')
      .replace('download.aspx', 'Doc.aspx')
      .replace('uniqueid=', 'sourcedoc={')
      .replace('&', '}&');
  }

  private static List<EmailWrapper> getEmailsFromUsers(List<User> users) {
    List<EmailWrapper> emailWrapperList = new List<EmailWrapper>();
    for (User u : users) {
      if (String.isBlank(u.email))
        continue;
      if (u.email.contains('.invalid'))
        continue;
      if (u.email == 'admin@simploud.com') {
        Simploud__SimploudOrgSettings__c settings = Simploud__SimploudOrgSettings__c.getOrgDefaults();
        if (String.isNotBlank(settings?.Support_Email_Replacement__c)) { 
          u.email = settings.Support_Email_Replacement__c;
        } else {
          continue;
        }
      }

      emailWrapperList.add(new EmailWrapper(u.Email));
    }

    return emailWrapperList;
  }

  private static List<Simploud__Controlled_Document__c> getControlledDocumentsByIds(List<Id> documentIds) {
    return [
      SELECT Id, OneDrive_Owner_Shared_Link__c, OneDrive_URL__c, OneDrive_Permission__c, OwnerId,
      (SELECT Simploud__Participant__c FROM Simploud__Document_Participants__r)
      FROM Simploud__Controlled_Document__c
      WHERE Id IN :documentIds
    ];
  }

  private static List<Simploud__Document_Participant__c> getDocumentParticipantsByParicipantAndDocumentsIds(Set<Id> userIds, List<Id> documentIds) {
    return [
      SELECT Id, OneDrive_Shared_Link__c
      FROM Simploud__Document_Participant__c
      WHERE Simploud__Participant__c IN :userIds AND Simploud__Document__c IN :documentIds
    ];
  }

  private static List<Simploud__Document_Participant__c> getDocumentParticipantsByDocumentsIds(Set<Id> documentIds){
    return [
      SELECT Id, Simploud__Participant__c,
        Simploud__Document__c, OneDrive_Shared_Link__c
      FROM Simploud__Document_Participant__c
      WHERE Simploud__Document__c IN :documentIds
    ];
  }

  private static List<User> getUsersByIds(List<Id> userIds) {
    return [
      SELECT Id, Email
      FROM User
      WHERE Id IN :userIds
    ];
  }

  private static List<User> getUsersByIdsAndFileAdmins(List<Id> userIds) { 
    return [
      SELECT Email, Profile.Name
      FROM User
      WHERE Id IN :userIds OR File_Admin__c = TRUE
    ];
  }
}
