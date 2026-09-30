/*
 * ___________________________________________________________________________________
 * Covered by
 * __________________________________________________________________________________
 * PacPoint-CL09082020 - Created for
 * __________________________________________________________________________________
 * Initial implementation
 *
 * @author chris.loyola@pacificpointcorp.com
 *
 * @created 9/8/2020
 * __________________________________________________________________________________
 */
public class RecwkstPdfController {
    public class TapeFeed{
        public String textarea{set;get;}
        public String textLabel{set;get;}
        public Decimal value{set;get;}
    }
    public static FiscalForm__c record;

    public static Map<String, Object> pdfData;

    public RecwkstPdfController(ApexPages.StandardController ctrl) {
        if(!Test.isRunningTest()) {
            ctrl.addFields(new List<String>{'Request__c'});
        }
        
        record = (FiscalForm__c)ctrl.getRecord();
        Object des = JSON.deserializeUntyped(record.Request__c);
        pdfData = (Map<String, Object>) des;
        
    }

    public String getCreatingUser() {
        Map<String, Object> usr = (Map<String, Object>) pdfData.get('runningUser');
        return usr.get('FirstName') + ' ' + usr.get('LastName');
    }
    public List<TapeFeed> getMoreTapes() {
        List<Object> dList = (List<Object>) pdfData.get('moreTapesCheck');
        List<TapeFeed> moreTapes = (List<TapeFeed>)JSON.deserialize(JSON.serialize(dList), List<TapeFeed>.class);
        return moreTapes;
    }
    public String getRunningName() {
        return String.valueOf(pdfData.get('runningName'));
    }
    public String getDepositNotesTextarea() {
        return String.valueOf(pdfData.get('depositNotesTextarea'));
    }
    public Date getBatchDate2() {
        String batchDate = (String)pdfData.get('batchDate2');

        return Date.valueOf(batchDate) ;
    }

    public Date getBatchDate() {
        String batchDate = (String)pdfData.get('batchDate');

        return Date.valueOf(batchDate) ;
    }
    public Decimal getCalculatedValue() {
        if(pdfData.get('calculatedValue') == null) {
            return 0;
        } else {
            return Decimal.valueOf(String.valueOf(pdfData.get('calculatedValue')));
        }
        
    }
    public Decimal getTerminal3TotalCash() {
        return Decimal.valueOf(String.valueOf(pdfData.get('terminal3TotalCash')));
    }
    
    public Decimal getTerminal13TotalCash() {
        return Decimal.valueOf(String.valueOf(pdfData.get('terminal13TotalCash')));
    }

    public Decimal getTerminal3TotalCheck() {
        return Decimal.valueOf(String.valueOf(pdfData.get('terminal3TotalCheck')));
    }

    public Decimal getTerminal13TotalCheck() {
        return Decimal.valueOf(String.valueOf(pdfData.get('terminal13TotalCheck')));
    }

    public Decimal getTerminal3TotalCoins() {
        return Decimal.valueOf(String.valueOf(pdfData.get('terminal3TotalCoins')));
    }

    public Decimal getTerminal13TotalCoins() {
        return Decimal.valueOf(String.valueOf(pdfData.get('terminal13TotalCoins')));
    }
    public String getTape1CheckTextarea() { 
        return String.valueOf(pdfData.get('tape1CheckTextarea'));
    }
    public String getTape2CheckTextarea() { 
        return String.valueOf(pdfData.get('tape2CheckTextarea'));
    }
    public String getTape3CheckTextarea() { 
        return String.valueOf(pdfData.get('tape3CheckTextarea'));
    }
    public String getTape4CheckTextarea() { 
        return String.valueOf(pdfData.get('tape4CheckTextarea'));
    }
    public String getTape5CheckTextarea() { 
        return String.valueOf(pdfData.get('tape5CheckTextarea'));
    }
    public String getTape6CheckTextarea() { 
        return String.valueOf(pdfData.get('tape6CheckTextarea'));
    }

    public Decimal getTape1Check() {
        return Decimal.valueOf(String.valueOf(pdfData.get('tape1Check')));
    }

    public Decimal getTape2Check() {
        return Decimal.valueOf(String.valueOf(pdfData.get('tape2Check')));
    }

    public Decimal getTape3Check() {
        return Decimal.valueOf(String.valueOf(pdfData.get('tape3Check')));
    }

    public Decimal getTape4Check() {
        return Decimal.valueOf(String.valueOf(pdfData.get('tape4Check')));
    }

    public Decimal getTape5Check() {
        return Decimal.valueOf(String.valueOf(pdfData.get('tape5Check')));
    }

    public Decimal getTape6Check() {
        return Decimal.valueOf(String.valueOf(pdfData.get('tape6Check')));
    }

    public Decimal getGov3TotalCheck() {
        return Decimal.valueOf(String.valueOf(pdfData.get('gov3TotalCheck')));
    }

    public Decimal getGov13TotalCheck() {
        return Decimal.valueOf(String.valueOf(pdfData.get('gov13TotalCheck')));
    }

    public Decimal getTotalCash() {
        return Decimal.valueOf(String.valueOf(pdfData.get('totalCash')));
    }

    public Decimal getTotalCoins() {
        return Decimal.valueOf(String.valueOf(pdfData.get('totalCoins')));
    }

    public Decimal getTotalDeposit() {
        return Decimal.valueOf(String.valueOf(pdfData.get('totalDeposit')));
    }

    public Decimal getTotalReceipt() {
        return Decimal.valueOf(String.valueOf(pdfData.get('totalReceipt')));
    }
}