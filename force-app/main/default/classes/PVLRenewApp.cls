public class PVLRenewApp {
    public static Boolean runSync = false;
    public class QueueClass implements Queueable {
        public Set<String> appIds;
        public QueueClass (Set<String> appIds) {
            this.appIds = appIds;
        }
        public void execute(QueueableContext context) {
            System.attachFinalizer(new FinalizerClass(appIds));
            ApplicationService.calcualteOutStanding(appIds);
        }
    }

    public class FinalizerClass implements Finalizer {
        public Set<String> appIds;
        public FinalizerClass (Set<String> appIds) {
            this.appIds = appIds;
        }
        
        public void execute(FinalizerContext ctx) {
            String parentJobId = String.valueOf(ctx.getAsyncApexJobId());
            if (ctx.getResult() != ParentJobResult.SUCCESS) {
                for(String recordId: appIds) {
                    ApplicationLogService.logApplicationError('Online Renewal Application Error', 
                        recordId, '', String.valueOf(ctx.getException()) );
                }
            }
        }
    }

    public static void calculate(Set<String> appIds) {
        if(Limits.getLimitQueueableJobs() == Limits.getQueueableJobs() || runSync) {
            ApplicationService.calcualteOutStanding(appIds);
        } else {
            System.enqueueJob(new QueueClass(appIds));
        }
        
    }
}