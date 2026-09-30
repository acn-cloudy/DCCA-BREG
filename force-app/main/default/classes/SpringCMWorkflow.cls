global class SpringCMWorkflow {
    global String Name {set;get;}
    global String Params {set;get;}
    global String Href {set;get;}
    global String Status {set;get;}
    global String Info {set;get;}

    global SpringCMWorkflow(String thename, String theparams) {
    	Name = thename;
    	Params = theparams;
    }
}