/*
 * -----------------------------------------------------------------------------------
 * Description
 *
 * -----------------------------------------------------------------------------------
 * Covered by: WithoutSharingDmlHelperTest
 * -----------------------------------------------------------------------------------
 * PacPoint-CL11032022 - Created for
 * -----------------------------------------------------------------------------------
 * Initial implementation
 *
 * @author chris.loyola@pacificpointcorp.com
 *
 * @created 11/03/2022
 * -----------------------------------------------------------------------------------
 * Changes
 * -----------------------------------------------------------------------------------
 */
public without sharing class WithoutSharingDmlHelper {
    public static void doInsert(List<SObject> records) {
        insert records;
    }

    public static void doInsert(SObject record) {
        doInsert(new SObject[]{record});
    }

    public static void doUpdate(List<SObject> records) {
        update records;
    }
}