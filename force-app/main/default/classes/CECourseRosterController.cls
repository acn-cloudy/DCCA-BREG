/*
 * ___________________________________________________________________________________
 * Description Controller for CECourseRoster VF Page
 * Covered by: CECourseRosterControllerTest
 * __________________________________________________________________________________
 * PacPoint-CL03242021 - Created for DCCA Portal
 * __________________________________________________________________________________
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 3/24/2021
 * __________________________________________________________________________________
 */
public class CECourseRosterController {
    public String courseId;

    public CECourseRosterController() {
        courseId = System.currentPageReference()
                .getParameters()
                .get('q');
    }

    public Data getCourse() {
        Data result = new Data();

        List<Course__c> c = [
                SELECT
                        Id,
                        Account__r.Name,
                        Account__r.ProviderSchoolID__c,
                        Subject__r.Name,
                        Medium__c,
                        CourseId__c,
                        StartDate__c,
                        StartTime__c,
                        Address__c,
                        Address2__c,
                        City__c,
                        Island__c,
                        State__c,
                        ZipCode__c,
                        InstructorName__c,
                        (SELECT
                                 Id,
                                 Account__r.Name,
                                 EnrolleeName__c,
                                 License__r.LicenseType__r.LicensePrefix__c,
                                 License__r.LicenseNumberFormula__c,
                                 MakeUpCredit__c
                        FROM PrelicenseCEEnrollment__r order by EnrolleeName__c)
                FROM Course__c
                WHERE Id =:courseId
        ];

        if (!c.isEmpty()) {
            result.course = c[0];
            if (result.course.StartTime__c != null) {
                Datetime tmpStartTime = Datetime.newInstance(Date.today(), result.course.StartTime__c);
                result.displayTime = tmpStartTime.format('hh:mm a');
            }

            String loc = String.isNotEmpty(result.course.Address__c) ? result.course.Address__c + ' ' : '';
            loc += String.isNotEmpty(result.course.Address2__c) ? result.course.Address2__c + ' ' : '';
            loc += String.isNotEmpty(result.course.City__c) ? result.course.City__c + ' ' : '';
            loc += String.isNotEmpty(result.course.Island__c) ? result.course.Island__c + ' ' : '';
            loc += String.isNotEmpty(result.course.State__c) ? result.course.State__c + ' ' : '';
            loc += String.isNotEmpty(result.course.ZipCode__c) ? result.course.ZipCode__c : '';
            result.displayLocation = loc;
        }

        return result;
    }

    public class Data{
        public Course__c course{
            get;set;
        }

        public String displayTime{
            get;set;
        }

        public String displayLocation{
            get;set;
        }
    }
}