public inherited sharing class BREGBusinessDetailsPdfController {
    public String pdfHtml { get; set; }

    public BREGBusinessDetailsPdfController() {
        String entityIdParam = ApexPages.currentPage().getParameters().get('entityId');
        if (String.isBlank(entityIdParam)) {
            this.pdfHtml = '';
            return;
        }

        this.pdfHtml = BREGBusinessDetailsPdfHtmlBuilder.build(Id.valueOf(entityIdParam));
    }
}