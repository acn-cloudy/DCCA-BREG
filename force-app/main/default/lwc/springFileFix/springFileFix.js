import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAccessToken from "@salesforce/apex/SpringCMConnector.getAccessToken"
import updateFileAndDes from "@salesforce/apex/CLMFileFixController.updateExternalFileURL"
import getAllFiles from "@salesforce/apex/CLMFileFixController.getFiles"

export default class SpringFileFix extends LightningElement {
    description;
    progress;
    folderLink;
    documentLink;
    docName;
    accesstoken;
    recordId;
    fileData;
    uploadInProgress;
    endpoint;
    fileMap = {
        '.aac': 'audio/aac',
        '.abw': 'application/x-abiword',
        '.arc': 'application/x-freearc',
        '.avi': 'video/x-msvideo',
        '.azw': 'application/vnd.amazon.ebook',
        '.bin': 'application/octet-stream',
        '.bmp': 'image/bmp',
        '.bz': 'application/x-bzip',
        '.bz2': 'application/x-bzip2',
        '.csh': 'application/x-csh',
        '.css': 'text/css',
        '.csv': 'text/csv',
        '.doc': 'application/msword',
        '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        '.eot': 'application/vnd.ms-fontobject',
        '.epub': 'application/epub+zip',
        '.gif': 'image/gif',
        '.htm': 'text/html',
        '.html': 'text/html',
        '.ico': 'image/vnd.microsoft.icon',
        '.ics': 'text/calendar',
        '.jar': 'application/java-archive',
        '.jpeg': 'image/jpeg',
        '.jpg': 'image/jpeg',
        '.js': 'text/javascript',
        '.json': 'application/json',
        '.jsonld': 'application/ld+json',
        '.mid': 'audio/midi audio/x-midi',
        '.midi': 'audio/midi audio/x-midi',
        '.mjs': 'text/javascript',
        '.mp3': 'audio/mpeg',
        '.mpeg': 'video/mpeg',
        '.mpkg': 'application/vnd.apple.installer+xml',
        '.odp': 'application/vnd.oasis.opendocument.presentation',
        '.ods': 'application/vnd.oasis.opendocument.spreadsheet',
        '.odt': 'application/vnd.oasis.opendocument.text',
        '.oga': 'audio/ogg',
        '.ogv': 'video/ogg',
        '.ogx': 'application/ogg',
        '.otf': 'font/otf',
        '.png': 'image/png',
        '.pdf': 'application/pdf',
        '.ppt': 'application/vnd.ms-powerpoint',
        '.pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        '.rar': 'application/x-rar-compressed',
        '.rtf': 'application/rtf',
        '.sh': 'application/x-sh',
        '.svg': 'image/svg+xml',
        '.swf': 'application/x-shockwave-flash',
        '.tar': 'application/x-tar',
        '.tif': 'image/tiff',
        '.tiff': 'image/tiff',
        '.ttf': 'font/ttf',
        '.txt': 'text/plain',
        '.vsd': 'application/vnd.visio',
        '.wav': 'audio/wav',
        '.weba': 'audio/webm',
        '.webm': 'video/webm',
        '.webp': 'image/webp',
        '.woff': 'font/woff',
        '.woff2': 'font/woff2',
        '.xhtml': 'application/xhtml+xml',
        '.xls': 'application/vnd.ms-excel',
        '.xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        '.xml': 'application/xml if not readable from casual users (RFC 3023, section 3)',
        '.xul': 'application/vnd.mozilla.xul+xml',
        '.zip': 'application/zip',
        '.3gp': 'video/3gpp',
        '.3g2': 'video/3gpp2',
        '.7z': 'application/x-7z-compressed'
        };
        
    connectedCallback(){
        this.getToken();
    }
    async getFileStarted() {
      const fileStr = await getAllFiles();
      const file = JSON.parse(fileStr);
      this.endpoint = file.FileURL__c;
      this.recordId = file.Id;
      this.downloadFile();

    }
    async getToken() {
        this.accesstoken = await getAccessToken();
    }
    async downloadFile() {
        const endpoint = this.endpoint;
        const {accesstoken } = this;
        const xhr = new XMLHttpRequest();
        xhr.open('GET', endpoint);
        xhr.setRequestHeader('Authorization',"bearer " + accesstoken);
        xhr.onload = () => {
        if (xhr.status === 200) {
            const data = JSON.parse(xhr.responseText);
            this.folderLink = data.ParentFolder.Href;
            this.documentLink = data.DownloadDocumentHref;
            this.docName = data.Name;
            this.description = data.Description;
            this.downloadFileContent(this.documentLink);
        } else {
            console.error(xhr.statusText);
        }
        };
        xhr.onerror = () => console.error(xhr.statusText);
        xhr.send();
    }
    downloadFileContent(endpoint) {
        const {accesstoken } = this;
        const xhr = new XMLHttpRequest();
        xhr.open('GET', endpoint);
        xhr.setRequestHeader('Authorization',"bearer " + accesstoken);
        xhr.onload = () => {
        if (xhr.status === 200) {
            const fileData = xhr.responseText;
            console.log("docName", this.docName);
            console.log("folderLink", this.folderLink);
            console.log("fileData", fileData);
            this.openfileUpload(fileData, this.docName);
        } else {
            console.error(xhr.statusText);
        }
        };
        xhr.onerror = () => console.error(xhr.statusText);
        xhr.send();
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
      openfileUpload(base64, fileName) {
        this.uploadInProgress = true;
        this.progress = 0;
        const fileExtension = fileName.substring(fileName.lastIndexOf(".")).toLowerCase();
        const fileType = this.fileMap[fileExtension];
        try{
          this.fileData = {
            'fileName': fileName,
            'fileContent': this.b64toBlob(base64, fileType)
          }
          this.sendToS3UsingSignedURL(this.fileData.fileContent, fileName);
        } catch(ex){
          updateFileAndDes({fileUrl: 'error', des: 'error', recordId: this.recordId}).then(res=> {
            console.log("res", res);
            this.getFileStarted();
          });
        }
        
        
      }    
  
      async sendToS3UsingSignedURL(file, fileName) {
          const { accesstoken } = this;
          const { folderLink } = this;
          const signedURL = folderLink.replace("https://api", "https://apiupload") +"/documents?name="+ fileName;
          let xhReq = new XMLHttpRequest();
          xhReq.open("POST", signedURL, true);
          xhReq.setRequestHeader('Authorization',"bearer " + accesstoken);
          xhReq.setRequestHeader('Content-Type' , 'multipart/form-data');
          xhReq.setRequestHeader('Accept', '*/*');
          
          // xhReq.setRequestHeader("Content-Disposition" ,'filename="' + this.fileNameOriginal + '"');
          xhReq.upload.onprogress = ('httpUploadProgress', progress => {
            this.progress = parseInt((progress.loaded/progress.total) *100, 10); 
            if(this.abortFileUpload){
              xhReq.abort();
              this.abortFileUpload = false;
              this.openModel = false;
            }
          });
          
          xhReq.onload =  (res) => {
            this.uploadInProgress = false;
            if (res.currentTarget.readyState === 4) {
              if (res.currentTarget.status === 201) {
                this.fileName = this.fileData.fileName;
                let message = `${fileName} uploaded successfully!!`
                const event = new ShowToastEvent({
                  title: "Success",
                  variant: "success",
                  message
                });
                this.dispatchEvent(event);
                const fileItem = JSON.parse(res.currentTarget.response);
                this.fileUrl = fileItem.Href;
                updateFileAndDes({fileUrl: this.fileUrl, des: this.description, recordId: this.recordId}).then(res=> {
                  console.log("res", res);
                  this.getFileStarted();
                });
              }
            }
          };
          xhReq.send(file);       
      }
    uploadFile() {

    }

}