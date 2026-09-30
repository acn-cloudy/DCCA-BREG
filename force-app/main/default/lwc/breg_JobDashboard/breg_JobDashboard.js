import { LightningElement, track, wire } from "lwc";
import { getFocusedTabInfo, setTabLabel, setTabIcon } from "lightning/platformWorkspaceApi";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getBatchJobConfigurations from "@salesforce/apex/BREGBatchJobConfigurationController.getBatchJobConfigurations";
import runBatchJob from "@salesforce/apex/BREGBatchJobConfigurationController.runBatchJob";
import getJobInfo from "@salesforce/apex/BREGBatchJobConfigurationController.getJobInfo";
import getBatchJobResult from "@salesforce/apex/BREGBatchJobConfigurationController.getBatchJobResult";

export default class JobDashboard extends LightningElement {
    @track jobs = [];
    @track selectedJob = {};
    loading = false;
    showJobDetailsModal = false;
    showAlertModal = false;
    alertModalTitle = "";
    alertModalMessage = "";
    showConfirmModal = false;
    confirmModalMessage = "";
    pendingJobId = null;
    pendingIsCleanupJob = false;

    yearOptions = [
        { label: new Date().getFullYear().toString(), value: new Date().getFullYear().toString() },
        { label: (new Date().getFullYear() - 1).toString(), value: (new Date().getFullYear() - 1).toString() }
    ];

    quarterOptions = [
        { label: "Q1", value: "1" },
        { label: "Q2", value: "2" },
        { label: "Q3", value: "3" },
        { label: "Q4", value: "4" }
    ];

    async connectedCallback() {
        try {
            const tabInfo = await getFocusedTabInfo();
            if (tabInfo?.tabId) {
                await setTabLabel(tabInfo.tabId, "BREG Job Dashboard");
                await setTabIcon(tabInfo.tabId, "utility:apex");
            }
        } catch (e) {
            console.debug("Not in console app or Workspace API error", e);
        }
    }

    @wire(getBatchJobConfigurations)
    wiredConfigurations({ error, data }) {
        if (data) {
            this.initializeJobs(data);
        } else if (error) {
            this.showToast("Error", "Failed to load job configurations: " + error.body.message, "error");
        }
    }

    initializeJobs(configurations) {
        this.jobs = configurations.map((configuration) => {
            const currentStatus = configuration.currentStatus || "Ready";
            const jobId = configuration.currentJobId || null;
            const displayStatus = currentStatus === "Completed" ? "Ready" : currentStatus;
            const statusConfig = this.getStatusConfig(displayStatus);
            const referenceDate = new Date();

            const job = {
                id: configuration.id,
                name: configuration.jobName,
                className: configuration.jobClass,
                description: configuration.jobDescription || "",
                supportsPreviewMode: configuration.supportsPreviewMode || false,
                previewModeDisabled: !(configuration.supportsPreviewMode || false),
                supportsQuarterSelect: configuration.supportsQuarterSelect || false,
                supportsYearSelect: configuration.supportsYearSelect || false,
                previewMode: false,
                batchSize: configuration.batchSize || 200,
                status: displayStatus,
                statusVariant: statusConfig.variant,
                lastRun: configuration.lastRunDate || "",
                duration: configuration.lastDuration || "",
                batchesProcessed: configuration.lastBatchesProcessed || null,
                jobId: jobId,
                actionButtonLabel: statusConfig.buttonLabel,
                actionButtonVariant: statusConfig.buttonVariant,
                actionButtonDisabled: statusConfig.buttonDisabled,
                preProcessingReport: configuration.preProcessingReport || null,
                postProcessingReport: configuration.postProcessingReport || null,
                resultFolderUrl: configuration.resultFolderUrl || null,
                lastRunLogs: null,
                selectedQuarter: referenceDate.getMonth() < 3 ? "1" : referenceDate.getMonth() < 6 ? "2" : referenceDate.getMonth() < 9 ? "3" : "4",
                selectedYear: referenceDate.getFullYear().toString(),
                indsNoticeDate: referenceDate.toISOString().split("T")[0],
                indsDueDate: new Date(referenceDate.setMonth(referenceDate.getMonth() + 2)).toISOString().split("T")[0],
                isKillJob: configuration.jobClass === "BREGAccountStatus2DissolutionBatch",
                cleanupJobClassName: configuration.cleanupJobClassName || null
            };

            if (jobId && this.isInProgressStatus(currentStatus)) {
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => {
                    this.pollJobStatus(job.id);
                }, 1000);
            }

            return job;
        });
    }

    isInProgressStatus(status) {
        return status === "Processing" || status === "Preparing" || status === "Queued" || status === "Holding";
    }

    getStatusConfig(status) {
        if (this.isInProgressStatus(status)) {
            return {
                variant: "warning",
                buttonLabel: "Running...",
                buttonVariant: "neutral",
                buttonDisabled: true
            };
        }
        if (status === "Completed") {
            return {
                variant: "success",
                buttonLabel: "Start Job",
                buttonVariant: "brand",
                buttonDisabled: false
            };
        }
        if (status === "Failed" || status === "Aborted") {
            return {
                variant: "error",
                buttonLabel: "Start Job",
                buttonVariant: "brand",
                buttonDisabled: false
            };
        }
        return {
            variant: "success",
            buttonLabel: "Start Job",
            buttonVariant: "brand",
            buttonDisabled: false
        };
    }

    handleJobAction(event) {
        const jobId = event.target.dataset.jobId;
        const job = this.jobs.find((jobItem) => jobItem.id === jobId);

        if (!job) return;

        if (job.status === "Ready" || job.status === "Failed" || job.status === "Completed" || job.status === "Aborted") {
            this.showRunConfirm(job, false);
        }
    }

    handleCleanupJobAction(event) {
        const jobId = event.target.dataset.jobId;
        const job = this.jobs.find((jobItem) => jobItem.id === jobId);

        if (!job) return;

        if (job.status === "Ready" || job.status === "Failed" || job.status === "Completed" || job.status === "Aborted") {
            this.showRunConfirm(job, true);
        }
    }

    showRunConfirm(job, isCleanupJob) {
        this.pendingJobId = job.id;
        this.pendingIsCleanupJob = isCleanupJob;
        this.confirmModalMessage = isCleanupJob
            ? `Are you sure you want to run the cleanup job for ${job.name}?`
            : `Are you sure you want to run ${job.name}?`;
        this.showConfirmModal = true;
    }

    cancelConfirmModal() {
        this.showConfirmModal = false;
        this.confirmModalMessage = "";
        this.pendingJobId = null;
        this.pendingIsCleanupJob = false;
    }

    confirmRunJob() {
        if (!this.pendingJobId) {
            this.cancelConfirmModal();
            return;
        }
        const job = this.jobs.find((jobItem) => jobItem.id === this.pendingJobId);
        const isCleanupJob = this.pendingIsCleanupJob;
        this.cancelConfirmModal();
        if (job) {
            this.startJob(job, isCleanupJob);
        }
    }

    startJob(job, isCleanupJob = false) {
        this.loading = true;
        const payload = {
            jobClassName: isCleanupJob && job.cleanupJobClassName ? job.cleanupJobClassName : job.className,
            batchSize: job.batchSize || 200,
            previewMode: job.previewMode || false,
            selectedQuarter: job.selectedQuarter,
            selectedYear: job.selectedYear,
            indsNoticeDate: job.indsNoticeDate,
            indsDueDate: job.indsDueDate
        };
        if (job.isKillJob && (!job.indsNoticeDate || !job.indsDueDate)) {
            let inputs = this.template.querySelectorAll(`lightning-input[data-job-id="${job.id}"]`);
            inputs.forEach((input) => {
                if (input.dataset.fieldName === "indsNoticeDate" || input.dataset.fieldName === "indsDueDate") {
                    input.reportValidity();
                }
            });
            this.loading = false;
            this.showToast("Validation Error", "Notice Date and Due Date are required for this job", "error");

            return;
        }

        runBatchJob({
            requestJSON: JSON.stringify(payload)
        })
            .then((result) => {
                this.loading = false;
                if (result.status === "success") {
                    job.status = "Running";
                    job.jobId = result.jobId;
                    job.lastRun = result.currentDateTime;
                    this.updateJobStatus(job, "Running");
                    this.showAlert("Job Started", `${job.name} started successfully.`);
                    this.pollJobStatus(job.id);
                } else {
                    this.showToast("Error", result.message, "error");
                }
            })
            .catch((error) => {
                this.loading = false;
                this.showToast("Error", "Failed to start job: " + (error.body ? error.body.message : error.message), "error");
            });
    }

    updateJobStatus(job, status) {
        const displayStatus = status === "Completed" ? "Ready" : status;
        const statusConfig = this.getStatusConfig(displayStatus);
        job.status = displayStatus;
        job.statusVariant = statusConfig.variant;
        job.actionButtonLabel = statusConfig.buttonLabel;
        job.actionButtonVariant = statusConfig.buttonVariant;
        job.actionButtonDisabled = statusConfig.buttonDisabled;
    }

    pollJobStatus(jobConfigId, continuePolling = true) {
        const job = this.jobs.find((jobItem) => jobItem.id === jobConfigId);
        if (!job || !job.jobId) return;

        getJobInfo({ jobId: job.jobId })
            .then((jobInfo) => {
                if (jobInfo) {
                    job.batchesProcessed = jobInfo.JobItemsProcessed;

                    if (jobInfo.CreatedDateStr) {
                        job.lastRun = jobInfo.CreatedDateStr;
                    }

                    this.updateJobStatus(job, jobInfo.Status);

                    if (jobInfo.CompletedDate && jobInfo.CreatedDate) {
                        job.duration = this.calculateDuration(jobInfo.CreatedDate, jobInfo.CompletedDate);
                        job.lastRun = jobInfo.CompletedDateStr;
                    }

                    if (jobInfo.Status === "Completed") {
                        this.loadJobResults(jobConfigId);
                        this.showAlert("Job Completed", `${job.name} has completed successfully. Click OK to dismiss.`);
                    } else if (jobInfo.Status === "Failed" || jobInfo.Status === "Aborted") {
                        this.showAlert("Job Finished", `${job.name} finished with status: ${jobInfo.Status}. Click OK to dismiss.`);
                    } else if (this.isInProgressStatus(jobInfo.Status) && continuePolling) {
                        // eslint-disable-next-line @lwc/lwc/no-async-operation
                        setTimeout(() => {
                            this.pollJobStatus(jobConfigId, true);
                        }, 5000);
                    }
                }
            })
            .catch((error) => {
                console.error("Error polling job status:", error);
            });
    }

    loadJobResults(jobConfigId) {
        const job = this.jobs.find((jobItem) => jobItem.id === jobConfigId);
        if (!job || !job.jobId) return;

        getBatchJobResult({ jobId: job.jobId })
            .then((results) => {
                if (results && results.length > 0) {
                    const result = results[0];
                    job.lastRunLogs = result.breg_Results__c || null;
                    job.totalCount = result.breg_Total_Count__c || null;
                }
            })
            .catch((error) => {
                console.error("Error loading job results:", error);
            });
    }

    calculateDuration(startDate, endDate) {
        if (!startDate || !endDate) return "";

        const start = new Date(startDate);
        const end = new Date(endDate);
        const diffMs = end - start;

        const hours = Math.floor(diffMs / (1000 * 60 * 60));
        const minutes = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));
        const seconds = Math.floor((diffMs % (1000 * 60)) / 1000);

        if (hours > 0) {
            return `${hours}h ${minutes}m ${seconds}s`;
        }
        if (minutes > 0) {
            return `${minutes}m ${seconds}s`;
        }
        return `${seconds}s`;
    }

    handlePreviewModeChange(event) {
        const jobId = event.target.dataset.jobId;
        const isChecked = event.target.checked;
        const job = this.jobs.find((jobItem) => jobItem.id === jobId);

        if (job) {
            job.previewMode = isChecked;
            const mode = isChecked ? "enabled" : "disabled";
            this.showToast("Info", `Preview mode ${mode} for ${job.name}`, "info");
        }
    }

    handleReferenceChange(event) {
        const jobId = event.target.dataset.jobId;
        const selectedReference = event.target.value;
        const job = this.jobs.find((jobItem) => jobItem.id === jobId);
        const referenceName = event.target.name;
        console.debug("Reference change detected:", { jobId, selectedReference, referenceName });
        if (job) {
            job[referenceName] = selectedReference;
        }
    }

    handleRefreshStatus(event) {
        const jobId = event.target.dataset.jobId;
        const job = this.jobs.find((jobItem) => jobItem.id === jobId);

        if (job && job.jobId) {
            // Force refresh without continuing polling
            this.pollJobStatus(job.id, false);
            this.showToast("Info", `Refreshing status for ${job.name}`, "info");
        } else {
            this.showToast("Info", `No active job to refresh for ${job.name}`, "info");
        }
    }

    handleViewPreProcessingReport(event) {
        const jobId = event.target.dataset.jobId;
        const job = this.jobs.find((jobItem) => jobItem.id === jobId);

        if (job && job.preProcessingReport) {
            window.open(
                job.preProcessingReport + (job.supportsQuarterSelect ? "?fv0=" + job.selectedQuarter + "&fv1=" + job.selectedQuarter : ""),
                "_blank"
            );
        }
    }

    handleOpenResultsFolder(event) {
        const jobId = event.target.dataset.jobId;
        const job = this.jobs.find((jobItem) => jobItem.id === jobId);
        if (job && job.resultFolderUrl) {
            console.debug("Opening results folder URL:", job.resultFolderUrl);
            window.open(job.resultFolderUrl, "_blank");
        }
    }

    handleViewPostProcessingReport(event) {
        const jobId = event.target.dataset.jobId;
        const job = this.jobs.find((jobItem) => jobItem.id === jobId);

        if (job && job.postProcessingReport) {
            window.open(
                job.postProcessingReport + (job.supportsQuarterSelect ? "?fv0=" + job.selectedQuarter + "&fv1=" + job.selectedQuarter : ""),
                "_blank"
            );
        }
    }

    handleViewDetails(event) {
        const jobId = event.target.dataset.jobId;
        const job = this.jobs.find((jobItem) => jobItem.id === jobId);
        if (job) {
            this.selectedJob = { ...job };
            if (job.className) {
                this.loadJobResultsForModal(job.className);
            }
            this.showJobDetailsModal = true;
        }
    }

    loadJobResultsForModal(jobClassName) {
        getBatchJobResult({ jobClassName: jobClassName })
            .then((results) => {
                if (results && results.length > 0) {
                    const result = results[0];
                    this.selectedJob.formattedTimestamp = result.formattedTimestamp || null;
                    let userName = "";
                    if (result.breg_User__r) {
                        const firstName = result.breg_User__r.FirstName || "";
                        const lastName = result.breg_User__r.LastName || "";
                        userName = (firstName + " " + lastName).trim();
                    }
                    this.selectedJob.user = userName || null;
                    this.selectedJob.jobName = result.breg_Job_Name__c || null;
                    this.selectedJob.totalCount = result.breg_Total_Count__c || null;
                    this.selectedJob.runId = result.breg_Run_Id__c || null;
                    this.selectedJob.lastRunLogs = result.breg_Results__c || null;
                    this.selectedJob.formattedResults = this.formatJobResults(result.breg_Results__c);
                }
            })
            .catch((error) => {
                console.error("Error loading job results for modal:", error);
            });
    }

    formatJobResults(jsonString) {
        if (!jsonString) {
            return null;
        }

        try {
            const jsonData = JSON.parse(jsonString);
            return this.formatJsonObject(jsonData);
        } catch (error) {
            console.error("Error parsing JSON:", error);
            return jsonString; // Return original string if parsing fails
        }
    }

    formatJsonObject(obj, indent = 0) {
        if (obj === null || obj === undefined) {
            return "";
        }

        if (typeof obj !== "object") {
            return String(obj);
        }

        if (Array.isArray(obj)) {
            if (obj.length === 0) {
                return "[]";
            }
            return obj
                .map((item, index) => {
                    const formatted = this.formatJsonObject(item, indent + 1);
                    return `${"  ".repeat(indent)}[${index}]: ${formatted}`;
                })
                .join("\n");
        }

        const entries = Object.entries(obj);
        if (entries.length === 0) {
            return "{}";
        }

        const filteredEntries = entries.filter(([key]) => key.toLowerCase() !== "logs");

        return filteredEntries
            .map(([key, value]) => {
                const formattedKey = this.formatKey(key);
                if (typeof value === "object" && value !== null && !Array.isArray(value)) {
                    const nested = this.formatJsonObject(value, indent + 1);
                    return `${"  ".repeat(indent)}${formattedKey}:\n${nested}`;
                }
                const formattedValue = this.formatValue(value, key);
                return `${"  ".repeat(indent)}${formattedKey}: ${formattedValue}`;
            })
            .join("\n");
    }

    formatKey(key) {
        // Convert camelCase to Title Case
        return key
            .replace(/([A-Z])/g, " $1")
            .replace(/^./, (str) => str.toUpperCase())
            .trim();
    }

    formatValue(value, key = "") {
        if (value === null || value === undefined) {
            return "N/A";
        }
        if (typeof value === "boolean") {
            return value ? "Yes" : "No";
        }
        if (typeof value === "number") {
            const keyLower = key.toLowerCase();
            if (keyLower.includes("year") || keyLower.includes("quarter") || keyLower.includes("month") || keyLower.includes("day")) {
                return String(value);
            }
            return value.toLocaleString();
        }
        if (typeof value === "string") {
            return value;
        }
        if (Array.isArray(value)) {
            return `[${value.length} items]`;
        }
        if (typeof value === "object") {
            return "{...}";
        }
        return String(value);
    }

    closeJobDetailsModal() {
        this.showJobDetailsModal = false;
        this.selectedJob = {};
    }

    showAlert(title, message) {
        this.alertModalTitle = title;
        this.alertModalMessage = message;
        this.showAlertModal = true;
    }

    closeAlertModal() {
        this.showAlertModal = false;
        this.alertModalTitle = "";
        this.alertModalMessage = "";
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(evt);
    }

    get hasJobs() {
        return this.jobs && this.jobs.length > 0;
    }

    get runningJobsCount() {
        return this.jobs.filter(
            (jobItem) => jobItem.status === "Running" || jobItem.status === "Processing" || jobItem.status === "Preparing" || jobItem.status === "Queued"
        ).length;
    }

    get failedJobsCount() {
        return this.jobs.filter((jobItem) => jobItem.status === "Failed" || jobItem.status === "Aborted").length;
    }
}