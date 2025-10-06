@isTest
public class ObjectFieldServiceTest {

    @isTest
    static void testGetAccessibleFields() {
        List<ObjectFieldService.FieldWrapper> fields = ObjectFieldService.getAccessibleFields('Account');
        System.assert(fields.size() > 0, 'Should return accessible fields for Account');
        Boolean foundName = false;
        for (ObjectFieldService.FieldWrapper f : fields) {
            if (f.apiName == 'Name') {
                foundName = true;
                System.assertEquals('Account Name', f.label, 'Label should match');
                System.assertEquals('STRING', String.valueOf(f.type).toUpperCase(), 'Type should be STRING');
            }
        }
        System.assert(foundName, 'Should include Name field');
    }

    @isTest
    static void testGetUpdateableFields() {
        List<ObjectFieldService.FieldWrapper> fields = ObjectFieldService.getUpdateableFields('Account');
        System.assert(fields.size() > 0, 'Should return updateable fields for Account');
        for (ObjectFieldService.FieldWrapper f : fields) {
            System.assert(f.isUpdateable, 'All fields should be updateable');
        }
    }

    @isTest
    static void testGetCreateableFields() {
        List<ObjectFieldService.FieldWrapper> fields = ObjectFieldService.getCreateableFields('Account');
        System.assert(fields.size() > 0, 'Should return createable fields for Account');
        for (ObjectFieldService.FieldWrapper f : fields) {
            System.assert(f.isCreateable, 'All fields should be createable');
        }
    }

    @isTest
    static void testInvalidObject() {
        Boolean exceptionThrown = false;
        try {
            ObjectFieldService.getAccessibleFields('NonExistentObject');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Should throw exception for invalid object');
    }
}