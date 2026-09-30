({
    doInit: function(component, event) {

       var rows = component.get("v.rows");
         
       var cols = component.get("v.columns");
       var types = component.get("v.fieldtypes");
       var colheaders = cols.split(",");
       var intypes = types.split(",");
       var fieldopts=[];
       
         for (var i=0;i<intypes.length;i++)
         {
             
             
             if (intypes[i].indexOf("picklist")!=-1)
             {
                 var opts = intypes[i].split(";");
                 intypes[i]="picklist";
                
                var keep = [];
                for (var x=0;x<opts.length;x++)
                {
                    if (x==0)
                    {
                        keep.push('-None-');
                       
                       if (opts[x].indexOf(":")!=-1)
                       {
                           keep.push(opts[x].split(":")[1]);
                       }
                       else
                           keep.push(opts[x]);
                    }
                    else
                    {
                        keep.push(opts[x]);
                    }
                }
                
                 fieldopts.push(keep);
                
             }
             else
             {
                 fieldopts.push([]);
             }
         }
         
       //rows.push(intypes);
       component.set("v.rows",rows);
        
      
        
       component.set("v.columnheadings",colheaders);
       component.set("v.inputfieldtypes",intypes);
       component.set("v.fieldopts",fieldopts);
       
/*        if (rows!=null)
        {
          
            
           component.set("v.controlid", rows.length);
        } */
   },
   
   
    editrow: function(component, event) {
 
    
        
      var rows = component.get("v.rows");
       
     
       
   //  var inputCmp = event.source;
 //    var theindex = inputCmp.get("v.title");
    
 var theindex = event.source.elements[0].title;
  
   

   if (theindex!=null && theindex!='')
   {
        
        component.set("v.indextoedit",theindex);
     //   component.set("v.currentrow", theindex);
       
       var fcn = '';
       //need to load the control name
                  
       
        var therow = rows[parseInt(theindex)];
       fcn=therow[therow.length-1];
        component.set("v.filecontrolname", fcn); 
       
       
        
        component.set("v.rowtoedit",therow);
        component.set("v.editmode",false);
        
        
        
        component.set("v.modalHidden",false);
   }
   },
   
    addrowdialog: function(component, event) {
     
        var rows = component.get("v.rows");
 //       var maxx = component.get("v.controlid");
 //      maxx++;
        var timeInMs = Date.now();
          component.set("v.controlid", timeInMs+'');
 
        
          
        
     component.set("v.editmode",true);   
     component.set("v.editmode",false);
    component.set("v.modalHidden",false);
   },
   
   saverow: function(component, event) {
    
         var types = component.get("v.inputfieldtypes");
       var rows = component.get("v.rows");
        
       var theindex = component.get("v.indextoedit");
    
           
        var valstoadd = component.find("inputtablecontrol");
        var sval=[];
        
        for (var i=0;i<valstoadd.length;i++)
        {
             var vall = '';  
        
            vall =  valstoadd[i].get("v.value");
            if (vall==null)
               vall='';
            
            
           // valstoadd[i].set("v.value",'');
            
            if (types[i]=='fileupload')
            {
               
                var fupl = valstoadd[i];
                
                 vall = fupl.get('v.fieldName');
 
            }
            
            sval.push(vall);
        }
        
               
       
        rows[parseInt(theindex)]=sval;

       
     component.set("v.rows",rows);
      component.set("v.editmode",false); 
     component.set("v.modalHidden",true);
   },
   
    addrow: function(component, event) {

       var rows = component.get("v.rows");
        
       if (rows==null)
       {
            rows = [];
       }

    var valstoadd = component.find("inputtablecontrol");
    var sval=[];
     var types = component.get("v.inputfieldtypes");
        
      
        
    for (var i=0;i<valstoadd.length;i++)
    {
        
       var vall = '';  
        
        vall =  valstoadd[i].get("v.value");
           if (vall==null)
           vall='';
        
        if (types[i]=='fileupload')
        {
            
            var fupl = valstoadd[i];
            
            
            vall = fupl.get('v.fieldName');
        }

        sval.push(vall);
        valstoadd[i].set("v.value",'');
    }
    
    
    rows.push(sval);
    
        
     component.set("v.rows",rows);
     //component.set("v.currentrow", rows.length);
    component.set("v.modalHidden",true);
   },
   
   
       removeRow: function(component, event, helper) {
      
       
       var inputCmp = event.getSource();
       var theindex = inputCmp.get("v.name");
       
       
  
       var rows = component.get("v.rows");
           
       var therow = rows[theindex];
       
       helper.deleteFiles(component, component.get("v.cardcacheid"), therow[therow.length-1]);        
           
       var newrows = [];
  
       for (var t=0;t<theindex;t++)
       {
           newrows.push(rows[t]);
       }
       
       for (var t=theindex+1;t<rows.length;t++)
       {
           newrows.push(rows[t]);
       }
  
      
       component.set("v.rows",newrows);
        
    //   var maxx = component.get("v.controlid");
           
        var rows = component.get("v.rows");
    //  	component.set("v.currentrow", maxx);
           
 
 //     rows.push(rows[rows.length-1]);
      // component.set("v.rows",rows);
   },
   cancelmodal: function(component, event) {
       
       component.set("v.editmode",false); 
       component.set("v.modalHidden",true);
   
   }
   
   
})