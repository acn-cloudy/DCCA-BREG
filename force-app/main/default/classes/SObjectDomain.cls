/*
 * A trim down version of sf domain model
 */
public virtual with sharing class SObjectDomain {
	/*
	 * Provides access to the data represented by this domain class
	 */
	public List<SObject> records { get; private set; }

	public Map<Id, SObject> recordMap { get; private set; }

	/*
	 * Derived from the records provided during construction, provides the native describe for the standard or custom object
	 */
	public Schema.DescribeSObjectResult sObjectDescribe { get; private set; }

	/*
	 * Constructs the domain class with the data on which to apply the behaviour implemented within
	 */
	public SObjectDomain(List<SObject> sObjectList) {
		// Ensure the domain class has its own copy of the data
		records = sObjectList.clone();

		try {
			// Capture SObjectType describe for this domain class
			for (Sobject record : records) {
				if (record.Id != null)
					sObjectDescribe = record.getSObjectType().getDescribe();
				break;
			}
			//contentDocumentLink doesn't have Id field
			if (sobjectDescribe != ContentDocumentLink.getSObjectType().getDescribe()) {
				recordMap = new Map<Id, SObject>(records);
			}
		} catch (Exception ex) {
		}
	}

	public virtual List<String> getIds() {
		return (List<String>) getFieldValues('Id');
	}

	public virtual List<Object> getFieldValues(String fieldName) {
		List<Object> values = new List<String>();
		for (SObject record : records) {
			values.add(record.get(fieldName));
		}
		return values;
	}

	public List<SObject> filterRecords(Set<String> ids) {
		List<SObject> filteredRecords = new List<SObject>();
		for (SObject record : records) {
			if (ids.contains(record.Id)) {
				filteredRecords.add(record);
			}
		}
		return filteredRecords;
	}

	public Map<String, List<Map<String, String>>> convertValueMapList(
		String phaseObject,
		List<String> fields,
		String parentField
	) {
		Map<String, List<Map<String, String>>> childrenValues = new Map<String, List<Map<String, String>>>();
		for (Sobject record : records) {
			String parentId = record.get(parentField) + '';
			List<Map<String, String>> values = new List<Map<String, String>>();
			if (childrenValues.containsKey(parentId)) {
				values = childrenValues.get(parentId);
			}
			Map<String, String> valueMap = new Map<String, String>();
			for (String field : fields) {
				String strValue = '';
				Object o;
				o = record.get(field);
				if (o instanceof Date) {
					Date dValue = Date.valueOf(o);
					String year = dValue.year() + '';
					String month = dValue.month() + '';
					String day = dValue.day() + '';
					if (day.length() == 1) {
						day = '0' + day;
					}
					if (month.length() == 1) {
						month = '0' + month;
					}
					if (year.length() == 4) {
						year = year.substring(2);
					}
					strValue = month + '/' + day + '/' + year;
				} else if (o instanceof String) {
					String str = String.valueof(o).escapeJava();

					strValue = str.replace('\\n', '<br>').unescapeJava();
				} else {
					strValue = o + '';
				}

				String fieldApiName = '{!' + phaseObject + '.' + field + '}';
				valueMap.put(fieldApiName, strValue);
			}
			values.add(valueMap);
			childrenValues.put(parentId, values);
		}
		return childrenValues;
	}

	public List<Map<String, String>> convertValueMapList(String phaseObject, List<String> fields) {
		List<Map<String, String>> values = new List<Map<String, String>>();
		for (Sobject record : records) {
			Map<String, String> valueMap = new Map<String, String>();
			for (String field : fields) {
				String strValue = '';
				Object o;
				o = record.get(field);
				if (o instanceof Date) {
					Date dValue = Date.valueOf(o);
					String year = dValue.year() + '';
					String month = dValue.month() + '';
					String day = dValue.day() + '';
					if (day.length() == 1) {
						day = '0' + day;
					}
					if (month.length() == 1) {
						month = '0' + month;
					}
					if (year.length() == 4) {
						year = year.substring(2);
					}
					strValue = month + '/' + day + '/' + year;
				} else if (o instanceof String) {
					String str = String.valueof(o).escapeJava();

					strValue = str.replace('\\n', '<br>').unescapeJava();
				} else {
					strValue = o + '';
				}

				String fieldApiName = '{!' + phaseObject + '.' + field + '}';
				valueMap.put(fieldApiName, strValue);
			}
			values.add(valueMap);
		}
		return values;
	}
}