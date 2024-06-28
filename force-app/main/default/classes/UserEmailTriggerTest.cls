@isTest
public with sharing class UserEmailTriggerTest {
    @TestSetup
    static void makeData() {
        Test.enableChangeDataCapture();

        User u = new User(
            Alias = 'test',
            Email = 'testemail0@gmail.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Testing',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'testuser1545@gmail.com',
            isActive = true
        );

        insert u;

        Test.getEventBus().deliver();
    }

    @isTest
    static void testUserEmailTrigger() {
        User u = [SELECT Id, Email FROM User WHERE Email = 'testemail0@gmail.com'];
        u.Email = 'testemail1@gmail.com';
        update u;

        Test.getEventBus().deliver();

        u = [SELECT Id, Email FROM User WHERE Email = 'testemail1@gmail.com'];

        System.assertNotEquals(null, u);
    }
}