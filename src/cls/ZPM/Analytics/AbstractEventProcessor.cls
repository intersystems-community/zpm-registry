/// To execute your code immediately after the event occurs,
/// you need to create a subclass of this class and override the Process() method in it.
Class ZPM.Analytics.AbstractEventProcessor [ Abstract ]
{

Parameter SubClasses As CONFIGVALUE;

/// Override this method to run your code when event occurs
ClassMethod Process(event as ZPM.Analytics.Event) As %Status [ Abstract ]
{
    Return $$$OK
}

/// Do not change or override this method
ClassMethod getSubClasses() As %String [ CodeMode = objectgenerator ]
{
    Set list = ""

    Set rs = ##class(%Dictionary.ClassDefinitionQuery).SubclassOfFunc("ZPM.Analytics.AbstractEventProcessor")
    While (rs.%Next()) {
        Set list = list _ $listbuild( rs.%GetData(1) )
    }

    Do $system.OBJ.UpdateConfigParam("ZPM.Analytics.AbstractEventProcessor","SubClasses",$listtostring(list,","))
    Do %code.WriteLine(" return $PARAMETER(""ZPM.Analytics.AbstractEventProcessor"",""SubClasses"") ")
    Return $$$OK
}

}
