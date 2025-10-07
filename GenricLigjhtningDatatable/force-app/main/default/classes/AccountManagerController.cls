public with sharing class AccountManagerController {
    
    @AuraEnabled(cacheable=true)
    public static String getObjectLabel(String objectApiName) {
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        if (globalDescribe.containsKey(objectApiName)) {
            Schema.SObjectType sobjectType = globalDescribe.get(objectApiName);
            Schema.DescribeSObjectResult describeResult = sobjectType.getDescribe();
            return describeResult.getLabel();
        } else {
            throw new AuraHandledException('Object not found: ' + objectApiName);
        }
    }public with sharing class AccountManagerController {
  @AuraEnabled(cacheable=true)
  public static String getObjectLabel(String objectApiName) {
    Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
    if (globalDescribe.containsKey(objectApiName)) {
      Schema.SObjectType sobjectType = globalDescribe.get(objectApiName);
      Schema.DescribeSObjectResult describeResult = sobjectType.getDescribe();
      return describeResult.getLabel();
    } else {
      throw new AuraHandledException('Object not found: ' + objectApiName);
    }
  }

  @AuraEnabled
  public static void updateAccounts(List<SObject> sObjList) {
    if (sObjList == null || sObjList.isEmpty()) {
      throw new AuraHandledException('No records provided for update.');
    }
    update as user sObjList;
  }

  @AuraEnabled(cacheable=false)
  public static Map<String, Object> getAccounts(Map<String, Object> params) {
    String objectApiName = (String) params.get('objectApiName');
    List<String> fields = new List<String>();
    if (
      params.containsKey('selectedFields') &&
      params.get('selectedFields') != null
    ) {
      for (Object f : (List<Object>) params.get('selectedFields')) {
        String fieldStr = (String) f;
        if (!fields.contains(fieldStr)) {
          fields.add(fieldStr);
        }
      }
    }
    if (!fields.contains('Id')) {
      fields.add('Id');
    } // Always select Id
    String searchKeyword = (String) params.get('searchKeyword');
    String field = (String) params.get('field');
    String operator = (String) params.get('operator');
    String value = (String) params.get('value');
    Integer pageNumber = extractInteger(params, 'pageNumber', 1);
    Integer pageSize = extractInteger(params, 'pageSize', 10);
    String sortBy = (String) params.get('sortBy');
    String sortDirection = (String) params.get('sortDirection');

    Integer offsetSize = (pageNumber - 1) * pageSize;

    // Build query
    QueryParams qp = new QueryParams();
    qp.objectApiName = objectApiName;
    qp.fields = fields;
    qp.searchKeyword = searchKeyword;
    qp.field = field;
    qp.operator = operator;
    qp.value = value;
    qp.sortBy = sortBy;
    qp.sortDirection = sortDirection;
    String baseQuery = buildBaseQuery(qp);
    System.debug('Base Query: ' + baseQuery);
    // Count query
    String countQuery = buildCountQuery(baseQuery);
    Integer totalCount = Database.countQuery(countQuery);

    // Pagination
    baseQuery += ' LIMIT ' + pageSize + ' OFFSET ' + offsetSize;
    System.debug('baseQuery: ' + baseQuery);
    List<SObject> sObjList = Database.query(baseQuery);

    return new Map<String, Object>{
      'records' => sObjList,
      'totalCount' => totalCount
    };
  }

  //Extract integer safely
  private static Integer extractInteger(
    Map<String, Object> params,
    String key,
    Integer defaultValue
  ) {
    return params.containsKey(key) && params.get(key) != null
      ? ((Decimal) params.get(key)).intValue()
      : defaultValue;
  }

  // Build base query with search + filters + sort
  private static String buildBaseQuery(QueryParams qp) {
    String selectClause =
      'SELECT ' +
      String.join(qp.fields, ', ') +
      ' FROM ' +
      qp.objectApiName +
      ' WHERE Id != null';
    String query = selectClause;

    query += applyGlobalSearch(qp.searchKeyword, qp.fields);
    query += applyAdvancedFilter(qp.field, qp.operator, qp.value);

    if (String.isNotBlank(qp.sortBy) && String.isNotBlank(qp.sortDirection)) {
      query += ' ORDER BY ' + qp.sortBy + ' ' + qp.sortDirection;
    }
    return query;
  }

  // Global search logic (searches only on text fields in fields list)
  public static String applyGlobalSearch(String keyword, List<String> fields) {
    System.debug('Global search on keyword: ' + keyword + ' fields: ' + fields);
    if (String.isBlank(keyword) || fields == null || fields.isEmpty()) {
      return '';
    }

    String safe = String.escapeSingleQuotes(keyword);

    // Validate API names and exclude Id explicitly
    List<String> validated = new List<String>();
    for (String f : fields) {
      if (f == null)
        continue;
      String t = f.trim();
      if (!Pattern.matches('^[A-Za-z0-9_\\.]+$', t))
        continue; // allow API-name tokens only [web:38]
      if (t.equalsIgnoreCase('Id'))
        continue; // always exclude Id [web:48]
      validated.add(t);
    }
    if (validated.isEmpty()) {
      return '';
    }

    // Build OR-ed LIKEs from validated fields
    List<String> likeClauses = new List<String>();
    for (String f : validated) {
      likeClauses.add(f + ' LIKE \'%' + safe + '%\'');
    }
    return ' AND (' + String.join(likeClauses, ' OR ') + ')';
  }

  // Advanced filter logic
  private static String applyAdvancedFilter(
    String field,
    String operator,
    String value
  ) {
    if (
      String.isBlank(field) ||
      String.isBlank(operator) ||
      String.isBlank(value)
    ) {
      return '';
    }

    String op = operator.toLowerCase();

    // If value is ISO datetime, do NOT quote it
    Boolean isDt = looksLikeDateTime(value);
    String safe = isDt ? value : String.escapeSingleQuotes(value);

    if (op == 'equals' || op == 'eq') {
      // For datetime, equality isn’t precise; if needed, keep simple per request
      return ' AND ' + field + ' = ' + (isDt ? safe : '\'' + safe + '\'');
    } else if (op == 'contains') {
      // Contains only makes sense for text; keep original behavior
      return ' AND ' + field + ' LIKE \'%' + safe + '%\'';
    } else if (op == 'startswith' || op == 'startsWith') {
      return ' AND ' + field + ' LIKE \'' + safe + '%\'';
    }

    // Optional: support relational operators (>, >=, <, <=) if UI sends them
    if (op == '>' || op == 'gt')
      return ' AND ' + field + ' > ' + (isDt ? safe : '\'' + safe + '\'');
    if (op == '>=' || op == 'gte')
      return ' AND ' + field + ' >= ' + (isDt ? safe : '\'' + safe + '\'');
    if (op == '<' || op == 'lt')
      return ' AND ' + field + ' < ' + (isDt ? safe : '\'' + safe + '\'');
    if (op == '<=' || op == 'lte')
      return ' AND ' + field + ' <= ' + (isDt ? safe : '\'' + safe + '\'');

    return '';
  }

  // Returns true if value looks like an ISO-8601 datetime the SOQL parser accepts
  private static Boolean looksLikeDateTime(String v) {
    if (String.isBlank(v))
      return false;
    // Accept YYYY-MM-DDThh:mm:ssZ or with offset (+/-HH:mm). Also allow milliseconds.
    // Examples: 2025-10-03T00:00:00Z, 2025-10-03T12:30:45+05:30, 2025-10-03T12:30:45.123Z
    String iso = '^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(?:\\.\\d{3})?(?:Z|[+-]\\d{2}:?\\d{2})$';
    return Pattern.matches(iso, v);
  }

  // Build count query
  private static String buildCountQuery(String baseQuery) {
    System.debug('baseQuery --- : ' + baseQuery);
    // Remove ORDER BY, LIMIT, and OFFSET for count queries
    String countQuery = baseQuery;
    Integer orderByIndex = countQuery.indexOf('ORDER BY');
    if (orderByIndex > -1) {
      countQuery = countQuery.substring(0, orderByIndex);
    }
    Integer limitIndex = countQuery.indexOf('LIMIT');
    if (limitIndex > -1) {
      countQuery = countQuery.substring(0, limitIndex);
    }
    Integer offsetIndex = countQuery.indexOf('OFFSET');
    if (offsetIndex > -1) {
      countQuery = countQuery.substring(0, offsetIndex);
    }
    // Replace SELECT ... FROM with SELECT COUNT() FROM
    Integer fromIndex = countQuery.indexOf('FROM');
    if (fromIndex > -1) {
      countQuery = 'SELECT COUNT() ' + countQuery.substring(fromIndex);
    }
    System.debug('countQuery: ' + countQuery);
    // Trim and return)
    return countQuery.trim();
  }

  @AuraEnabled(cacheable=true)
  public static Map<String, List<String>> getPicklistValues(
    String objectApiName
  ) {
    Map<String, List<String>> picklistMap = new Map<String, List<String>>();

    Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
    if (!globalDescribe.containsKey(objectApiName)) {
      throw new AuraHandledException('Object not found: ' + objectApiName);
    }
    Schema.DescribeSObjectResult objDescribe = globalDescribe.get(objectApiName)
      .getDescribe();

    for (Schema.SObjectField f : objDescribe.fields.getMap().values()) {
      Schema.DescribeFieldResult fd = f.getDescribe();
      Schema.DisplayType t = fd.getType();
      if (
        t == Schema.DisplayType.Picklist ||
        t == Schema.DisplayType.MultiPicklist
      ) {
        List<String> values = new List<String>();
        for (Schema.PicklistEntry pe : fd.getPicklistValues()) {
          values.add(pe.getValue());
        }
        picklistMap.put(fd.getName(), values);
      }
    }
    return picklistMap;
  }

  private class QueryParams {
    public String objectApiName;
    public List<String> fields;
    public String searchKeyword;
    public String field;
    public String operator;
    public String value;
    public String sortBy;
    public String sortDirection;
  }
}

    
    @AuraEnabled
    public static void updateAccounts(List<SObject> sObjList) {
        if (sObjList == null || sObjList.isEmpty()) {
            throw new AuraHandledException('No records provided for update.');
        }
        update as user sObjList;
    }
    
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getAccounts(Map<String, Object> params) {
        String objectApiName = (String) params.get('objectApiName');
        List<String> fields = new List<String>();
        if (params.containsKey('selectedFields') && params.get('selectedFields') != null) {
            for (Object f : (List<Object>)params.get('selectedFields')) {
                String fieldStr = (String)f;
                if (!fields.contains(fieldStr)) {fields.add(fieldStr);}
            }
        }
        if (!fields.contains('Id')) {fields.add('Id'); }// Always select Id
        String searchKeyword = (String) params.get('searchKeyword');
        String field = (String) params.get('field');
        String operator = (String) params.get('operator');
        String value = (String) params.get('value');
        Integer pageNumber = extractInteger(params, 'pageNumber', 1);
        Integer pageSize = extractInteger(params, 'pageSize', 10);
        String sortBy = (String) params.get('sortBy');
        String sortDirection = (String) params.get('sortDirection');
        
        Integer offsetSize = (pageNumber - 1) * pageSize;
        
        // Build query
        QueryParams qp = new QueryParams();
        qp.objectApiName = objectApiName;
        qp.fields = fields;
        qp.searchKeyword = searchKeyword;
        qp.field = field;
        qp.operator = operator;
        qp.value = value;
        qp.sortBy = sortBy;
        qp.sortDirection = sortDirection;
        String baseQuery = buildBaseQuery(qp);
        // Count query
        String countQuery = buildCountQuery(baseQuery);
        Integer totalCount = Database.countQuery(countQuery);
        
        // Pagination
        baseQuery += ' LIMIT ' + pageSize + ' OFFSET ' + offsetSize;
        List<SObject> sObjList = Database.query(baseQuery);
        
        return new Map<String, Object>{
            'records' => sObjList,
                'totalCount' => totalCount
                };
                    }
    
    //Extract integer safely
    private static Integer extractInteger(Map<String, Object> params, String key, Integer defaultValue) {
        return params.containsKey(key) && params.get(key) != null
            ? ((Decimal) params.get(key)).intValue()
            : defaultValue;
    }
    
    // Build base query with search + filters + sort
    private static String buildBaseQuery(QueryParams qp) {
        String selectClause = 'SELECT ' + String.join(qp.fields, ', ') + ' FROM ' + qp.objectApiName + ' WHERE Id != null';
        String query = selectClause;
        
        query += applyGlobalSearch(qp.searchKeyword, qp.fields);
        query += applyAdvancedFilter(qp.field, qp.operator, qp.value);
        
        if (String.isNotBlank(qp.sortBy) && String.isNotBlank(qp.sortDirection)) {
            query += ' ORDER BY ' + qp.sortBy + ' ' + qp.sortDirection;
        }
        return query;
    }
    
    // Global search logic (searches only on text fields in fields list)
    private static String applyGlobalSearch(String keyword, List<String> fields) {
        if (String.isBlank(keyword) || fields == null || fields.isEmpty()) {return '';}
        keyword = String.escapeSingleQuotes(keyword);
        
        // Only search on fields that are likely to be text (simple heuristic)
        List<String> searchFields = new List<String>();
        for (String f : fields) {
            if (f.toLowerCase().contains('name') || f.toLowerCase().contains('industry') || f.toLowerCase().contains('type') || f.toLowerCase().contains('phone')) {
                searchFields.add(f);
            }
        }
        if (searchFields.isEmpty()) {return '';}
        List<String> likeClauses = new List<String>();
        for (String f : searchFields) {
            likeClauses.add(f + ' LIKE \'%' + keyword + '%\'');
        }
        return ' AND (' + String.join(likeClauses, ' OR ') + ')';
    }
    
    // Advanced filter logic
    private static String applyAdvancedFilter(String field, String operator, String value) {
        if (String.isBlank(field) || String.isBlank(operator) || String.isBlank(value)) { return ''; }
        
        String op = operator.toLowerCase();
        
        // If value is ISO datetime, do NOT quote it
        Boolean isDt = looksLikeDateTime(value);
        String safe = isDt ? value : String.escapeSingleQuotes(value);
        
        if (op == 'equals' || op == 'eq') {
            // For datetime, equality isn’t precise; if needed, keep simple per request
            return ' AND ' + field + ' = ' + (isDt ? safe : '\'' + safe + '\'');
        } else if (op == 'contains') {
            // Contains only makes sense for text; keep original behavior
            return ' AND ' + field + ' LIKE \'%' + safe + '%\'';
        } else if (op == 'startswith' || op == 'startsWith') {
            return ' AND ' + field + ' LIKE \'' + safe + '%\'';
        }
        
        // Optional: support relational operators (>, >=, <, <=) if UI sends them
        if (op == '>' || op == 'gt')        return ' AND ' + field + ' > '  + (isDt ? safe : '\'' + safe + '\'');
        if (op == '>=' || op == 'gte')      return ' AND ' + field + ' >= ' + (isDt ? safe : '\'' + safe + '\'');
        if (op == '<' || op == 'lt')        return ' AND ' + field + ' < '  + (isDt ? safe : '\'' + safe + '\'');
        if (op == '<=' || op == 'lte')      return ' AND ' + field + ' <= ' + (isDt ? safe : '\'' + safe + '\'');
        
        return '';
    }
    
    // Returns true if value looks like an ISO-8601 datetime the SOQL parser accepts
    private static Boolean looksLikeDateTime(String v) {
        if (String.isBlank(v)) return false;
        // Accept YYYY-MM-DDThh:mm:ssZ or with offset (+/-HH:mm). Also allow milliseconds.
        // Examples: 2025-10-03T00:00:00Z, 2025-10-03T12:30:45+05:30, 2025-10-03T12:30:45.123Z
        String iso = '^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(?:\\.\\d{3})?(?:Z|[+-]\\d{2}:?\\d{2})$';
        return Pattern.matches(iso, v);
    }
    
    // Build count query
    private static String buildCountQuery(String baseQuery) {
        // Remove ORDER BY, LIMIT, and OFFSET for count queries
        String countQuery = baseQuery;
        Integer orderByIndex = countQuery.indexOf('ORDER BY');
        if (orderByIndex > -1) {
            countQuery = countQuery.substring(0, orderByIndex);
        }
        Integer limitIndex = countQuery.indexOf('LIMIT');
        if (limitIndex > -1) {
            countQuery = countQuery.substring(0, limitIndex);
        }
        Integer offsetIndex = countQuery.indexOf('OFFSET');
        if (offsetIndex > -1) {
            countQuery = countQuery.substring(0, offsetIndex);
        }
        // Replace SELECT ... FROM with SELECT COUNT() FROM
        Integer fromIndex = countQuery.indexOf('FROM');
        if (fromIndex > -1) {
            countQuery = 'SELECT COUNT() ' + countQuery.substring(fromIndex);
        }
        return countQuery.trim();
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getPicklistValues(String objectApiName){
        Map<String, List<String>> picklistMap = new Map<String, List<String>>();
        
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        if (!globalDescribe.containsKey(objectApiName)) {
            throw new AuraHandledException('Object not found: ' + objectApiName);
        }
        Schema.DescribeSObjectResult objDescribe = globalDescribe.get(objectApiName).getDescribe();
        
        for (Schema.SObjectField f : objDescribe.fields.getMap().values()) {
            Schema.DescribeFieldResult fd = f.getDescribe();
            Schema.DisplayType t = fd.getType();
            if (t == Schema.DisplayType.Picklist || t == Schema.DisplayType.MultiPicklist) {
                List<String> values = new List<String>();
                for (Schema.PicklistEntry pe : fd.getPicklistValues()) {
                    values.add(pe.getValue());
                }
                picklistMap.put(fd.getName(), values);
            }
        }
        return picklistMap;
    }
    
    private class QueryParams {
        public String objectApiName;
        public List<String> fields;
        public String searchKeyword;
        public String field;
        public String operator;
        public String value;
        public String sortBy;
        public String sortDirection;
    }
}