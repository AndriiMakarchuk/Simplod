@isTest
public with sharing class NamedCredsRefreshJobTest {
    @isTest
    public static void testNamedCredsRefreshJob() {
        Test.setMock(HttpCalloutMock.class, new HttpMock());

        Test.startTest();

        Exception e;
        try {
            NamedCredsRefreshJob job = new NamedCredsRefreshJob();
            job.execute(null);
        } catch (Exception ex) {
            e = ex;
        }

        Test.stopTest();

        System.assert(e == null, 'Expected exception not to be thrown');
    }

    private class HttpMock implements HttpCalloutMock{
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"access_token":"123","instance_url":"https://na1.salesforce.com"}');
            return res;
        }
    }
}