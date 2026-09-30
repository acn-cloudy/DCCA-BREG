/*
* ─────────────────────────────────────────────────────────
* Used for the 
* DocGeneratorDataSources records
* ─────────────────────────────────────────────────────────
* PacPoint-AZ291019 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp
* @created      2019-10-29
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
public with sharing class DocGeneratorFeed {
    public SObject record {set;get;}
    public List<SObject> records {set;get;}
    public String phaseObject{set;get;}
    public String query {set;get;}
    public String rowSpecs {set;get;}
    public String parentField {set;get;}
    public String parentSource {set;get;}
    public String defaultValue {set;get;}
    public List<String> fields {set;get;}
    public Map<String, String> valueMap {set;get;}
    public List<Map<String, String>> valueMaps {set;get;}
    public Map<String, List<Map<String, String>>> childrenValues {set;get;}

}