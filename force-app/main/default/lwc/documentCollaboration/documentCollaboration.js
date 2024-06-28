import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

import getSharePointEmbedUrl from '@salesforce/apex/SharePointFileEditorController.getEmbedUrl';
import getSharePointEditorUrl from '@salesforce/apex/SharePointFileEditorController.getEditorUrl';
import getRecordName from '@salesforce/apex/SharePointFileEditorController.getRecordName';
import saveDocumentToSF from '@salesforce/apex/SharePointFileEditorController.saveDocumentToSF';
import getDownloadLink from '@salesforce/apex/SharePointFileEditorController.getDownloadLink';
import uploadFileToSharePoint from '@salesforce/apex/SharePointFileEditorController.uploadFileToSharePoint';
import isFileAttached from '@salesforce/apex/SharePointFileEditorController.isFileAttached';
import isUserHasAccessToDocument from '@salesforce/apex/SharePointFileEditorController.isUserHasAccessToDocument';
import getDocumentStatus from '@salesforce/apex/SharePointFileEditorController.getDocumentStatus';
import getFileMimeType from '@salesforce/apex/SharePointFileEditorController.getFileMimeType';
import getOneDriveDirectUrl from '@salesforce/apex/SharePointFileEditorController.getOneDriveDirectUrl';
import isCollaborationEnabled from '@salesforce/apex/SharePointFileEditorController.isCollaborationEnabled';
import getSelectedCollaboration from '@salesforce/apex/DocumentCollaborationToolHelper.getSelectedCollaboration';

import getGoogleEditorUrl from '@salesforce/apex/GoogleEditorController.getEditorUrl';
import downloadFileFromGoogle from '@salesforce/apex/GoogleEditorController.saveDocument';
import getGoogleDownloadLink from '@salesforce/apex/GoogleEditorController.getDownloadLink';

import editLabel from '@salesforce/label/c.sharepoint_edit';
import refreshLabel from '@salesforce/label/c.sharepoint_refresh';
import downloadLabel from '@salesforce/label/c.sharepoint_download';
import uploadToSharePointLabel from '@salesforce/label/c.sharepoint_uploadtosharepoint';
import uploadToSimploudLabel from '@salesforce/label/c.sharepoint_uploadtosimploud';
import openInDesktopLabel from '@salesforce/label/c.sharepoint_openindesktop';
import openInWebLabel from '@salesforce/label/c.sharepoint_openinweb';
import openInDesktopIcon from '@salesforce/label/c.sharepoint_openindesktop_icon';
import openInWebIcon from '@salesforce/label/c.sharepoint_openinweb_icon';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class DocumentCollaboration extends NavigationMixin(LightningElement) {
    @api recordId;
    @api showPreview;
    @api openInDesktop;
    @api usePopup;

    @track embedUrl;
    @track editUrl;
    @track iconname = 'doctype:unknown';
    @track noDocument = false;
    @track displayUploadToSharePoint = false;
    @track displayIframe = false;
    @track trackChangesEnabled = false;

    @track openInGoogleLabelValue = 'Edit';
    @track openInGoogleIconName = 'utility:edit';

    @track showPopup = false;

    inEdit = false;

    @track selectedIntegration = {
        'SharePoint': true,
        'Google': false
    };

    editors = {
        web: {
            id: 'web',
            name: openInWebLabel ?? 'Edit in Web App',
            iconName: openInWebIcon ?? 'utility:http'
        },
        desktop: {
            id: 'desktop',
            name: openInDesktopLabel ?? 'Edit in Desktop',
            iconName: openInDesktopIcon ?? 'utility:desktop'
        }
    }

    desktopEditorLinksByMimeType = {
        word: 'ms-word:ofe|u|',
        excel: 'ms-excel:ofe|u|',
        ppt: 'ms-powerpoint:ofe|u|',
        unknown: ''
    }

    @track selectedEditor = this.editors.desktop;
    @track alternativeEditor = this.editors.web;

    filename;

    editLabelValue;
    refreshLabelValue;
    downloadLabelValue;
    uploadToSimploudLabelValue;
    uploadToSharePointLabelValue;

    async connectedCallback() {
        this.displayIframe = await isCollaborationEnabled({
            controlledDocumentId: this.recordId
        });

        if (!this.displayIframe) return;

        const selectedIntegration = await getSelectedCollaboration({});

        this.selectedIntegration[selectedIntegration] = true;
        this.selectedIntegration[Object.keys(this.selectedIntegration).filter(integration => integration != selectedIntegration)[0]] = false;
        
        if (this.openInDesktop === true) {
            this.selectedEditor = this.editors.desktop;
            this.alternativeEditor = this.editors.web;
        }
        else {
            this.selectedEditor = this.editors.web;
            this.alternativeEditor = this.editors.desktop;
        }

        try {
            if (this.selectedIntegration.SharePoint) {
                this.editUrl = await getSharePointEditorUrl({
                    controlledDocumentId: this.recordId
                });
            
                this.embedUrl = await getSharePointEmbedUrl({
                    controlledDocumentId: this.recordId
                });
            }
            else {
                this.editUrl = await getGoogleEditorUrl({
                    recordId: this.recordId
                });

                this.displayIframe = !(this.editUrl == null || this.editUrl == '' || this.editUrl == undefined || this.editUrl == 'undefined' || this.editUrl == 'null');


                this.embedUrl = this.editUrl + '/preview';
            }
        }
        catch (error) {
            if (await isFileAttached({
                    controlledDocumentId: this.recordId
                })) {

                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Error',
                        message: error.body.message,
                        variant: 'error'
                    }));

                    this.displayUploadToSharePoint = true;
                }
            
            this.noDocument = true;
        }

        try {
            this.filename = await getRecordName({
                controlledDocumentId: this.recordId
            });
        } 
        catch (error) {
        }

        this.editLabelValue = editLabel || 'Edit';
        this.refreshLabelValue = refreshLabel || 'Refresh';
        this.downloadLabelValue = downloadLabel || 'Download';
        this.uploadToSimploudLabelValue = uploadToSimploudLabel || 'Upload to Simploud';
        this.uploadToSharePointLabelValue = uploadToSharePointLabel || 'Upload to SharePoint';
    }

    async openEditor(event) {
        if (this.selectedIntegration.Google) {
            this.editUrl = await getGoogleEditorUrl({
                recordId: this.recordId
            });

            this.openPopup();
        }
        else {
            this.editUrl = await getSharePointEditorUrl({
                controlledDocumentId: this.recordId
            });

            const fileMimeType = await getFileMimeType({
                controlledDocumentId: this.recordId
            });
            const desktopUrl = ((this.desktopEditorLinksByMimeType[fileMimeType] ?? '') + await getOneDriveDirectUrl({
                controlledDocumentId: this.recordId
            }));

            if (this.selectedEditor.id == 'desktop') {
                const editorLink = document.createElement('a');
                editorLink.href = desktopUrl
                editorLink.target = '';
                editorLink.click();
            }
            else {
                const refresh = () => {
                    this.refreshEditor({});
                }

                const openedPage = window.open(this.editUrl, '_blank');
                const timer = setInterval(() => {
                    if (openedPage.closed) {
                        refresh();
                        clearInterval(timer);
                    }
                }, 500);
            }
        }
    }
    
    async downloadToPC(event) {
        if (this.selectedIntegration.Google) {
            const downloadLink = await getGoogleDownloadLink({
                recordId: this.recordId
            });

            const download = document.createElement('a');
            download.href = downloadLink;
            download.download = this.filename;
            download.click();

            return;
        }
        else {
            const downloadLink = await getDownloadLink({
                controlledDocumentId: this.recordId
            });

            const download = document.createElement('a');
            download.href = downloadLink;
            download.download = this.filename;
            download.click();
        }
    }

    async downloadToSF(event) {
        if (this.selectedIntegration.Google) {
            await downloadFileFromGoogle({
                recordId: this.recordId
            });

            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Document has been saved in Salesforce',
                variant: 'success'
            }));

            return;
        }
        else {
            try {
                await saveDocumentToSF({
                    controlledDocumentId: this.recordId
                });
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'Document has been saved in Salesforce',
                    variant: 'success'
                }));
            }
            catch (e) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: e.body.message,
                    variant: 'error'
                }));
            }
        }
    }

    async uploadToSharePoint(event) {
        await uploadFileToSharePoint({
            controlledDocumentId: this.recordId
        });
    }

    async iframeLoaded(event) {
        console.log(JSON.stringify(event));
        console.log(event.target);
    }
    
    openPopup(event) {
        if (!this.usePopup) {
            if (this.inEdit) {
                this.embedUrl = this.editUrl + '/preview';
                this.openInGoogleLabelValue = 'Edit';
                this.openInGoogleIconName = 'utility:edit';
                this.inEdit = false;
            }
            else {
                this.embedUrl = this.editUrl.replace('/preview', '');
                this.openInGoogleLabelValue = 'Close';
                this.openInGoogleIconName = 'utility:close';
                this.inEdit = true;
            }
            return;
        }

        // this.showPopup = true;
        const newTab = window.open(this.editUrl, '_blank');
        const timer = setInterval(() => {
            if (newTab.closed) {
                this.refreshEditor({});
                clearInterval(timer);
            }
        }, 500);
    }

    closePopup(event) {
        if (!this.usePopup) {
            this.embedUrl = this.editUrl + '/preview';
            return;
        }

        this.showPopup = false;
        this.refreshEditor({});
    }

    refreshEditor(event) {
        this.noDocument = !this.noDocument;
        setTimeout(() => {
            this.noDocument = !this.noDocument;
            this.connectedCallback();
        }, 50);
    }

    toggleSwitchEditor(event) {
        const optionsComponent = this.template.querySelector('[data-id="alternative-editor-options"]');
        optionsComponent.classList.toggle('slds-hidden');
    }

    switchEditors(event) {
        this.selectedEditor = this.editors[this.selectedEditor.id == 'web' ? 'desktop' : 'web']
        this.alternativeEditor = this.editors[this.selectedEditor.id == 'web' ? 'desktop' : 'web'];
        this.toggleSwitchEditor();
        this.openEditor();
    }
}