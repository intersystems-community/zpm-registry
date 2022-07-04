Class ZPM.PackageOEX Extends %Persistent
{

/// packageName in registry DB (ZPM.Package)
Property Name As %String;

/// name without spaces (slug) for the package in OEX
Property NWS As %String [ Required ];

Property OEXLink As %String [ SqlComputeCode = {Set {*} = "https://"_..#OEX_"/package/"_{NWS} }, SqlComputed, SqlComputeOnChange = %%INSERT ];

Property OEXImagePath As %String;

Property FirstApprovalDate As %PosixTime;

Parameter OEX = "openexchange.intersystems.com";

Parameter OEXENDPOINT = "/mpapi/packages/all_for_zpm";

/// Read data from oex 
ClassMethod UpdateOEXPackages() As %Status
{
    //delete all existing data
    Do ..%DeleteExtent()

    Do ..addSSL()
    Set req = ##class(%Net.HttpRequest).%New()
    Set req.SSLConfiguration = ..#OEX
    Set sc = req.Get("https://"_..#OEX_..#OEXENDPOINT)
    Return:$$$ISERR(sc) sc

    If req.HttpResponse.StatusCode '= 200 {
		Return $$$ERROR(5001, "getUserInfo[oAuth]: "_req.HttpResponse.StatusCode_": "_req.HttpResponse.ReasonPhrase)
	}
    Try {
        Set packages = [].%FromJSON(req.HttpResponse.Data)
    } Catch ex {
        Return ex.AsStatus()
    }

    Set iter = packages.%GetIterator()
    While iter.%GetNext(.key, .package) {
        // find package in our DB by PackageName
        Set id = ""
        Set tName = package.PackageName
        &sql(SELECT ID INTO :id FROM ZPM.Package WHERE name = :tName AND UpLink IS NULL)
        If (id '= "") {
            Set oexPackage = ..%New()
            Set oexPackage.Name = package.PackageName
            Set oexPackage.NWS = package.NWS
            Set oexPackage.OEXImagePath = package.ImageURL
            Set oexPackage.FirstApprovalDate = package.FirstApprovalDate
            Set tSC = oexPackage.%Save()
            Return:($$$ISERR(tSC)) tSC
        }
    }
    Return $$$OK
}

ClassMethod addSSL()
{
    New $NAMESPACE
    Set $NAMESPACE = "%SYS"
    If '##class(Security.SSLConfigs).Exists(..#OEX) {
        Do ##class(Security.SSLConfigs).Create(..#OEX)
    }
}

Storage Default
{
<Data name="PackageOEXDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Package</Value>
</Value>
<Value name="3">
<Value>NWS</Value>
</Value>
<Value name="4">
<Value>OEXLink</Value>
</Value>
<Value name="5">
<Value>OEXImagePath</Value>
</Value>
<Value name="6">
<Value>FirstApprovalDate</Value>
</Value>
<Value name="7">
<Value>Name</Value>
</Value>
</Data>
<DataLocation>^ZPM.PackageOEXD</DataLocation>
<DefaultData>PackageOEXDefaultData</DefaultData>
<IdLocation>^ZPM.PackageOEXD</IdLocation>
<IndexLocation>^ZPM.PackageOEXI</IndexLocation>
<StreamLocation>^ZPM.PackageOEXS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
