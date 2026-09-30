import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAccessToken from "@salesforce/apex/SpringCMConnector.getToken"
import getURL from "@salesforce/apex/SpringCMConnector.getFolderURL"

export default class SpringFiles extends LightningElement {
    fileData;
    fileName;
    progress =0 ; 
    uploadInProgress = false;
    fileUrl;
    abortFileUpload = false;
    accessToken;
    @api hideloadresult;
    @api label;
    @api recordId;
    @api signedUrl;
    @api getFileInfo() {
      const {fileUrl, fileName} = this;
      return {url: fileUrl, name: fileName};
    }
    b64toBlob (b64Data, contentType='', sliceSize=512) {
      const byteCharacters = atob(b64Data);
      const byteArrays = [];
    
      for (let offset = 0; offset < byteCharacters.length; offset += sliceSize) {
        const slice = byteCharacters.slice(offset, offset + sliceSize);
    
        const byteNumbers = new Array(slice.length);
        for (let i = 0; i < slice.length; i++) {
          byteNumbers[i] = slice.charCodeAt(i);
        }
    
        const byteArray = new Uint8Array(byteNumbers);
        byteArrays.push(byteArray);
      }
    
      const blob = new Blob(byteArrays, {type: contentType});
      return blob;
    }
    openfileUpload(event) {
      const { label } = this;
      this.dispatchEvent(new CustomEvent("uploadstarted"), {detail:{label}});
        const file = event.target.files[0]
        var reader = new FileReader()
        reader.onload = () => {
            let base64 = reader.result.split(',')[1];
            
            this.fileData = {
                'fileName': file.name,
                'fileContent': this.b64toBlob(base64, file.type),
                'recordId': this.recordId
            }
            this.onFileUpload();
        }
        reader.readAsDataURL(file)
    }

    onFileUpload(){
        this.uploadInProgress = true;
        const {fileContent, fileName} = this.fileData
        this.generateSignedUrlAndUpload(fileContent, fileName);
    }
    async generateSignedUrlAndUpload(file, fileName) {
      const { recordId } = this;
      let signedURL = this.signedUrl || await getURL({recordId });
      await this.sendToSignedURL(file, fileName, signedURL);
    }

    async sendToSignedURL(file, fileName, url) {
        const signedURL = url.replace('{?name}', "?name="+ encodeURIComponent(fileName));
        this.accessToken = await getAccessToken();
        this.progress = 0;
        let xhReq = new XMLHttpRequest();
        xhReq.open("POST", signedURL, true);
        xhReq.setRequestHeader('Authorization',"bearer " + this.accessToken);
        xhReq.setRequestHeader('Content-Type' , 'multipart/form-data');
        xhReq.setRequestHeader('Accept', '*/*');
        
        // xhReq.setRequestHeader("Content-Disposition" ,'filename="' + this.fileNameOriginal + '"');
        xhReq.upload.onprogress = ('httpUploadProgress', progress => {
          this.progress = parseInt((progress.loaded/progress.total) *100, 10); 
          if(this.abortFileUpload){
            xhReq.abort();
            this.abortFileUpload = false;
            this.dispatchEvent(new CustomEvent("uploadterminated"));
          }
        });
        
        xhReq.onload =  (res) => {
          this.uploadInProgress = false;
          if (res.currentTarget.readyState === 4) {
            if (res.currentTarget.status >= 200 && res.currentTarget.status < 300) {
              this.fileName = this.fileData.fileName;
              this.dispatchEvent(new ShowToastEvent({
                title: "Success",
                variant: "success",
                message: `${fileName} uploaded successfully!!`
              }));
              const fileItem = JSON.parse(res.currentTarget.response);
              this.fileUrl = fileItem.Href;
              const { label } = this;
              const cEvent = new CustomEvent("uploadfinished", 
                {detail: {files: [{name: this.fileName , fileUrl: this.fileUrl}], label}});
              this.dispatchEvent(cEvent);
              this.progress = 0;
            } else {
              this.handleError("There is an error in uploading file. Please try again!");
            }
          }
        };
        xhReq.onerror = () => {
          // Handle network errors
          this.handleError("Network error occurred during file upload.");
        };
        xhReq.ontimeout = () => {
            // Handle request timeouts
            this.handleError("File upload timed out.");
        };
        xhReq.send(file);  
    }
    handleError(message) {
      this.dispatchEvent(new ShowToastEvent({
        title: "Error",
        variant: "error",
        message
      }));
    }
}