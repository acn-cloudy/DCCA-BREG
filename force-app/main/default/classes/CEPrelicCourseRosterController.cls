/*
 * ___________________________________________________________________________________
 * Description Controller for CEPrelicCourseRoster VF Page
 * Covered by: CEPrelicCourseRosterControllerTest
 * __________________________________________________________________________________
 * PacPoint-CL03242021 - Created for Phase #
 * __________________________________________________________________________________
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 3/24/2021
 * __________________________________________________________________________________
 */
public class CEPrelicCourseRosterController {
    public String courseId;

    public CEPrelicCourseRosterController() {
        courseId = System.currentPageReference()
                .getParameters()
                .get('q');
    }

    public Course__c getCourse() {
        Course__c result = new Course__c();

        List<Course__c> c = [
                SELECT
                        Id,
                        Account__r.Name,
                        Account__r.ProviderSchoolID__c,
                        Subject__r.Name,
                        Medium__c,
                        CourseId__c,
                        Instructor__r.Name
                FROM Course__c
                WHERE Id =:courseId
        ];

        if (!c.isEmpty()) {
            result = c[0];
        }

        return result;
    }
}