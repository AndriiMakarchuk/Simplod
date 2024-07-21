({
    MAX_FILE_SIZE: 4500000, //Max file size 4.5 MB 
    CHUNK_SIZE: 750000,      //Chunk Max size 750Kb 
    
    doInit : function(component, event, helper) {
        var actionImage = component.get("c.getAttachmentContentLink");
        actionImage.setParams({
            parentId : component.get("v.recordId")
        });
        
        actionImage.setCallback(this, function(rep){
            if(rep.getReturnValue())
            {
                var resp = JSON.parse(rep.getReturnValue());
                if (resp) {
                    if (resp.lastVersion)
                    {
                        var versionId = resp.lastVersion.Id; 
                        var contentId = resp.lastVersion.ContentDocumentId; 
                        var src = "/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=" + versionId + "&contentId=" + contentId;
                        component.set("v.imageSrc", src);
                        component.set("v.ContentDocumentId", resp.contentId);
                        component.set("v.contentDocumentHref", '/sfc/servlet.shepherd/version/download/' + versionId );
                        var docName = resp.documentName;
                        if ( docName && docName.length > 35)
                        {
                            docName =  docName.substring(0, 35) + "...";
                        }
                        component.set("v.docName",  docName + ' ('+  resp.noVersions +')');
                        component.set("v.contentDocNotFound", false);
                        component.set("v.isEffectiveStatus", resp.isEffective);
                        
                        component.set("v.fileExt", resp.lastVersion.FileExtension);
                        if (resp.lastVersion.ContentSize)
                        {
                            var fileSize = resp.lastVersion.ContentSize / 1048576; 
                            fileSize = fileSize.toFixed(1);
                            component.set("v.fileSize", fileSize);
                        }
                        
                    }else {
                        component.set("v.contentDocNotFound", true);
                        component.set("v.isRevisionEmpty", resp.isRevision); 
                        component.set("v.previousId", resp.previousId);     
                    }
                    component.set("v.hideCheckButton",resp.hideCheckButton)
                    var checkStatus = resp.checkStatus;
                    component.set("v.checkOut", checkStatus.checkOut); 
                    component.set("v.checkIn", checkStatus.checkIn);
                    component.set("v.cancelCheck", checkStatus.cancelCheck);
                    component.set("v.myCheckOut", checkStatus.myCheckOut);
                    component.set("v.checkedOutBy", checkStatus.checkOutBy);          
                    component.set("v.checkedOutOn", checkStatus.checkOutOn);
                    component.set("v.docRendition", checkStatus.docRendition);
                    component.set("v.isReady",true);
                    
                } else {
                    component.set("v.contentDocNotFound", true);
                    component.set("v.isReady",true);
                }
            }
        });
        
        $A.enqueueAction(actionImage);
    },
    
        
    isLightUser: function(component, event, helper) {
        
        var lightGroup = component.get("v.lightGroup");
        
        if (lightGroup)
        {
            lightGroup = lightGroup.trim();
            
            var isLight = component.get("c.isGroupMember");
            isLight.setParams({
                groupName: lightGroup
            });        
            
            isLight.setCallback(this, function(rep){
                var resp = rep.getReturnValue();
                if (resp) {
                    component.set("v.isLight",true);
                } 
                else
                {
                    component.set("v.isLight",false);
                }
                
            });
            
            $A.enqueueAction(isLight); 
        }
        else
        {
            component.set("v.isLight",false);
        }
    },
    
    
    checkStatus : function(component, event, helper) {
        
        var action = component.get("c.getCheckOutStatus");
        var actionType = component.get("v.docAction");
        if (actionType == 'Word')
        {
            var eUrl= $A.get("e.force:navigateToURL");
            eUrl.setParams({
                "url": component.get("v.contentDocumentHref")
            });
            eUrl.fire();
            // Open in the same tab window.location.href = component.get("v.contentDocumentHref","_blank");
            return;
        } 
        
        action.setParams({
            parentId : component.get("v.recordId"),
            actionType : actionType,
            comment : component.get("v.comment")
        });
        
        action.setCallback(this, function(rep){
            var state = rep.getState();
            if (state === "SUCCESS") {
                var docStatus = JSON.parse(rep.getReturnValue());
                var checkStatus = docStatus;
                if (docStatus.checkStatus)
                {
                    checkStatus = docStatus.checkStatus;
                }
                var checkStatus = docStatus;
                component.set("v.checkOut", checkStatus.checkOut);
                component.set("v.checkIn", checkStatus.checkIn);
                component.set("v.cancelCheck", checkStatus.cancelCheck);
                component.set("v.checkedOutBy", checkStatus.checkOutBy);          
                component.set("v.checkedOutOn", checkStatus.checkOutOn);
                component.set("v.docRendition", checkStatus.docRendition);
                component.set("v.myCheckOut", checkStatus.myCheckOut);
                component.set("v.comment","");
                
                if (actionType == 'CheckIn' && checkStatus.checkIn)
                {
                    component.set("v.showFileInput", true); 
                }
                if (actionType == 'In' && checkStatus.statusMessage && checkStatus.statusType == 'success')
                {
                    helper.showToast('success',checkStatus.statusMessage);
                    component.set("v.showFileInput", false); 
                    if (component.get("v.viewerMode") == "status")
                    {               
                        var evt = $A.get("e.c:genericDataEvent");
                        evt.setParams({
                            eventType: "requiredFields"
                        });
                        evt.fire();
                    }
                    else{
                        $A.get('e.force:refreshView').fire();
                    }
                }
                if (actionType == 'Out' && checkStatus.myCheckOut)
                {
                    var eUrl= $A.get("e.force:navigateToURL");
                    eUrl.setParams({
                        "url": component.get("v.contentDocumentHref")
                    });
                    eUrl.fire();
                    if (checkStatus.statusMessage && checkStatus.statusType == 'success')
                    {
                        helper.showToast('success',checkStatus.statusMessage);
                    }
                } 
                if (checkStatus.statusMessage && checkStatus.statusType == 'error')
                {
                    helper.showToast('error',checkStatus.statusMessage);
                }
            }
        });          
        $A.enqueueAction(action);
    },
    
            
    getFile: function (component,event,helper,objectName) {
        var action = component.get("c.getPreviousFile");
        action.setParams({
            parentId : component.get("v.recordId"),
            previousId : previousVersion
        });
        action.setCallback(this, function(rep){
            var resp = rep.getReturnValue();
            if (resp) {
                
            }
        });
        
        $A.enqueueAction(action); 
    },
    
        
    getVersions: function(component, event, helper) {
        var contentId = component.get("v.ContentDocumentId");
        var action = component.get("c.getFileVersions");
        action.setParams({
            fileId : contentId
        });
        action.setCallback(this, function(rep){
            var resp = JSON.parse(rep.getReturnValue());
            if (resp && resp.length>0) {
                resp.sort(function(a,b){
                    if(a.versionNo<b.versionNo) return 1;
                    if(a.versionNo>b.versionNo) return -1;
                    return 0;
                });
                component.set("v.versionList", resp);
                component.set("v.showVersions", true);
            }
        });
        
        $A.enqueueAction(action); 
    },
    
    
    showToast: function(type, message){
        var toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            mode: 'pester',
            duration: 5000,
            message: message,
            type: type
        });
        toastEvent.fire();
        
    }
    
    
    
})