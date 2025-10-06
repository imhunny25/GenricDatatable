public with sharing class ObjectFieldService {
    
    /**
     * Returns all accessible fields for a given object
     * @param objectApiName - API name of the object (e.g., 'Account', 'Contact')
     * @return List of FieldWrapper containing field details
     */
    @AuraEnabled(cacheable=true)
    public static List<FieldWrapper> getAccessibleFields(String objectApiName) {
        List<FieldWrapper> fieldList = new List<FieldWrapper>();
        
        try {
            // Get the object describe
            Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectApiName);
            
            if (objectType == null) {
                throw new AuraHandledException('Object not found: ' + objectApiName);
            }
            
            // Check if user has access to the object
            Schema.DescribeSObjectResult objectDescribe = objectType.getDescribe();
            if (!objectDescribe.isAccessible()) {
                throw new AuraHandledException('You do not have access to this object');
            }
            
            // Get all fields
            Map<String, Schema.SObjectField> fieldMap = objectDescribe.fields.getMap();
            
            // Iterate through fields and check accessibility
            for (String fieldName : fieldMap.keySet()) {
                Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
                
                // Only include accessible fields
                if (fieldDescribe.isAccessible()) {
                    FieldWrapper field = new FieldWrapper();
                    field.apiName = fieldDescribe.getName();
                    field.label = fieldDescribe.getLabel();
                    field.type = String.valueOf(fieldDescribe.getType());
                    field.isRequired = !fieldDescribe.isNillable() && !fieldDescribe.isDefaultedOnCreate();
                    field.isUpdateable = fieldDescribe.isUpdateable();
                    field.isCreateable = fieldDescribe.isCreateable();
                    field.length = fieldDescribe.getLength();
                    field.isCustom = fieldDescribe.isCustom();
                    
                    fieldList.add(field);
                }
            }
            
            // Sort by label
            fieldList.sort();
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving fields: ' + e.getMessage());
        }
        System.debug('Field List: ' + JSON.serialize(fieldList));
        return fieldList;
    }
    
    /**
     * Returns only updateable fields for a given object
     * @param objectApiName - API name of the object
     * @return List of FieldWrapper containing updateable field details
     */
    @AuraEnabled(cacheable=true)
    public static List<FieldWrapper> getUpdateableFields(String objectApiName) {
        List<FieldWrapper> allFields = getAccessibleFields(objectApiName);
        List<FieldWrapper> updateableFields = new List<FieldWrapper>();
        
        for (FieldWrapper field : allFields) {
            if (field.isUpdateable) {
                updateableFields.add(field);
            }
        }
        
        return updateableFields;
    }
    
    /**
     * Returns only createable fields for a given object
     * @param objectApiName - API name of the object
     * @return List of FieldWrapper containing createable field details
     */
    @AuraEnabled(cacheable=true)
    public static List<FieldWrapper> getCreateableFields(String objectApiName) {
        List<FieldWrapper> allFields = getAccessibleFields(objectApiName);
        List<FieldWrapper> createableFields = new List<FieldWrapper>();
        
        for (FieldWrapper field : allFields) {
            if (field.isCreateable) {
                createableFields.add(field);
            }
        }
        
        return createableFields;
    }
    
    /**
     * Wrapper class to hold field information
     */
    public class FieldWrapper implements Comparable {
        @AuraEnabled public String apiName { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String type { get; set; }
        @AuraEnabled public Boolean isRequired { get; set; }
        @AuraEnabled public Boolean isUpdateable { get; set; }
        @AuraEnabled public Boolean isCreateable { get; set; }
        @AuraEnabled public Integer length { get; set; }
        @AuraEnabled public Boolean isCustom { get; set; }
        
        // Implement Comparable interface to sort by label
        public Integer compareTo(Object compareTo) {
            FieldWrapper compareToField = (FieldWrapper) compareTo;
            if (label == compareToField.label) return 0;
            if (label > compareToField.label) return 1;
            return -1;
        }
    }
}