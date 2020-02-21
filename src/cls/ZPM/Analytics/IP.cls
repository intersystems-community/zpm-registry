/// 
Class ZPM.Analytics.IP Extends (%Persistent, %JSON.Adaptor)
{

Property TS As %PosixTime(%JSONINCLUDE = "none") [ SqlComputeCode = {set {*}=##class(%Library.PosixTime).CurrentTimeStamp()}, SqlComputed, SqlComputeOnChange = %%INSERT ];

Property IP As %String(%JSONFIELDNAME = "ip") [ Required ];

Index IPIndex On IP [ Data = TS, Unique ];

Property City As %String(%JSONFIELDNAME = "city");

Property Region As %String(%JSONFIELDNAME = "region");

Property RegionCode As %String(%JSONFIELDNAME = "region_code");

Property Country As %String(%JSONFIELDNAME = "country");

Property CountryCode As %String(%JSONFIELDNAME = "country_code");

Property Latitude As %Decimal(%JSONFIELDNAME = "latitude", SCALE = 4);

Property Longitude As %Decimal(%JSONFIELDNAME = "longitude", SCALE = 4);

Parameter EXTERNALSERVICEURL = "ipapi.co";

Parameter %JSONIGNOREINVALIDFIELD = 1;

ClassMethod LoadIPData(ip As %String) As ZPM.Analytics.IP
{
    If (ip="") {
        Return $$$ERROR($$$GeneralError,"Empty ip")
    }
    Do ..IPIndexDelete(ip)
    Try {
        Set tRequest = ##class(%Net.HttpRequest).%New()
        Set tRequest.FollowRedirect = 1
        Set tRequest.Server = ..#EXTERNALSERVICEURL
        Set tRequest.SSLConfiguration = ..GetSSLConfiguration(tRequest.Server)
        Set tSC = tRequest.Get(ip_"/json/")
        If $$$ISOK(tSC), tRequest.HttpResponse.StatusCode=200 {
            Set ipObj = ..%New()
            $$$THROWONERROR(sc,ipObj.%JSONImport(tRequest.HttpResponse.Data))
            $$$THROWONERROR(sc,ipObj.%Save())
            Return ipObj
        }
    } Catch ex { 
        Return $$$NULLOREF
    }
    Return $$$NULLOREF
}

ClassMethod GetSSLConfiguration(host) As %String
{
  New $NAMESPACE
  Set $NAMESPACE = "%SYS"
  If '##class(Security.SSLConfigs).Exists(host) {
    Do ##class(Security.SSLConfigs).Create(host)
  }
  return host
}

Query ThisDayIPUpdate(ip As %String = "") As %SQLQuery(ROWSPEC = "IP:%String")
{
SELECT IP FROM ZPM_Analytics.IP WHERE IP=:ip AND {fn TIMESTAMPDIFF(SQL_TSI_DAY, TS, NOW())}<1
}

Storage Default
{
<Data name="IPDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>TS</Value>
</Value>
<Value name="3">
<Value>IP</Value>
</Value>
<Value name="4">
<Value>City</Value>
</Value>
<Value name="5">
<Value>Region</Value>
</Value>
<Value name="6">
<Value>RegionCode</Value>
</Value>
<Value name="7">
<Value>Country</Value>
</Value>
<Value name="8">
<Value>CountryCode</Value>
</Value>
<Value name="9">
<Value>Latitude</Value>
</Value>
<Value name="10">
<Value>Longitude</Value>
</Value>
</Data>
<DataLocation>^ZPM.Analytics.IPD</DataLocation>
<DefaultData>IPDefaultData</DefaultData>
<IdLocation>^ZPM.Analytics.IPD</IdLocation>
<IndexLocation>^ZPM.Analytics.IPI</IndexLocation>
<StreamLocation>^ZPM.Analytics.IPS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
