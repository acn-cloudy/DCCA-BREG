public class ManagedContentController {
    static Id getNetworkId() {
        String networkId = Network.getNetworkId();
        if(Test.isRunningTest()) {
            List<Network> networks = [SELECT Id FROM Network WHERE NAME = 'dcca' LIMIT 1];
            if(!networks.isEmpty()) networkId = networks.get(0).Id;
        }
        return networkId;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getContent(
        String contentId,
        Integer page,
        Integer pageSize,
        String language,
        String filterby
    ) {
        try {
            String networkId = getNetworkId();
            ConnectApi.ManagedContentVersionCollection contentCollection = ConnectApi.ManagedContent.getManagedContentByContentKeys(
                networkId,
                new List<String>{ contentId },
                0,
                1,
                language,
                filterby,
                false
            );
            Map<String, Object> result = new Map<String, Object>();
            result.putAll(contentCollection.items[0].contentNodes);
            result.put('$meta', new Map<String, Object> {
                'publishedDate' => contentCollection.items[0].publishedDate
            });
            return result;
        } catch (ConnectApi.ConnectApiException e) {
            System.debug('Error Message : ' + e);
            Map<String, ConnectApi.ManagedContentNodeValue> mcnvMap = new Map<String, ConnectApi.ManagedContentNodeValue>();
            return mcnvMap;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<ConnectApi.ManagedContentVersion> getContentList(
        Integer page,
        Integer pageSize,
        String language,
        String filterby
    ) {
        try {
            String networkId = getNetworkId();
            ConnectApi.ManagedContentVersionCollection contentCollection = ConnectApi.ManagedContent.getAllManagedContent(
                networkId,
                page,
                pageSize,
                language,
                filterby
            );
            return contentCollection.items;
        } catch (ConnectApi.ConnectApiException e) {
            System.debug('Error Message : ' + e);
            List<ConnectApi.ManagedContentVersion> mcnvMap = new List<ConnectApi.ManagedContentVersion>();
            return mcnvMap;
        }
    }

    @AuraEnabled(cacheable=true)
    public static ConnectApi.ManagedContentVersionCollection getContentCollection(
        Integer page,
        Integer pageSize,
        String language,
        String topic,
        String filterby
    ) {
        try {
            String networkId = getNetworkId();
            ConnectApi.ManagedContentVersionCollection contentCollection;
            System.debug('topics: ' + topic);
            if(String.isBlank(topic)) {
                contentCollection = ConnectApi.ManagedContent.getAllManagedContent(
                    networkId,
                    page,
                    pageSize,
                    language,
                    filterby
                );
            }else {
                contentCollection = ConnectApi.ManagedContent.getManagedContentByTopics(
                    networkId,
                    new List<String> {topic},
                    page,
                    pageSize,
                    language,
                    filterby
                );
            }
            return contentCollection;
        } catch (ConnectApi.ConnectApiException e) {
            System.debug('Error Message : ' + e);
            ConnectApi.ManagedContentVersionCollection mcnvMap = new ConnectApi.ManagedContentVersionCollection();
            return mcnvMap;
        }
    }
}