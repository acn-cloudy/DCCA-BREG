/*
 * ___________________________________________________________________________________
 * Description Controller for PVL_DOOR_CERT VF page pdf
 * We could have used the Standard controller to get the data as previously implemented but somehow it doesn't
 * work when the page is viewed in public website. But it does work when using custom controller
 * Covered by: PVL_DoorCertControllerTest
 * __________________________________________________________________________________
 * PacPoint-CL03212021 - Created for DCCA CE Portal
 * __________________________________________________________________________________
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 3/21/2021
 * __________________________________________________________________________________
 *
 * @see case 00010804, 00012339 (as public page via CE Portal)
 */
public class PVL_DoorCertController {
    public String recordId;

    public PVL_DoorCertController() {
        recordId = System.currentPageReference()
                .getParameters()
                .get('id');
    }

    public PdfDataWrapper getCourse() {
        Course__c c = [
                SELECT Id,
                        Credits__c,
                        CourseId__c,
                        StartDate__c,
                        Account__r.Name,
                        SubjectDescription__c,
                        Address__c,
                        Address2__c,
                        City__c,
                        Island__c,
                        State__c,
                        ZipCode__c,
                        InstructorName__c,
                        Medium__c,
                        Subject__r.Name,
                        StartTime__c
                FROM Course__c
                WHERE Id = :recordId
        ];

        PdfDataWrapper wrapper = new PdfDataWrapper();
        wrapper.c = c;
        if (c.StartTime__c != null) {
            Datetime tempStartTime = Datetime.newInstance(Date.today(), c.StartTime__c);
            wrapper.startTimeDisplay = tempStartTime.format('hh:mm a');
        }

        return wrapper;
    }

    public Class PdfDataWrapper{
        public Course__c c{
            get;set;
        }

        public String startTimeDisplay{
            get;set;
        }
    }
}