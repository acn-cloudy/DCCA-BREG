@IsTest
private class DocuSignJWTTest {
    private static final String RSA_PRIVATE_KEY =
        'MIIEpAIBAAKCAQEAxCg+YPlTDjljhg7YQs4n6jMAth0raDV6rnQ0z5MC+Fhr/k0W2pKZcqZ7Rp260f36CgbG2lzMZacBhZeY2JWQUjfXG5UuRi4w259uGTVP+iS/n7LRABeFneYp663TOH2NE7ELmK2ycks12AOW5WIayJbADzKEiwgU1ulYXioZ5jXiUdE92mciu1HwOV/EUM6EPraaCG9Ufv+cL/VcEp6qW+IB3J31mYF+jfDo4+wMkwJLu+qgRcV+Zfas0GFuqlJoBYu7gAce/2+TtC1jKpOTM9vKk4uNqiwB5BsMIi1PIpLR2hWnpF6gr9y1lG0ChGUTXpbM9wvl22Znst/QslFjewIDAQABAoIBAAz7PNNL0VIp80Hj8sCCNC115zK4dJyo5D2Sx8LLz96B4BqZ+JXJ5MAZprW9qoLdc//YJ4nyzs+CPMHU16nP/BdijzruXHvmOYWGLT+t1Bv/hypicNS4uclKeiKZBA4Mbr9m3c6+AlAU59fitzZUtFNY5qhj9TGVIZ43Z65Kgde0i3ySxO8syVKYZ5baXwRWTKeC5m4/XtCI4fptTZIGKV/wPpGdh0bX4tLqk+LFU7wSCQEcS5UIjIWalJyEKJTIw0Z9gNMGxUryDC1ocGHjXuUEQQ5g6MCfEPJiTpPI9lrZMjnLZ1IadtGVF8uAaiD4FSvOWd5JXOj1eMYbruDoKwECgYEA7W97uoWubtVZ/TVgagmVCeioTCAGxR/M6cNtUFm3wduJqVIejyKPj+lpxNaFPszmvPK941pR6+GRvE1bswzn5nbUqwvcUVyfHt68U1GLutgVNF9beMPP8eqTH/QLa4xgtgo1jNeM0dkAsvIhQ4ImI1g4mADEKVYprYOiDoW5ljECgYEA036Ia/GGfDcVxXVYQISzlZVKIBqortABGj9gpqTIJkT0ZRz5pcBSBxlh1xr00mnSrJ5dKkHBU3x8wYwmsDn455jJp8virDX6MlplqDspZIL8IGc0ULYjcNM5wBu+ZfV4xirQDS+bP4YVrB5nnGOXSAeCXcUMUgDhbEM3H4ipLWsCgYA24jc6hV4t1nlns2fm+vINiU8l0Z1fAZvPSVJCaYq1b/bhQc84jOecf3roeiHww1JuyLmmDSG0ob6bRVJ2D/ym5D8CjspNsFhDvX7Qz5+5/+re4U/2mWS+6dc6YqIlKRzN14xLUyQE+eFUe+2+eh4wu1rRoBO37mfR6QST0Mt2cQKBgQC2k4Uxqk9u7B7fV23YRLbDax2SmXEFeIt7HTtSoO4oG17f6yOY823cswzDpYG0I6a7XfsPf7RlXhJVA6hiealmRX/QWzJTeEWFMoSPtoMFQg5l6rI++v2daLtyHIFBg6e/azYwK+jZ7ebHr3fCijcO92yThogcQqZXz67GijOCAQKBgQDD8avFNgz6Q9Tfec1ucybjQRtdhAGBOTCJjAyC69ZGwdkMOX7bw8ZcYS3anYE7FeAlCoFxQX9lLQsP87kdLRD4x/CVNHXk3p2AzmeNu4Dn7x0ppYPU/qObhc0h4f5QvNygteP2/t5L29m4fWZWs/jwi1o67ZKXwgnkp5O8CgN2dQ==';

    @IsTest
    static void testIssueWithHs256IncludesClaims() {
        String encodedSecret = EncodingUtil.base64Encode(Blob.valueOf('unit-test-secret'));
        DocuSignJWT jwt = new DocuSignJWT(DocuSignJWT.HS256, 'subject-id', 'issuer-id', encodedSecret, 'signature impersonation', 'account-d.docusign.com');
        jwt.claims = new Map<String, String>{ 'customClaim' => 'customValue' };

        String token = jwt.issue();
        List<String> parts = token.split('\\.');

        System.assertEquals(3, parts.size(), 'JWT should have header, body, and signature');

        Map<String, Object> header = decodeJsonSegment(parts[0]);
        Map<String, Object> body = decodeJsonSegment(parts[1]);

        System.assertEquals(DocuSignJWT.HS256, (String) header.get('alg'), 'Header should contain HS256 algorithm');
        System.assertEquals('JWT', (String) header.get('typ'), 'Header should contain JWT type');
        System.assertEquals('issuer-id', (String) body.get('iss'), 'Body should contain issuer');
        System.assertEquals('subject-id', (String) body.get('sub'), 'Body should contain subject');
        System.assertEquals('account-d.docusign.com', (String) body.get('aud'), 'Body should contain audience');
        System.assertEquals('signature impersonation', (String) body.get('scope'), 'Body should contain scope');
        System.assertEquals('customValue', (String) body.get('customClaim'), 'Custom claims should be included');
        System.assertNotEquals(null, body.get('iat'), 'Issued-at should be present');
        System.assertNotEquals(null, body.get('exp'), 'Expiry should be present');
        System.assertNotEquals('', parts[2], 'Signature should be generated for HS256');
    }

    @IsTest
    static void testIssueWithNoneAlgorithmHasEmptySignature() {
        DocuSignJWT jwt = new DocuSignJWT(DocuSignJWT.NONE, 'subject-id', 'issuer-id', null, 'signature', 'account-d.docusign.com');

        String token = jwt.issue();
        List<String> parts = token.split('\\.');

        System.assertEquals(2, parts.size(), 'Apex split drops the trailing empty signature segment');
        System.assert(token.endsWith('.'), 'Unsigned JWT should end with a trailing period for the empty signature');

        Map<String, Object> header = decodeJsonSegment(parts[0]);
        System.assertEquals(DocuSignJWT.NONE, (String) header.get('alg'), 'Header should contain none algorithm');
    }

    @IsTest
    static void testIssueWithRs256UsesProvidedPrivateKey() {
        DocuSignJWT jwt = new DocuSignJWT(DocuSignJWT.RS256, 'subject-id', 'issuer-id', RSA_PRIVATE_KEY, 'signature', 'account-d.docusign.com');

        String token = jwt.issue();
        List<String> parts = token.split('\\.');

        System.assertEquals(3, parts.size(), 'JWT should have header, body, and signature');

        Map<String, Object> header = decodeJsonSegment(parts[0]);
        System.assertEquals(DocuSignJWT.RS256, (String) header.get('alg'), 'Header should contain RS256 algorithm');
        System.assertNotEquals('', parts[2], 'Signature should be generated for RS256');
    }

    private static Map<String, Object> decodeJsonSegment(String base64UrlSegment) {
        String base64Segment = base64UrlSegment.replace('-', '+').replace('_', '/');
        while (Math.mod(base64Segment.length(), 4) != 0) {
            base64Segment += '=';
        }
        return (Map<String, Object>) JSON.deserializeUntyped(EncodingUtil.base64Decode(base64Segment).toString());
    }
}