global with sharing class NamedCredsRefreshJob implements Schedulable {
    global void execute(SchedulableContext ctx) {
        try {
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:GDocs' + '/drive/v3/files');
            req.setMethod('GET');
            HttpResponse res = http.send(req);

            HttpRequest req2 = new HttpRequest();
            req2.setEndpoint('callout:SharePoint/me/drive/items/');
            req2.setHeader('Accept', 'application/json');
            req2.setHeader('Content-Type', 'application/json');
            req2.setMethod('GET');
            HttpResponse res2 = http.send(req2);
        }
        catch (Exception e) {
            System.debug('Exception: ' + e.getMessage());
        }
    }
}