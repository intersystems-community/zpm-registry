Class ZPM.Analytics.AbstractEventProcessor [ Abstract ]
{

Parameter SubClasses As CONFIGVALUE;

ClassMethod Process(event) As %Status [ Abstract ]
{
    Return $$$OK
}

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
