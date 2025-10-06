@isTest
public class AccountManagerControllerTest {

    @testSetup
    static void setup() {
        // Create test Accounts
        List<Account> accs = new List<Account>();
        for (Integer i = 0; i < 5; i++) {
            accs.add(new Account(
                Name = 'Test Account ' + i,
                Industry = 'Apparel',
                Type = 'Customer',
                Phone = '123456789' + i
            ));
        }
        insert accs;
    }

    @isTest
    static void testGetObjectLabel() {
        String label = AccountManagerController.getObjectLabel('Account');
        System.assertEquals('Account', label, 'Should return Account label');
    }

    @isTest
    static void testUpdateAccounts() {
        Account acc = [SELECT Id, Name FROM Account LIMIT 1];
        acc.Name = 'Updated Name';
        List<SObject> sObjList = new List<SObject>{ acc };
        Test.startTest();
        AccountManagerController.updateAccounts(sObjList);
        Test.stopTest();
        Account updated = [SELECT Name FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Updated Name', updated.Name, 'Account name should be updated');
    }

    @isTest
    static void testGetAccounts() {
        Map<String, Object> params = new Map<String, Object>{
            'objectApiName' => 'Account',
            'selectedFields' => new List<String>{'Id', 'Name', 'Industry', 'Type', 'Phone'},
            'searchKeyword' => '',
            'field' => '',
            'operator' => '',
            'value' => '',
            'pageNumber' => 1,
            'pageSize' => 2,
            'sortBy' => 'Name',
            'sortDirection' => 'ASC'
        };
        Map<String, Object> result = AccountManagerController.getAccounts(params);
        System.assert(result.containsKey('records'), 'Should contain records');
        System.assert(result.containsKey('totalCount'), 'Should contain totalCount');
        List<SObject> records = (List<SObject>)result.get('records');
        System.assert(records.size() > 0, 'Should return at least one record');
    }

    @isTest
    static void testGetAccountsWithSearchAndFilter() {
        Map<String, Object> params = new Map<String, Object>{
            'objectApiName' => 'Account',
            'selectedFields' => new List<String>{'Id', 'Name', 'Industry', 'Type', 'Phone'},
            'searchKeyword' => 'Test',
            'field' => 'Industry',
            'operator' => 'equals',
            'value' => 'Apparel',
            'pageNumber' => 1,
            'pageSize' => 10,
            'sortBy' => 'Name',
            'sortDirection' => 'ASC'
        };
        Map<String, Object> result = AccountManagerController.getAccounts(params);
        List<SObject> records = (List<SObject>)result.get('records');
        System.assert(records.size() > 0, 'Should return filtered records');
    }

    @isTest
    static void testGetPicklistValues() {
        Map<String, List<String>> picklistVals = AccountManagerController.getPicklistValues('Account');
        System.assert(picklistVals.containsKey('Industry'), 'Should contain Industry picklist');
        System.assert(picklistVals.get('Industry').size() > 0, 'Industry picklist should have values');
    }

    @isTest
    static void testGetObjectLabelInvalid() {
        Boolean exceptionThrown = false;
        try {
            AccountManagerController.getObjectLabel('NonExistentObject');
        } catch (Exception e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Exception should be thrown for invalid object');
    }

    @isTest
    static void testGetPicklistValuesInvalid() {
        Boolean exceptionThrown = false;
        try {
            AccountManagerController.getPicklistValues('NonExistentObject');
        } catch (Exception e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Exception should be thrown for invalid object');
    }

    @isTest
    static void testUpdateAccountsEmpty() {
        Boolean exceptionThrown = false;
        try {
            AccountManagerController.updateAccounts(new List<SObject>());
        } catch (Exception e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Exception should be thrown for empty update');
    }
}