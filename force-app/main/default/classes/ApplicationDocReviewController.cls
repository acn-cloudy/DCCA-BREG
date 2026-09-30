public class ApplicationDocReviewController {
    @InvocableMethod(label='Generate PDF' category='Application')
    public static List<Result> generatePDF(Input[] inputs) {
        List<Result> results = new List<Result>();
        for(Input i: inputs) {
            PageReference ref = PVL_PDFGenerator.generateURL(i.recordId, i.templateName);
            Result re = new Result();
            re.url = ref.getUrl();
            results.add(re);
        }
        return results;   
    }

    public class Input {
        @InvocableVariable(label='Record Id' required=true)
        public Id recordId;
        @InvocableVariable(label='Template Name')
        public String templateName;
    }
    public class Result {
        @InvocableVariable(label='URL' description='Output file url' required=true)
        public String url;
    }
}