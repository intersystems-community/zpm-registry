Class ZPM.Analytics.Event Extends (%Persistent, %JSON.Adaptor)
{

/// Server date and time, saving the data 
Property TS As %PosixTime(%JSONINCLUDE = "none") [ SqlComputeCode = {set {*}=##class(%Library.PosixTime).CurrentTimeStamp()}, SqlComputed, SqlComputeOnChange = %%INSERT ];

/// Event type: download, install, uninstall
Property Type As %String(%JSONINCLUDE = "none", VALUELIST = ",download,install,uninstall");

/// ModuleName
Property Name As %String(%JSONFIELDNAME = "name", MAXLEN = 50) [ Required ];

Property Version As %String(%JSONFIELDNAME = "version", MAXLEN = 50) [ Required ];

Property GUID As %String(%JSONFIELDNAME = "guid");

/// Iris Version ($zv)
Property SystemVersion As %String(%JSONFIELDNAME = "system_version", MAXLEN = 100);

Property SystemVersionOS As %String(%JSONINCLUDE = "none") [ SqlComputeCode = {set {*}=##class(%SYSTEM.Version).GetOS({SystemVersion})}, SqlComputed, SqlComputeOnChange = %%INSERT ];

Property SystemVersionNumber As %String(%JSONINCLUDE = "none") [ SqlComputeCode = {set {*}=##class(%SYSTEM.Version).GetNumber({SystemVersion})}, SqlComputed, SqlComputeOnChange = %%INSERT ];

Property ZPMClientVersion As %String(%JSONFIELDNAME = "zpmclient_version", MAXLEN = 50);

Property IP As %String(%JSONINCLUDE = "none", MAXLEN = 50);

/// Is Installation finished succesfuly
Property Success As %Boolean(%JSONFIELDNAME = "success");

Property ErrorMsg As %String(%JSONFIELDNAME = "error_msg", MAXLEN = 1000);

Parameter %JSONIGNOREINVALIDFIELD = 1;

ForeignKey NameVersionFK(Name,Version) References ZPM.Package(NameVersion);

ClassMethod SaveEvent(action As %String, ip As %String = "", json As %DynamicObject) As %Status
{
    Try {
        Set event = ..%New()
        Set event.Type = action
        DO event.%JSONImport(json)
        $$$THROWONERROR(sc, event.%Save())
        Return sc
    } Catch ex {
        do ex.Log()
        Return ex.AsStatus()
    }
}

Storage Default
{
<Data name="EventDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>TS</Value>
</Value>
<Value name="3">
<Value>Name</Value>
</Value>
<Value name="4">
<Value>Version</Value>
</Value>
<Value name="5">
<Value>SystemVersion</Value>
</Value>
<Value name="6">
<Value>SystemVersionOS</Value>
</Value>
<Value name="7">
<Value>SystemVersionNumber</Value>
</Value>
<Value name="8">
<Value>ZPMClientVersion</Value>
</Value>
<Value name="9">
<Value>IP</Value>
</Value>
<Value name="10">
<Value>Country</Value>
</Value>
<Value name="11">
<Value>Region</Value>
</Value>
<Value name="12">
<Value>City</Value>
</Value>
<Value name="13">
<Value>Success</Value>
</Value>
<Value name="14">
<Value>ErrorMsg</Value>
</Value>
<Value name="15">
<Value>Type</Value>
</Value>
<Value name="16">
<Value>GUID</Value>
</Value>
</Data>
<DataLocation>^ZPM.Analytics.EventD</DataLocation>
<DefaultData>EventDefaultData</DefaultData>
<IdLocation>^ZPM.Analytics.EventD</IdLocation>
<IndexLocation>^ZPM.Analytics.EventI</IndexLocation>
<StreamLocation>^ZPM.Analytics.EventS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
