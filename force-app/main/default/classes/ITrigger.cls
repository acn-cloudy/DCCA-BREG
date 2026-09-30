/*
* ─────────────────────────────────────────────────────────
* Interface containing methods Trigger Handlers must implement to enforce best
* practice and bulkification of triggers.
* ─────────────────────────────────────────────────────────
* PacPoint-AZ130619 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp 
* @created      2019-06-13
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
public interface ITrigger {
    /**
     * bulkBefore
     *
     * This method is called prior to execution of a BEFORE trigger. Use this to
     * cache any data required into maps prior execution of the trigger.
     */
    void bulkBefore();

    /**
     * bulkAfter
     *
     * This method is called prior to execution of an AFTER trigger. Use this to
     * cache any data required into maps prior execution of the trigger.
     */
    void bulkAfter();
    

    /**
     * beforeInsert
     *
     * This method is called iteratively for each record to be inserted during a
     * BEFORE trigger. Never execute any SOQL/SOSL etc in this and other
     * iterative methods.
     */
    void beforeInsert(SObject so);
    
    

    /**
     * beforeUpdate
     *
     * This method is called iteratively for each record to be updated during a
     * BEFORE trigger.
     */
    void beforeUpdate(SObject oldSo, SObject so);

    /**
     * beforeDelete
     *
     * This method is called iteratively for each record to be deleted during a
     * BEFORE trigger.
     */
    void beforeDelete(SObject so);
    
    /**
     * beforeUnDelete
     *
     * This method is called iteratively for each record to be undeleted during a
     * BEFORE trigger.
     */
    void beforeUnDelete(SObject so);

    /**
     * afterInsert
     *
     * This method is called iteratively for each record inserted during an
     * AFTER trigger. Always put field validation in the 'After' methods in case
     * another trigger has modified any values. The record is 'read only' by
     * this point.
     */
    void afterInsert(SObject so);

    /**
     * afterUpdate
     *
     * This method is called iteratively for each record updated during an AFTER
     * trigger.
     */
    void afterUpdate(SObject oldSo, SObject so);

    /**
     * afterDelete
     *
     * This method is called iteratively for each record deleted during an AFTER
     * trigger.
     */

    void afterDelete(SObject so);
    
     /**
     * afterUnDelete
     *
     * This method is called iteratively for each record undeleted during an AFTER
     * trigger.
     */
    void afterUnDelete(SObject so);

    /**
     * andFinally
     *
     * This method is called once all records have been processed by the
     * trigger. Use this method to accomplish any final operations such as
     * creation or updates of other records.
     */
    void andFinally();
}