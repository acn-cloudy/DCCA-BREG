/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Controller for the Application Record Create component
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
*  PacPoint-AZ200919 - Created for PVL phase 1
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
public with sharing class PVLSettingsSelector {
    // Used to query PVL Settings
    public static List<PVLSettings__mdt> getSettingsByName(String name) {
        return [Select Id, ApplicationWizardPageLayoutDefault__c,
             MasterLabel, WizardApplicationType__c, Division__c 
             from PVLSettings__mdt where MasterLabel =: name];
    }
    
}