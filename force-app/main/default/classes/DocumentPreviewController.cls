/**
* @author Sagie Twig
* Following class serve back-end for document preview component 09/2018
*/
global with sharing class DocumentPreviewController {
    
    /**
* Provide content document id for link generation
* @param  parentId [ Controlled document Id ]
* @return          [ JSON String { responseType, data, msg } ]
*/
    @AuraEnabled
    global static String getAttachmentContentLink(Id parentId){
        DocumentStatusWrapper docStatus = new DocumentStatusWrapper();
        docStatus.documentId = parentId;
        docStatus.isEffective = false;
        docStatus.hideCheckButton = false;
        List<ContentVersion> contentVersionList = new List<ContentVersion>();
        List<Controlled_Document__c> docs = getCurrentDocument(parentId);
        if (!docs.isEmpty()) {
            docStatus.documentName = docs[0].Name;
            docStatus.status = docs[0].Status__c;
            docStatus.documentType = docs[0].Document_Type__c;
            docStatus.isEffective = docs[0].Status__c == 'Effective';
            List<ContentDocumentLink> contentDocumentLinks = new List<ContentDocumentLink>();
            Schema.DescribeFieldResult statusResult = Controlled_Document__c.Status__c.getDescribe();
            
            Boolean useCollaboration = false;
            if (docs[0].Google_Docs_Url__c !=null || docs[0].OneDrive_URL__c != null)
            {
                useCollaboration = SharePointTriggersHelper.isCollaborationEnabled(Helper.Document,docs[0].Status__c);
                List<Schema.PicklistEntry> picklistValues = statusResult.getPicklistValues();
                
                if (!picklistValues.isEmpty()) {
                    String firstPicklistValue = picklistValues[0].getValue();
                    
                    if (firstPicklistValue != docs[0].Status__c && useCollaboration)
                    {
                         docStatus.hideCheckButton = true;
                    }
                }

            }
            
            docStatus.isRevision = false;
            if (docs[0].ContentDocumentLinks != null && docs[0].ContentDocumentLinks.size() > 0)
                contentDocumentLinks = docs[0].ContentDocumentLinks;
            else if (String.isNotBlank(docs[0].Previous_Version__c))
            {
                docStatus.isRevision = true;
                docStatus.previousId = docs[0].Previous_Version__c;
            }
                
            
            if ( !contentDocumentLinks.isEmpty() ) {
                docStatus.contentId = contentDocumentLinks[0].ContentDocumentId;
                // Get all the versions that are not PDF rendition and are in Word or PDF formats
                contentVersionList = getCurrentVersion(parentId, docStatus.contentId);
                 docStatus.noVersions = contentVersionList.size();
            }
            if ( !contentVersionList.isEmpty() ) {
                docStatus.lastVersion = contentVersionList[0];
            }
            
            Map<String,OrgUtils.DocumentTypeWrapper> docTypeMap = OrgUtils.getDocTypeMap();
            OrgUtils.DocumentTypeWrapper docType = docTypeMap.get(docStatus.documentType);
            String init = 'Init';
            if (docType != null && String.isNotBlank(docType.adminGroup))
            {
                if (!OrgUtils.isGroupMember(docType.adminGroup))
                    init = 'InitUser';
            }
            
            String checkStatusString = getCheckOutStatus(parentId,init,null);
            
            docStatus.checkStatus = (DocumentCheckOutWrapper)JSON.deserialize(checkStatusString,DocumentCheckOutWrapper.class);
            
            return Json.serialize(docStatus);
                }
        else{ return null;}
    }
    
         // This is the method that determines if the current user belongs to the admin group
    @AuraEnabled
    public static Boolean isGroupMember(String groupName) {
        return OrgUtils.isGroupMember(groupName);
    }
    
     // This is the method that determines if the current user belongs to the admin group
    @AuraEnabled
    public static String getFileVersions(String fileId) {
        List<DocumentVersion> versionList = new List<DocumentVersion>();
        Decimal index = 0;
        
        for (ContentVersion cv : [SELECT Id, Title, FileExtension,CreatedDate,CreatedBy.Name,ContentSize,ContentDocumentId,ReasonForChange FROM ContentVersion WHERE ContentDocumentId =: fileId 
                                  AND FileExtension in ('docx','doc','xls','xlsx','pdf','ppt','pptx','odt','odp','ods','numbers') 
                                  AND ReasonForChange != 'PDF Rendition' ORDER BY CreatedDate])
        {
            DocumentVersion currentVersion = new DocumentVersion();
            currentVersion.name = cv.Title;
            currentVersion.extension = cv.FileExtension;
            currentVersion.size = cv.ContentSize / 1024;           
            currentVersion.versionId = cv.Id;
            currentVersion.contentId = cv.ContentDocumentId;      
            currentVersion.contentDate = cv.CreatedDate;
            currentVersion.modifier = cv.CreatedBy.Name;
            currentVersion.reason = cv.ReasonForChange;   
            currentVersion.versionNo = index;
            index++;
            versionList.add(currentVersion);
        }
        
        return Json.serialize(versionList);
    }
    
    // Get the current document version
    public static List<Controlled_Document__c> getCurrentDocument (String parentId)
    {
        List<Controlled_Document__c> docs = new List<Controlled_Document__c>();
          if(Schema.sObjectType.Controlled_Document__c.isAccessible() && Schema.sObjectType.ContentDocumentLink.isAccessible() ){
            docs = [SELECT Id,Name,OwnerId,Status__c,Checked_Out__c,Checked_Out_By__c,Checked_Out_On__c,Version__c,Revision__c,Check_Out_Name__c,Rendition_Available__c,Document_Type__c,Previous_Version__c,
                    OneDrive_URL__c,Use_Document_Collaboration_Tool__c,Google_Docs_Url__c,(SELECT ContentDocumentId,LinkedEntityId, ContentDocument.FileExtension  
                     FROM ContentDocumentLinks WHERE LinkedEntityId = :parentId),(Select ID,WhatId,OwnerId,Status,Check_In_User__c From Tasks Where Status = 'In Progress')
                     FROM Controlled_Document__c WHERE Id =: parentId];
        }
        return docs;
    }
    
    public static List<ContentVersion> getCurrentVersion (String parentId, String contentId)
    {
        List<ContentVersion> contentVersionList = new List<ContentVersion>();
          if(Schema.sObjectType.ContentVersion.isAccessible()) 
                {
                    contentVersionList = [SELECT Id,Title,ContentDocumentId, VersionNumber,FileExtension,LastModifiedDate,ContentSize
                                          FROM ContentVersion  
                                          WHERE ContentDocumentId =:contentId AND FileExtension in ('docx','doc','xls','xlsx','ppt','pptx','pdf','odt','odp','ods','numbers') AND 
                                          ReasonForChange != 'PDF Rendition'  
                                          ORDER BY CreatedDate  DESC];
                }
        return contentVersionList;
    }

    
    
    /**
* Get controlled document checkout status
* @param  parentId [ Controlled document Id ]
* @param  actionType [ String with the type of action ]
* @return          [ JSON String { Controlled_Document__c } ]
*/
    @AuraEnabled
    public static String getCheckOutStatus(Id parentId, String actionType,String comment) {
        List<Controlled_Document__c> docs = getCurrentDocument(parentId);
        // There is no controlled document
        if (docs.isEmpty()) 
        {return null;}
        Controlled_Document__c doc = docs[0];
        String fileExt = 'NA';
        Map<String,OrgUtils.DocumentTypeWrapper> docTypeMap = OrgUtils.getDocTypeMap();
        OrgUtils.DocumentTypeWrapper docType = docTypeMap.get(doc.Document_Type__c);
        List<String> checkInStatuses = docType.checkInStatuses;
        
        SimploudOrgSettings__c  setting = new SimploudOrgSettings__c ();
        if(Schema.sObjectType.SimploudOrgSettings__c.isAccessible() ){
            setting = SimploudOrgSettings__c.getOrgDefaults();
        }
        
        
        List<ContentVersion> contentVersionList = new List<ContentVersion>();
        if (!doc.ContentDocumentLinks.isEmpty())
        {
            String contentId = docs[0].ContentDocumentLinks[0].ContentDocumentId; 
            contentVersionList = getCurrentVersion(parentId, contentId);  
            if (!contentVersionList.isEmpty())
                fileExt = contentVersionList[0].FileExtension;
        }
        DocumentCheckOutWrapper checkStatus = new DocumentCheckOutWrapper();
        checkStatus.docRendition = doc.Rendition_Available__c;
        checkStatus.statusMessage = '';
        checkStatus.statusType = 'success';
        String docStatus = doc.Status__c;
        if (!checkInStatuses.contains(docStatus))
        {
            checkStatus.checkOut = false; 
            checkStatus.checkIn = false; 
            checkStatus.checkOutBy = '';
            checkStatus.checkOutOn = '';
            checkStatus.cancelCheck = false;                    
            checkStatus.myCheckOut = false;
        }
        else
        {
            if (fileExt == 'NA')
            {
                checkStatus.checkOut = false; 
                checkStatus.checkIn = true; 
                checkStatus.checkOutBy = '';
                checkStatus.checkOutOn = '';
                checkStatus.cancelCheck = false;                    
                checkStatus.myCheckOut = false;
            }
            else if (fileExt == 'pdf')
            {
                checkStatus.checkOut = false; 
                checkStatus.checkIn = true; 
                checkStatus.checkOutBy = '';
                checkStatus.checkOutOn = '';
                checkStatus.cancelCheck = false;                    
                checkStatus.myCheckOut = false;
            }
            else
            {
                if (doc.Checked_Out__c)
                {
                    checkStatus.checkOut = false; 
                    checkStatus.checkIn = false; 
                    checkStatus.checkOutBy = doc.Check_Out_Name__c ;
                    checkStatus.checkOutOn = doc.Checked_Out_On__c.format();
                    if ((doc.OwnerId == Userinfo.getUserId() && actionType !='InitUser') || doc.Checked_Out_By__c == Userinfo.getUserId())
                        checkStatus.cancelCheck = true;
                    else 
                        checkStatus.cancelCheck = false;
                    if (doc.Checked_Out_By__c == UserInfo.getUserId())
                    {
                        checkStatus.myCheckOut = true;
                            checkStatus.checkIn = true;
                    }
                    else 
                    {
                        checkStatus.myCheckOut = false;
                        checkStatus.checkIn = false;
                    }
                }
                else
                {
                    checkStatus.checkOut = true; 
                    checkStatus.checkIn = false; 
                    checkStatus.checkOutBy = '';
                    checkStatus.checkOutOn = '';
                    checkStatus.cancelCheck = false;                    
                    checkStatus.myCheckOut = false;
                }
                
            }
            
        }
        
        if (actionType == 'In' )
        {
            if (!doc.Tasks.isEmpty())
            {
                List<Task> taskList = doc.Tasks;
                for (Task task_i : taskList)
                {
                    task_i.Check_In_User__c = UserInfo.getName();
                }
                if (Schema.sObjectType.Task.isUpdateable())
                {
                    update taskList;
                }
                
            }
            doc.Checked_Out__c = false;
            doc.Checked_Out_By__c = null;
            doc.Checked_Out_On__c = null;
            checkStatus.checkOutBy = '';
            checkStatus.checkOutOn = '';            
            checkStatus.checkIn = false;     
            checkStatus.checkOut = true;            
            checkStatus.cancelCheck = false;                    
            checkStatus.myCheckOut = false;
            checkStatus.statusMessage = 'Document has been checked-in successfully';
            if (!doc.Tasks.isEmpty())
            {
                List<Task> taskList = doc.Tasks;
                for (Task task_i : taskList)
                {
                    task_i.Check_In_User__c = UserInfo.getName();
                }
                if (Schema.sObjectType.Task.isUpdateable())
                    update taskList;
                
                
            }
            if (Schema.sObjectType.Controlled_Document__c.isUpdateable())
                update doc;
        }
        else if (actionType == 'CheckIn' && !checkStatus.checkIn)
        {
            checkStatus.statusMessage = 'Document cannot be checked-in by you at this stage';
            checkStatus.statusType = 'error';
        }
        
        
        if (actionType == 'Out' && !doc.Checked_Out__c  )
        {
            doc.Checked_Out__c = true;
            doc.Checked_Out_By__c = Userinfo.getUserId();                
            DateTime nowDate = System.now();
            doc.Checked_Out_On__c = nowDate;
            checkStatus.checkOutBy = Userinfo.getName();
            checkStatus.checkOutOn = nowDate.format();
            checkStatus.checkIn = true; 
            checkStatus.checkOut = false;            
            checkStatus.cancelCheck = true; 
            checkStatus.myCheckOut = true;
            if (!doc.Tasks.isEmpty())
            {
                List<Task> taskList = doc.Tasks;
                for (Task task_i : taskList)
                {
                    task_i.Check_In_User__c = null;
                }
                if (Schema.sObjectType.Task.isUpdateable())
                    update taskList;
                
            }
            if (Schema.sObjectType.Controlled_Document__c.isUpdateable())
                update doc;
            checkStatus.statusMessage = 'Document was checked-out to your computer';
        }
        
        if (actionType == 'Cancel' && checkStatus.cancelCheck )
        {
            doc.Checked_Out__c = false;
            doc.Checked_Out_By__c = null;
            doc.Checked_Out_On__c = null;
            checkStatus.checkOutBy = '';
            checkStatus.checkOutOn = '';
            checkStatus.checkIn = false; 
            checkStatus.checkOut = true;            
            checkStatus.cancelCheck = false;                    
            checkStatus.myCheckOut = false;  
            if (!doc.Tasks.isEmpty())
            {
                List<Task> taskList = doc.Tasks;
                for (Task task_i : taskList)
                {
                    task_i.Check_In_User__c = UserInfo.getName();
                }
                if (Schema.sObjectType.Task.isUpdateable())
                    update taskList;
                
            }
            if (String.isNotBlank(comment))
            {
                GenericAuditTrailHandler.fieldToCommentMap = new Map<String,String>();
                GenericAuditTrailHandler.fieldToCommentMap.put(Helper.ORG_PREFIX+'Checked_Out__c',comment);                
                GenericAuditTrailHandler.fieldToCommentMap.put(Helper.ORG_PREFIX+'Checked_Out_By__c',comment); 
            }
            if (Schema.sObjectType.Controlled_Document__c.isUpdateable())
                update doc;
        }
        //system.debug('checkStatus'+checkStatus);
        return JSON.Serialize(checkStatus);     
    }
    
    // Wrapper class for the document status
    public class DocumentStatusWrapper {
        public String documentId{get; set;}
        public String contentId{get; set;}
        public String previousId{get; set;}
        public String documentName{get; set;}
        public Decimal documentSize{get; set;}
        public Integer noVersions{get; set;}
        public ContentVersion lastVersion{get; set;}
        public DocumentCheckOutWrapper checkStatus{get; set;}
        public String status{get; set;}
        public String documentType{get; set;}
        public Boolean isEffective{get; set;}
        public Boolean isRevision{get; set;}
        public Boolean hideCheckButton{get; set;}
    }
    
    
        // Wrapper class for the document status
    public class DocumentVersion {
        public String versionId{get; set;}
        public String contentId{get; set;}
        public String name{get; set;}
        public String extension{get; set;}
        public Decimal size{get; set;}
        public String reason{get; set;}
        public DateTime contentDate{get; set;}
        public String modifier{get; set;}
        public Decimal versionNo{get; set;}
    }
    
}