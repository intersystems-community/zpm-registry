Class ZPM.Analytics.Measurement Extends (%Persistent, %JSON.Adaptor)
{

/// Server date and time, saving the data 
Property TS As %PosixTime(%JSONINCLUDE = "none") [ SqlComputeCode = {set {*}=##class(%Library.PosixTime).CurrentTimeStamp()}, SqlComputed, SqlComputeOnChange = %%INSERT ];

/// ModuleName
Property Name As %String(%JSONFIELDNAME = "name", MAXLEN = 50) [ Required ];

Property Version As %String(%JSONFIELDNAME = "version", MAXLEN = 50) [ Required ];

/// Iris Version ($zv)
Property SystemVersion As %String(%JSONFIELDNAME = "system_version", MAXLEN = 100) [ Required ];

Property ZPMClientVersion As %String(%JSONFIELDNAME = "zpmclient_version", MAXLEN = 50);

Property IP As %String(%JSONINCLUDE = "none", MAXLEN = 50);

Property Country As %String(%JSONINCLUDE = "none");

Property Region As %String(%JSONINCLUDE = "none");

Property City As %String(%JSONINCLUDE = "none");

/// Is Installation finished succesfuly
Property Success As %Boolean(%JSONFIELDNAME = "success");

Property ErrorMsg As %String(%JSONFIELDNAME = "error_msg", MAXLEN = 1000);

Parameter %JSONIGNOREINVALIDFIELD = 1;

ForeignKey NameVersionFK(Name,Version) References ZPM.Package(NameVersion);

Method SetIP(ip As %String = "") As %Status
{
    Return:(ip="") $$$OK
    // найти есть ли IP в ZPM.Analytics.IP
    Set tRS = ##class(ZPM.Analytics.IP).ThisDayIPUpdateFunc(ip)
    If (tRS.%SQLCODE<0) {
        Return 0
    }
    If (tRS.%SQLCODE=0) {
        set ipObj = ##class(ZPM.Analytics.IP).IPIndexOpen(ip)
    } else {
        set ipObj = ##class(ZPM.Analytics.IP).LoadIPData(ip)
    }
    Return:('$IsObject(ipObj)) $$$OK
    Set ..IP = ip
    Set ..Country = ipObj.Country
    Set ..Region = ipObj.Region
    Set ..City = ipObj.City
}

ClassMethod SaveMeasurement(ip As %String, json As %DynamicObject) As %Status
{
    Try {
        Set measurement = ..%New()
        DO measurement.%JSONImport(json)
        Do measurement.SetIP(ip)
        $$$THROWONERROR(sc, measurement.%Save())
        Return sc
    } Catch ex {
        Return ex.AsStatus()
    }
}

Storage Default
{
<Data name="MeasurementDefaultData">
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
<Value>ZPMClientVersion</Value>
</Value>
<Value name="7">
<Value>IP</Value>
</Value>
<Value name="8">
<Value>Country</Value>
</Value>
<Value name="9">
<Value>Region</Value>
</Value>
<Value name="10">
<Value>City</Value>
</Value>
<Value name="11">
<Value>Success</Value>
</Value>
<Value name="12">
<Value>ErrorMsg</Value>
</Value>
</Data>
<DataLocation>^ZPM.Analytics.MeasurementD</DataLocation>
<DefaultData>MeasurementDefaultData</DefaultData>
<IdLocation>^ZPM.Analytics.MeasurementD</IdLocation>
<IndexLocation>^ZPM.Analytics.MeasurementI</IndexLocation>
<StreamLocation>^ZPM.Analytics.MeasurementS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
