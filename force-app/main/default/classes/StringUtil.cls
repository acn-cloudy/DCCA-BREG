public class StringUtil {
    
    public static String shortenedTo(Integer numChars, String str) {
        return str.substring(0, Math.min(str.length(), numChars));
    }

    public static String generateRandomString(Integer length) {
        String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyz';
        String str = '';
        while (str.length() < length) {
            Integer index = Math.mod(Math.abs(Crypto.getRandomInteger()), chars.length());
            str += chars.substring(index, index + 1);
        }
        return str;
    }

    public static String getSoqlStringList(Set<String> items) {
        return getSoqlStringList(new List<String>(items));
    }

    public static String getSoqlStringList(String[] items) {
        return '(\'' + String.join(items, '\',\'') + '\')';
    }

}