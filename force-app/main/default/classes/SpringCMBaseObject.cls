global virtual class SpringCMBaseObject {
	global String Name {get;set;}
	//global String CreatedDate {get;set;}
	//global String CreatedBy {get;set;}
	//global String UpdatedDate {get;set;}
	//global String UpdatedBy {get;set;}
	//global String Description {get;set;}
	global SpringCMFolder ParentFolder {get;set;}
	//global SpringCMEosInfo EosParentInfo {get;set;}
	//global AccessLevel": {
	//global String Path {get;set;}
	// global AttributeGroups": {
	//global SpringCMShareLinks ShareLinks {get;set;}
	//global Security": {
	global String Href {get;set;}

	global class SpringCMDocuments extends SpringCMApiCollection {
		global List<SpringCMDocument> Items {get;set;}
	}

	//global class SpringCMShareLinks extends SpringCMApiCollection {
	//	global List<SpringCMShareLink> Items {get;set;}
	//}
}