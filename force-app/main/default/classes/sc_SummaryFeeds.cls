public with sharing class sc_SummaryFeeds {
    
    @Auraenabled
    public String sectionLabel {set;get;}
    
    @Auraenabled
    public List<Feed> feeds {set;get;}
    
    public class Feed implements Comparable{
        // Implement the compareTo() method
        public Integer compareTo(Object compareTo) {
            Feed compareToEmp = (Feed)compareTo;
            if (sortOrder == compareToEmp.sortOrder) return 0;
            if (sortOrder > compareToEmp.sortOrder) return 1;
            return -1;        
        }
        
        public List<Row> generateRows(String value, List<String> cols){
            List<String> totalRows = value.split('!=!');
            totalRows.remove(0);
            String lastC = totalRows.get(totalRows.size() -1);
            Integer lastDigit = Integer.valueOf(lastC.split('#')[0]);
            List<Row> rows = new List<Row>();
            Integer colsToShow =cols.size(); 
            Integer count = 0;
            List<String> totalRows2 = new list<string>();
            
            if(colsToShow == 1){ 
                
                for(Integer i=0; i< totalRows.size(); i++ ){
                    totalRows2.add(totalRows[i]);
                    i++;
                }
                system.debug('totalRows2' + totalRows2);
            }
            
            for(Integer i = 0; i<= lastDigit; i ++ ){
                Row rowUnit = new Row();
                List<Column> columns = new List<Column>();
                
                for(Integer j = 0; j <  colsToShow ; j ++ ){
                    string rowId = '';
                    string rowVal = '';
                    if(colsToShow > 1){
                        rowId  = totalRows.get(count).split('#')[0];
                        rowVal = totalRows.get(count).split('#')[1];
                    }
                    else  if(colsToShow == 1){
                        rowId = totalRows2.get(count).split('#')[0];
                        rowVal = totalRows2.get(count).split('#')[1];
                    }
                    
                    system.debug('count '+count + 'rowId ' + rowId +'rowVal '+rowVal+'cols.get(j) '+cols.get(j));
                    if(rowId == i.format() ){
                        Column col = new Column(cols.get(j), rowVal);
                        columns.add(col);                        
                    }
                    count++; 
                }system.debug(columns);
                if(!columns.isEmpty()){
                    rowUnit.columns = columns;
                    rows.add(rowUnit);
                }
            }
            
            
            
            
            
            
            return rows;
            
        }
        
        public Feed(String label) {
            this.label = label;
        }
        public Feed(String label, String value){
            this.label = label;
            this.value = value;
        }
        
        public Feed(String label, String value, List<String> cols){
            this.label = label;
            this.value = value;
            this.cols = cols;
            this.rows = generateRows(value, cols);
        }
        @Auraenabled
        public String label {set; get;}
        @Auraenabled
        public String value {set; get;}
        @Auraenabled
        public Decimal sortOrder {set;get;}
        @Auraenabled
        public List<Row> rows {set;get;}
        @Auraenabled
        public List<String> cols {set;get;}
        
    }
    public class Column {
        
        public Column(String label, String value){
            this.label = label;
            this.value = value;
        }
        @Auraenabled
        public String label {set; get;}
        @Auraenabled
        public String value {set; get;}
    }
    public class Row {
        @Auraenabled
        public List<Column> columns {set;get;}
    }
    public class FieldInfo {
        public String label;
        public String apiName;
        public String type;
    }
    
    
}