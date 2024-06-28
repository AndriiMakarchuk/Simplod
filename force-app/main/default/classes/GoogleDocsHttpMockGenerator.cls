@isTest
public class GoogleDocsHttpMockGenerator implements HttpCalloutMock {
    private final RestResourceWrapper uploadFile = new RestResourceWrapper('/upload/drive/v3/files', 'POST');
    private final RestResourceWrapper getFile = new RestResourceWrapper('/drive/v3/files', 'GET');
    private final RestResourceWrapper deleteFile = new RestResourceWrapper('/drive/v3/files/', 'DELETE');
    private final RestResourceWrapper downloadFile = new RestResourceWrapper('/export', 'GET');
    private final RestResourceWrapper updateFile = new RestResourceWrapper('/upload/drive/v3/files/', 'PATCH');
    private final RestResourceWrapper deletePermission = new RestResourceWrapper('/permissions', 'DELETE');
    private final RestResourceWrapper createPermission = new RestResourceWrapper('/permissions', 'POST');

    private String body = '';
    private Blob bodyBlob;
    private Integer code = 404;
    private String status = 'Not Found';
    private Map<String, String> responseHeaders = new Map<String, String>();

    public GoogleDocsHttpMockGenerator() {
    }
    
    public HTTPResponse respond(HTTPRequest req) {
        if (uploadFile.isEqual(req)) {
            body = '{"id": "1"}';
            code = 200;
            status = 'OK';
            responseHeaders.put('Content-Type', 'application/json');
        } else if (downloadFile.isEqual(req)) {
            bodyBlob = Blob.valueOf('Hello World');
            code = 200;
            status = 'OK';
            responseHeaders.put('Content-Type', 'text/plain');
        } else if (getFile.isEqual(req)) {
            body = '{"files": []}';
            code = 200;
            status = 'OK';
            responseHeaders.put('Content-Type', 'application/json');
        } else if (deleteFile.isEqual(req)) {
            code = 204;
            status = 'No Content';
            responseHeaders.put('Content-Type', 'application/json');
        } else if (updateFile.isEqual(req)) {
            body = '{"id": "1"}';
            code = 200;
            status = 'OK';
            responseHeaders.put('Content-Type', 'application/json');
        } else if (deletePermission.isEqual(req)) {
            body = '';
            code = 204;
            status = 'No Content';
            responseHeaders.put('Content-Type', 'application/json');
        } else if (createPermission.isEqual(req)) {
            body = '{"id": "123"}';
            code = 200;
            status = 'OK';
            responseHeaders.put('Content-Type', 'application/json');
        }

        HttpResponse res = new HttpResponse();

        if (bodyBlob != null) {
            res.setBodyAsBlob(bodyBlob);
        }
        else {
            res.setBody(body);
        }

        res.setStatusCode(code);
        res.setStatus(status);

        for (String key : responseHeaders.keySet()) {
            res.setHeader(key, responseHeaders.get(key));
        }

        return res;
    }

    private class RestResourceWrapper {
        public String endpoint;
        public String method;

        public RestResourceWrapper(String endpoint, String method) {
            this.endpoint = endpoint;
            this.method = method;
        }

        public Boolean isEqual(HttpRequest req) {
            return req.getMethod() == this.method && req.getEndpoint().contains(this.endpoint);
        }
    }
}