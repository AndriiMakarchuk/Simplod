public with sharing class WordUtils {
    private class CannotEnableTrackChangesException extends Exception {}

    public static Blob enableTrackChangesForDocument(Id contentVersionId) {
        ContentVersion cv = [Select Id, VersionData, ContentDocumentId, PathOnClient, FileExtension, Title FROM ContentVersion WHERE Id=:contentVersionId WITH SECURITY_ENFORCED];

        // if (cv.FileExtension != 'docx') {
            return cv.VersionData;
        // }

        // if (cv.VersionData.size() > 1572864) {
        //     return cv.VersionData;
        // }

        // Zippex myZip = new Zippex(cv.VersionData);
        // String docXml = myZip.getFile('word/settings.xml').toString();

        // if (docXml.contains('<w:trackRevisions w:val="true"/>')) {
        //     return cv.VersionData;
        // }

        // docXml = docXml.replace('</w:settings>', '<w:trackRevisions w:val="true"/></w:settings>');

        // if (!docXml.contains('<w:trackRevisions')) {
        //     throw new CannotEnableTrackChangesException('Could not enable track changes for document');
        // }

        // Zippex output = new Zippex();
        // Set <String> fileNames = myZip.getFileNames();
        // for (String fileName : fileNames) {
        //     if (fileName.contains('settings.xml')) continue;
            
        //     output.addFile(fileName, myZip.getFile(fileName), null);
        // }
        // myZip.removeFile('word/settings.xml');
        // myZip.addFile('word/settings.xml', Blob.valueOf(docXml), null);

        // return myZip.getZipArchive();
    }
}