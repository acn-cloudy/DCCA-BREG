@RestResource(urlMapping='/Encoding')
global class PVL_EncodingService {
    @HttpGet
    global static String signItem() {
        RestRequest req = RestContext.request;
        String body = req.params.get('data');
        Org_Credential__mdt record = [Select Id, Password__c, Key__c from Org_Credential__mdt Where Label = 'Digital Form'];
        OrgConfiguration__c configuration = OrgConfiguration__c.getOrgDefaults();
        String digitalForm = configuration.DigitalFormURL__c;
        Blob exampleIv = Blob.valueOf(record.Password__c);
        Blob key = EncodingUtil.base64Decode(record.Key__c );
        Blob data = Blob.valueOf(body);
        Blob encrypted = Crypto.encrypt('AES128', key, exampleIv, data);
        String str = digitalForm + '?data=' + EncodingUtil.base64encode(encrypted);

        return str;
    }

    public static String decode(String str) {
        Org_Credential__mdt record = [Select Id, Password__c, Key__c from Org_Credential__mdt Where Label = 'Digital Form'];
        Blob iv = Blob.valueOf(record.Password__c);
        Blob key = EncodingUtil.base64Decode(record.Key__c );
        Blob b = EncodingUtil.base64decode(str);
        Blob decrypted = Crypto.decrypt('AES128', key, iv, b);
        String decryptedString = decrypted.toString();
        return decryptedString;
    }
    
}