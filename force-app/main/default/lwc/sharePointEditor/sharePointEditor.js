import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

import getEmbedUrl from '@salesforce/apex/SharePointFileEditorController.getEmbedUrl';
import getEditorUrl from '@salesforce/apex/SharePointFileEditorController.getEditorUrl';
import getRecordName from '@salesforce/apex/SharePointFileEditorController.getRecordName';
import saveDocumentToSF from '@salesforce/apex/SharePointFileEditorController.saveDocumentToSF';
import getDownloadLink from '@salesforce/apex/SharePointFileEditorController.getDownloadLink';
import uploadFileToSharePoint from '@salesforce/apex/SharePointFileEditorController.uploadFileToSharePoint';
import isFileAttached from '@salesforce/apex/SharePointFileEditorController.isFileAttached';
import isUserHasAccessToDocument from '@salesforce/apex/SharePointFileEditorController.isUserHasAccessToDocument';
import getDocumentStatus from '@salesforce/apex/SharePointFileEditorController.getDocumentStatus';
// import getFileSize from '@salesforce/apex/SharePointFileEditorController.getFileSize';
import getFileMimeType from '@salesforce/apex/SharePointFileEditorController.getFileMimeType';
import getOneDriveDirectUrl from '@salesforce/apex/SharePointFileEditorController.getOneDriveDirectUrl';
import isCollaborationEnabled from '@salesforce/apex/SharePointFileEditorController.isCollaborationEnabled';

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

export default class SharePointEditor extends NavigationMixin(LightningElement) {
    @api recordId;
    @api showPreview;
    @api openInDesktop;

    @track embedUrl;
    @track editUrl;
    @track iconname = 'doctype:unknown';
    @track noDocument = false;
    @track displayUploadToSharePoint = false;
    @track displayIframe = false;
    @track trackChangesEnabled = false;

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
        
        if (this.openInDesktop === true) {
            this.selectedEditor = this.editors.desktop;
            this.alternativeEditor = this.editors.web;
        }
        else {
            this.selectedEditor = this.editors.web;
            this.alternativeEditor = this.editors.desktop;
        }

        try {
            this.editUrl = await getEditorUrl({
                controlledDocumentId: this.recordId
            });
        
            this.embedUrl = await getEmbedUrl({
                controlledDocumentId: this.recordId
            });
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
        this.editUrl = await getEditorUrl({
            controlledDocumentId: this.recordId
        });

        const refresh = () => {
            this.refreshEditor({});
        }

        const fileMimeType = await getFileMimeType({
            controlledDocumentId: this.recordId
        });
        const desktopUrl = ((this.desktopEditorLinksByMimeType[fileMimeType] ?? this.desktopEditorLinksByMimeType['word']) + await getOneDriveDirectUrl({
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
    
    async downloadToPC(event) {
        const downloadLink = await getDownloadLink({
            controlledDocumentId: this.recordId
        });

        const download = document.createElement('a');
        download.href = downloadLink;
        download.download = this.filename;
        download.click();
    }

    async downloadToSF(event) {
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
        this.maximized = true;
    }

    closePopup(event) {
        this.maximized = false;
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