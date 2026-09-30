/*
 * ___________________________________________________________________________________
 * Controller for CE_FUTURE_COURSES VF Page
 * Covered by: CE_FutureCoursesControllerTest
 * __________________________________________________________________________________
 * PacPoint-CL03212021 - Created for Phase DCCA CE Portal
 * __________________________________________________________________________________
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 3/21/2021
 * __________________________________________________________________________________
 */
public class CE_FutureCoursesController {
    public static final String COURSE_TYPE_PRELIC = 'p';

    public String courseTypeFilter{
        get;set;
    }

    public CE_FutureCoursesController() {
        courseTypeFilter = System.currentPageReference()
                .getParameters()
                .get('t');
    }
    public List<Account> getCoursesSchools() {
        //init as CE filter
        String area = 'Continuing Education';

        if (courseTypeFilter == COURSE_TYPE_PRELIC) {
            area = 'Prelicense';
        }
        List<ProviderSchoolSubjects__c> schoolSubjects = [Select Id, Name, ProviderSchool__c,
            ProviderSchool__r.AdministratorEmail__c,
            ProviderSchool__r.AdministratorStreet1__c,
            ProviderSchool__r.AdministratorCity__c,
            ProviderSchool__r.AdministratorState__c,
            ProviderSchool__r.AdministratorZipcode__c,
            ProviderSchool__r.AdministratorPhone__c,
            ProviderSchool__r.Website,
            ProviderSchool__r.Name 
            FROM ProviderSchoolSubjects__c 
            WHERE Area__c =: area
            AND ExpirationDate__c > today 
            AND Subject__c NOT IN (
            	SELECT Subject__c     
            	FROM LicenseType_Required_CE__c 
            	WHERE LicenseType__r.Name IN (
                    'EJ', 'EJI', 'EJS', 'EM', 'ES', 'ESI', 'ESS', 'PJ', 'PM'
                )
        	)];
        
        Set<String> schoolIds = new Set<String>();
        for(ProviderSchoolSubjects__c subject: schoolSubjects) {
            schoolIds.add(subject.ProviderSchool__c);
        }
        List<Account> accounts = [Select Id,AdministratorEmail__c, AdministratorStreet1__c, 
            AdministratorCity__c, AdministratorState__c, AdministratorZipcode__c, AdministratorPhone__c, 
            Website, Name  from Account where 
            Id in: schoolIds order by Name];
        for(Account acc: accounts) {
            if(acc.AdministratorPhone__c != null) {
                if(acc.AdministratorPhone__c.length() == 10 && !acc.AdministratorPhone__c.contains('-')) {
                    acc.AdministratorPhone__c = acc.AdministratorPhone__c.substring(0, 3) 
                        + '-' + acc.AdministratorPhone__c.substring(3, 6) 
                        + '-' + acc.AdministratorPhone__c.substring(6);
                }
            }
        }
        return accounts;

    }

    public List<IslandCoursesWrapper> getResults() {
        //init as CE filter
        Set<String> typeFilter = new Set<String>{'Core', 'Elective'};

        if (courseTypeFilter == COURSE_TYPE_PRELIC) {
            typeFilter = new Set<String>{'Prelicense'};
        }

        List<Course__c> courses = [
    		SELECT
        		Id,
        		Island__c,
        		StartDate__c,
        		EndDate__c,
        		StartTime__c,
        		Name,
        		Credits__c,
        		Medium__c,
        		Address__c,
        		Address2__c,
        		City__c,
        		State__c,
        		ZipCode__c,
        		Account__r.Name,
        		Account__r.Phone,
        		Account__r.AdministratorStreet1__c,
        		Account__r.AdministratorCity__c,
        		Account__r.AdministratorState__c,
        		Account__r.AdministratorZipcode__c,
        		Account__r.AdministratorPhone__c,
        		Provider_School_Subject__r.Subject__r.Name
    		FROM Course__c
    		WHERE Subject__c NOT IN (
            	SELECT Subject__c     
            	FROM LicenseType_Required_CE__c 
            	WHERE LicenseType__r.Name IN (
                    'EJ', 'EJI', 'EJS', 'EM', 'ES', 'ESI', 'ESS', 'PJ', 'PM'
                )
        	)
    		AND 
        		Subject__r.Type__c IN :typeFilter
    		AND 
        	(
            	(Medium__c = 'Classroom' and StartDate__c > TODAY) 
            	OR 
            	((Medium__c = 'Internet' or Medium__c = Null) and EndDate__c > TODAY)
        	)
		];

        Map<String, IslandCoursesWrapper> tempResults = new Map<String, IslandCoursesWrapper>();

        for (Course__c c : courses) {

            if(c.Medium__c == 'Internet') {
                c.Island__c = 'Other';
            }
            if (!tempResults.containsKey(c.Island__c)) {
                IslandCoursesWrapper wrapper = new IslandCoursesWrapper();
                wrapper.island = c.Island__c;
                tempResults.put(c.Island__c, wrapper);
            }

            CourseWrapper cWrap = new CourseWrapper();
            cWrap.course = c;
            if (c.StartTime__c != null) {
                Datetime tmpStartTime = Datetime.newInstance(Date.today(), c.StartTime__c);
                cWrap.formattedStartTime = tmpStartTime.format('hh:mm a');
            }

            tempResults.get(c.Island__c).courses.add(cWrap);
        }
        List<IslandCoursesWrapper> records = tempResults.values();
        records.sort();
        return records;
    }

    public class IslandCoursesWrapper implements Comparable {
        public String island{
            get;set;
        }

        public List<CourseWrapper> courses{
            get;set;
        }

        public IslandCoursesWrapper() {
            courses = new List<CourseWrapper>();
        }
        // Compare opportunities based on the opportunity amount.
        public Integer compareTo(Object compareTo) {
            // Cast argument to OpportunityWrapper
            IslandCoursesWrapper compareRecord = (IslandCoursesWrapper)compareTo;

            // The return value of 0 indicates that both elements are equal.
            Integer returnValue = 0;
            if (island > compareRecord.island) {
                // Set return value to a positive value.
                returnValue = 1;
            } else {
                returnValue = -1;
            }

            return returnValue;       
        }
    }

    public class CourseWrapper{
        public Course__c course{
            get;set;
        }

        public String formattedStartTime{
            get;set;
        }
    }
}