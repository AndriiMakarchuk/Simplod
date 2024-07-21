({
  doInit : function(component, event, helper) {
      helper.doInit(component, event, helper);
      helper.isLightUser(component, event, helper);     
  },

  uploadFile: function(component, event, helper) {
    component.set("v.docAction", "CheckIn");
    helper.checkStatus(component, event, helper);
  },

  uploadFileCancel: function(component, event, helper) {
    component.set("v.showFileInput", false);
  },

  viewVersions: function(component, event, helper) {
       var versionsLink = '/lightning/r/' + component.get("v.ContentDocumentId") + '/related/ContentVersions/view';
       var eUrl= $A.get("e.force:navigateToURL");
                    eUrl.setParams({
                        "url": versionsLink
                    });
                    eUrl.fire();
  },
    
    getVersions: function(component, event, helper) {
        helper.getVersions(component, event, helper);
    },
    
    closeVersions: function(component, event, helper) {
        component.set("v.showVersions", false);
    },
    
    
    
    
    checkOut: function(component, event, helper) {
        component.set("v.docAction", "Out");
        helper.checkStatus(component, event, helper);
    },
    
    wordVersion: function(component, event, helper) {
        component.set("v.docAction", "Word");
        helper.checkStatus(component, event, helper);
    },
    
    
    cancelCheckOut: function(component, event, helper) {
        component.set("v.docAction", "Cancel");
        if (component.get("v.requestComment"))
        {
            component.set("v.addComment", true);
        }
        else
        {
            helper.checkStatus(component, event, helper);
        }
    },
    
     
    closeComment: function(component, event, helper) {
        component.set("v.docAction", "");
        component.set("v.comment", "");
        component.set("v.addComment", false);
    },
    
    submitComment: function(component, event, helper) { 
        component.set("v.addComment", false);
        helper.checkStatus(component, event, helper);
    },
    
   getFile: function(component, event, helper) {
        //helper.getFile(component, event, helper);
  },
    
    
  handleFilesChange: function(component, event, helper) {
    var fileName = ''
    if (event.getSource().get("v.files").length > 0) {
      fileName = event.getSource().get("v.files")[0]['name'];
      component.set("v.showButton", true);
    }
    component.set("v.fileName", fileName);
  },

  handleUploadFinished: function (component, event, helper) {
    component.set("v.isReady",false);
    component.set("v.docAction", "In");
    helper.checkStatus(component, event, helper);
  },

  handleImageError : function (component, event, helper) {
    component.set("v.showImage", false);
  }

})