/*
 * ___________________________________________________________________________________
 * Description Test for CE_FutureCoursesController
 * __________________________________________________________________________________
 * PacPoint-CL03272021 - Created for DCCA CE Portal
 * __________________________________________________________________________________
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 3/27/2021
 * __________________________________________________________________________________
 */
@IsTest
private class CE_FutureCoursesControllerTest {
    @TestSetup
    static void setup() {
        Subject__c ceSubject = new Subject__c();
        ceSubject.Name = 'test';
        ceSubject.Medium__c = 'Classroom';
        ceSubject.Type__c = 'Core';
        ceSubject.CreditsForCESubjects__c = 1;

        Subject__c preLicSubject = new Subject__c();
        preLicSubject.Name = 'test';
        preLicSubject.Medium__c = 'Classroom';
        preLicSubject.Type__c = 'Prelicense';
        preLicSubject.CreditsForCESubjects__c = 1;

        Subject__c internetLicSubject = new Subject__c();
        internetLicSubject.Name = 'Internet';
        internetLicSubject.Medium__c = 'Internet';
        internetLicSubject.Type__c = 'Prelicense';
        internetLicSubject.CreditsForCESubjects__c = 1;

        insert new List<Subject__c>{ceSubject, preLicSubject, internetLicSubject};

        Course__c ceCourse = new Course__c();
        ceCourse.StartTime__c = Time.newInstance(1, 0, 0, 0);
        ceCourse.Island__c = 'Hawaii';
        ceCourse.Subject__c = ceSubject.Id;
        ceCourse.StartDate__c = Date.today().addDays(1);
        Course__c ceCourse2 = new Course__c();
        ceCourse2.StartTime__c = Time.newInstance(1, 0, 0, 0);
        ceCourse2.Island__c = 'Oahu';
        ceCourse2.Subject__c = ceSubject.Id;
        ceCourse2.StartDate__c = Date.today().addDays(1);

        Course__c preLicCourse = new Course__c();
        preLicCourse.StartTime__c = Time.newInstance(1, 0, 0, 0);
        preLicCourse.Island__c = 'Oahu';
        preLicCourse.Subject__c = preLicSubject.Id;
        preLicCourse.StartDate__c = Date.today().addDays(1);

        Course__c oLicCourse = new Course__c();
        oLicCourse.StartTime__c = Time.newInstance(1, 0, 0, 0);
        oLicCourse.Island__c = '';
        oLicCourse.Subject__c = internetLicSubject.Id;
        oLicCourse.StartDate__c = Date.today().addDays(1);

        insert new List<Course__c>{ceCourse, preLicCourse, oLicCourse, ceCourse2};
    }

    @IsTest
    static void testGetResultsCe() {
        PageReference p = Page.CE_FUTURE_COURSES;
        Test.setCurrentPage(p);
        ApexPages.currentPage().getParameters().put('t', 'c');
        CE_FutureCoursesController ct = new CE_FutureCoursesController();
        ct.getResults();
    }

    @IsTest
    static void testGetResultsPrelic() {
        PageReference p = Page.CE_FUTURE_COURSES;
        Test.setCurrentPage(p);
        ApexPages.currentPage().getParameters().put('t', 'p');
        CE_FutureCoursesController ct = new CE_FutureCoursesController();
        ct.getResults();
        ct.getCoursesSchools();
    }
}