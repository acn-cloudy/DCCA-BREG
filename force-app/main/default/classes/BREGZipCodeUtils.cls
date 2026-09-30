public with sharing class BREGZipCodeUtils {
    public class StateEntry {
        public Integer id;
        public String name;
        public String stateCode;
        public String countryCode;

        public StateEntry(Integer id, String name, String stateCode, String countryCode) {
            this.id = id;
            this.name = name;
            this.stateCode = stateCode;
            this.countryCode = countryCode;
        }
    }

    @TestVisible
    private static final List<StateEntry> STATE_DATA = new List<StateEntry>{
        new StateEntry(976, 'Armed Forces - Pacific', 'AP', 'US'),
        new StateEntry(977, 'Armed Forces - Americas', 'AA', 'US'),
        new StateEntry(978, 'Armed Forces - Europe/Africa/Canada', 'AE', 'US'),
        new StateEntry(975, 'United States', 'US', 'US'),
        new StateEntry(814, 'Alabama', 'AL', 'US'),
        new StateEntry(815, 'Alaska', 'AK', 'US'),
        new StateEntry(816, 'Arizona', 'AZ', 'US'),
        new StateEntry(817, 'Arkansas', 'AR', 'US'),
        new StateEntry(818, 'California', 'CA', 'US'),
        new StateEntry(819, 'Colorado', 'CO', 'US'),
        new StateEntry(820, 'Connecticut', 'CT', 'US'),
        new StateEntry(821, 'Delaware', 'DE', 'US'),
        new StateEntry(822, 'District of Columbia', 'DC', 'US'),
        new StateEntry(823, 'Florida', 'FL', 'US'),
        new StateEntry(824, 'Georgia', 'GA', 'US'),
        new StateEntry(825, 'Hawaii', 'HI', 'US'),
        new StateEntry(826, 'Idaho', 'ID', 'US'),
        new StateEntry(827, 'Illinois', 'IL', 'US'),
        new StateEntry(828, 'Indiana', 'IN', 'US'),
        new StateEntry(829, 'Iowa', 'IA', 'US'),
        new StateEntry(830, 'Kansas', 'KS', 'US'),
        new StateEntry(831, 'Kentucky', 'KY', 'US'),
        new StateEntry(832, 'Louisiana', 'LA', 'US'),
        new StateEntry(833, 'Maine', 'ME', 'US'),
        new StateEntry(834, 'Maryland', 'MD', 'US'),
        new StateEntry(835, 'Massachusetts', 'MA', 'US'),
        new StateEntry(836, 'Michigan', 'MI', 'US'),
        new StateEntry(837, 'Minnesota', 'MN', 'US'),
        new StateEntry(838, 'Mississippi', 'MS', 'US'),
        new StateEntry(839, 'Missouri', 'MO', 'US'),
        new StateEntry(840, 'Montana', 'MT', 'US'),
        new StateEntry(841, 'Nebraska', 'NE', 'US'),
        new StateEntry(842, 'Nevada', 'NV', 'US'),
        new StateEntry(843, 'New Hampshire', 'NH', 'US'),
        new StateEntry(844, 'New Jersey', 'NJ', 'US'),
        new StateEntry(845, 'New Mexico', 'NM', 'US'),
        new StateEntry(846, 'New York', 'NY', 'US'),
        new StateEntry(847, 'North Carolina', 'NC', 'US'),
        new StateEntry(848, 'North Dakota', 'ND', 'US'),
        new StateEntry(849, 'Ohio', 'OH', 'US'),
        new StateEntry(850, 'Oklahoma', 'OK', 'US'),
        new StateEntry(851, 'Oregon', 'OR', 'US'),
        new StateEntry(852, 'Pennsylvania', 'PA', 'US'),
        new StateEntry(853, 'Puerto Rico', 'PR', 'US'),
        new StateEntry(854, 'Rhode Island', 'RI', 'US'),
        new StateEntry(855, 'South Carolina', 'SC', 'US'),
        new StateEntry(856, 'South Dakota', 'SD', 'US'),
        new StateEntry(857, 'Tennessee', 'TN', 'US'),
        new StateEntry(858, 'Texas', 'TX', 'US'),
        new StateEntry(859, 'Utah', 'UT', 'US'),
        new StateEntry(860, 'Vermont', 'VT', 'US'),
        new StateEntry(861, 'Virginia', 'VA', 'US'),
        new StateEntry(862, 'Washington', 'WA', 'US'),
        new StateEntry(863, 'West Virginia', 'WV', 'US'),
        new StateEntry(864, 'Wisconsin', 'WI', 'US'),
        new StateEntry(865, 'Wyoming', 'WY', 'US'),
        new StateEntry(866, 'Guam', 'GU', 'US'),
        new StateEntry(867, 'Federated States of Micronesia', 'FM', 'US'),
        new StateEntry(869, 'Northern Mariana Islands', 'MP', 'US'),
        new StateEntry(870, 'Palau', 'PW', 'US'),
        new StateEntry(872, 'Virgin Island', 'VI', 'US'),
        new StateEntry(873, 'Alberta', 'AB', 'CA'),
        new StateEntry(874, 'British Columbia', 'BC', 'CA'),
        new StateEntry(875, 'Manitoba', 'MB', 'CA'),
        new StateEntry(876, 'New Brunswick', 'NB', 'CA'),
        new StateEntry(877, 'Newfoundland', 'NF', 'CA'),
        new StateEntry(878, 'Northwest Territories', 'NT', 'CA'),
        new StateEntry(879, 'Nova Scotia', 'NS', 'CA'),
        new StateEntry(880, 'Nunavut', 'NU', 'CA'),
        new StateEntry(881, 'Ontario', 'ON', 'CA'),
        new StateEntry(882, 'Prince Edward Island', 'PE', 'CA'),
        new StateEntry(883, 'Quebec', 'QC', 'CA'),
        new StateEntry(884, 'Saskatchewan', 'SK', 'CA'),
        new StateEntry(885, 'Yukon', 'YT', 'CA'),
        new StateEntry(918, 'Australian Capital Territory', 'ACT', 'AU'),
        new StateEntry(919, 'New South Wales', 'NSW', 'AU'),
        new StateEntry(920, 'Northern Territory', 'NT', 'AU'),
        new StateEntry(921, 'Queensland', 'QLD', 'AU'),
        new StateEntry(922, 'South Australia', 'SA', 'AU'),
        new StateEntry(923, 'Tasmania', 'TAS', 'AU'),
        new StateEntry(924, 'Victoria', 'VIC', 'AU'),
        new StateEntry(925, 'Western Australia', 'WA', 'AU'),
        new StateEntry(973, 'Trust Territory of the Pacific Islands', 'TT', 'US'),
        new StateEntry(-2, 'Error', 'ERORR', 'CA'),
        new StateEntry(-1, 'NO LOCALITY', 'NL', 'CA')
    };

    // Lazily built lookup: id (as String) -> stateCode
    private static Map<String, String> idToStateCode;
    // Lazily built lookup: stateCode -> countryCode
    private static Map<String, String> stateToCountry;

    private static void buildLookups() {
        if (idToStateCode != null) {
            return;
        }
        idToStateCode = new Map<String, String>();
        stateToCountry = new Map<String, String>();
        for (StateEntry e : STATE_DATA) {
            idToStateCode.put(String.valueOf(e.id), e.stateCode);
            stateToCountry.put(e.stateCode, e.countryCode);
        }
    }

    // Returns state code for a given numeric id (e.g. 825 -> 'HI')
    public static String getStateCodeById(Integer id) {
        if (id == null) {
            return null;
        }
        buildLookups();
        return idToStateCode.get(String.valueOf(id));
    }

    // Returns country code for a given state code (e.g. 'HI' -> 'US')
    public static String getCountryByStateCode(String stateCode) {
        if (String.isBlank(stateCode)) {
            return null;
        }
        buildLookups();
        return stateToCountry.get(stateCode);
    }

    private static Boolean between(Integer value, Integer min, Integer max) {
        return value >= min && value <= max;
    }
}