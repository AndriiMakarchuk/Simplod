/**
 * Interface for Collaboration Tools
 * @author Danyil Mahalias
 * @since 22.09.2023
 */
public interface ICollaborationTool {
    void deleteDocuments(String[] docsUrls);
    void uploadFiles(String[] docIds);
    void saveMinorVersion(Map<Id, String> docIdStatus);
    void updatePermissions(Id[] docIds);
    void updateViewonly(Id[] docIds);
    void clearViewonly(Id[] docIds);
}