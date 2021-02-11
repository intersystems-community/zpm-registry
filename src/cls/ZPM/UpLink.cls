/// Linking a Remote Registry
Class ZPM.UpLink Extends %Persistent
{

/// Remote Registry Label 
Property Name As %String;

Property Host As %String(MAXLEN = 200);

Property Port As %Integer;

Property SSL As %Boolean;

Property Location As %String(MAXLEN = 200);

Property Position As %Integer;

Property Active As %Boolean;

Property PackagesWhiteList As %String(MAXLEN = 30000) [ InitialExpression = "*" ];

Method PackagesWhiteListJSON() As %DynamicArray
{
    If (..PackagesWhiteList="") { 
        Return ""
    }
    Set ja = []
    For i=1:1:$Length(..PackagesWhiteList,",") {
        Do ja.%Push($Piece(..PackagesWhiteList,",",i))
    } 
    return ja
}

Method MatchWhiteList(pkg) As %Boolean
{
    For i=1:1:$Length(..PackagesWhiteList,",") {
        Set pattern = $Piece(..PackagesWhiteList,",",i)
        Set sql = "SELECT 1 WHERE ? %MATCHES ?"
        Set tStatement = ##class(%SQL.Statement).%New()
        Set tStatus = tStatement.%Prepare(sql)
        If ($$$ISERR(tStatus)) { 
            Return 0
        }
        Set tResult = tStatement.%Execute(pkg, pattern)
        If (tResult.%SQLCODE<0) {
            Return 0
        }
        If tResult.%Next() {

            Return 1
        }
    }
    Return 0
}

Method GetHttpRequest()
{
    #Dim httprequest as %Net.HttpRequest
    Set httprequest = ##class(%Net.HttpRequest).%New()
    Set httprequest.Server = ..Host
    Set httprequest.FollowRedirect = 1
    If (..Port'="") { 
        Set httprequest.Port = ..Port
    }
    If (..SSL) {
        Set httprequest.SSLConfiguration = ##class(ZPM.Utils).GetSSLConfiguration()
    }
    Return httprequest
}

ClassMethod UpdatePackagesFromAllUpLinks() As %Status
{
    Set sql = "SELECT ID FROM ZPM.UpLink WHERE Active = 1 ORDER BY Position"
    Set statement = ##class(%SQL.Statement).%New()
    Set tSC = statement.%Prepare(sql)
    If $$$ISERR(tSC) { Return tSC }
    Set resultset=statement.%Execute()
    While resultset.%Next() {
        Set uplink = ..%OpenId(resultset.ID)
        Do uplink.UpdatePackagesFromOneUpLink()
    } 
    Return $$$OK
}

Method UpdatePackagesFromOneUpLink() As %Status
{
    Set httprequest = ..GetHttpRequest()
    Set searchStr = "packages/-/all"
    If (..PackagesWhiteList'="") {
        Set searchTerms = ..PackagesWhiteListJSON()
        Set searchStr = "packages/-/all?q="_$$$URLENCODE(searchTerms.%ToJSON())
    }
    Set tSC = httprequest.Get(..Location_searchStr)
    If ($$$ISERR(tSC)) { Return tSC }
    Try {
        Set packages = [].%FromJSON(httprequest.HttpResponse.Data)
    } Catch { 
        Return 0 
    }
    Set iter = packages.%GetIterator()
    While iter.%GetNext(.key , .package ) {
        Do ..AddPackage(package)
    }
}

ClassMethod LoadPackageFromAllUpLinks(pkg As %String = "", version As %String = "") As ZPM.Package
{
    Set pPackage = ##class(ZPM.Package).%OpenId(pkg_"||"_version)
    If ('$IsObject(pPackage)) {
        Set pPackage = ##class(ZPM.Package).%New()
        Set pPackage.name = pkg
    }

    Set sql = "SELECT ID FROM ZPM.UpLink WHERE Active = 1 ORDER BY Position"
    Set statement = ##class(%SQL.Statement).%New()
    Set tSC = statement.%Prepare(sql)
    If $$$ISERR(tSC) { Return tSC }
    Set resultset=statement.%Execute()
    While resultset.%Next() {
        Set upLink = ..%OpenId(resultset.ID)
        Set tSC = upLink.LoadPackageFromOneUpLink(pPackage, pkg, version)
        If $$$ISOK(tSC) {
            Set tSC = pPackage.%Save()
            If (tSC) { 
                Return pPackage
            }
        }
    } 
    Return $$$NULLOREF
}

Method LoadPackageFromOneUpLink(pPackage As ZPM.Package, pkg As %String = "", version As %String = "") As %Status
{
    // проверить что пакет подпадает под допустимые маски в whitelist
    If ('..MatchWhiteList(pkg)) { 
        Return $$$ERROR($$$GeneralError, "invalid package name "_pkg) 
    }
    Try {
        Set pPackage.UpLink = $this
        $$$ThrowOnError(..LoadManifest(pPackage, pkg, version))
        $$$ThrowOnError(..LoadPackage(pPackage, pkg, version))
        $$$ThrowOnError(..LoadInstaller(pPackage, pkg, version))
    } Catch ex {
        Return ex.AsStatus()
    }
    Return $$$OK
}

Method LoadManifest(pPackage As ZPM.Package, pkg As %String = "", version As %String = "") As %Status
{
    Set tRequest = ..GetHttpRequest()
    Set url = "/packages/"_pkg_"/"_version_"/manifest"
    Set tSC = tRequest.Get(..Location_url)

    If $$$ISERR(tSC) { Return tSC }
    If (tRequest.HttpResponse.StatusCode'=200) {
        Return $$$ERROR($$$GeneralError,"Error downloading manifest "_pkg_" "_version_". HTTPSTATUS:"_tRequest.HttpResponse.StatusCode)
    }
    Do pPackage.manifest.Rewind()
    If ($IsObject(tRequest.HttpResponse.Data)) {
        Do pPackage.manifest.CopyFrom(tRequest.HttpResponse.Data)
    } Else {
        Do pPackage.manifest.Write(tRequest.HttpResponse.Data)
    }

    Set xpathArr("Module/Version")=""
    Set xpathArr("Module/Description")=""
    Set xpathArr("Module/Keywords")=""

    Set tSC = ##class(ZPM.Utils).ReadXMLElements(pPackage.manifest, .xpathArr)
    If $$$ISERR(tSC) { Return tSC }

    If ('$Data(xpathArr("Module/Version","text"))) {
        Return $$$ERROR($$$GeneralError,"Unable to read module version from manifest")
    } 
    Set pPackage.version = $Get(xpathArr("Module/Version","text"))
    Set pPackage.description = $Get(xpathArr("Module/Description","text"))
    Set pPackage.keywords = $Get(xpathArr("Module/Keywords","text"))

    Return $$$OK
}

Method LoadInstaller(pPackage As ZPM.Package, pkg As %String = "", version As %String = "") As %Status
{
    Set tRequest = ..GetHttpRequest()
    Set url = "/packages/"_pkg_"/"_version_"/installer"
    Set tSC = tRequest.Get(..Location_url)
    If $$$ISERR(tSC) { Return tSC }
    If (tRequest.HttpResponse.StatusCode'=200) {
        Return $$$OK    
    }
    Do pPackage.installer.Rewind()
    If ($IsObject(tRequest.HttpResponse.Data)) {
        Do pPackage.installer.CopyFrom(tRequest.HttpResponse.Data)
    }
    Return $$$OK
}

Method LoadPackage(pPackage As ZPM.Package, pkg As %String = "", version As %String = "") As %Status
{
    Set tRequest = ..GetHttpRequest()
    Set url = "/packages/"_pkg_"/"_version
    Set tSC = tRequest.Get(..Location_url)
    If $$$ISERR(tSC) { Return tSC }
    If (tRequest.HttpResponse.StatusCode'=200) {
        Return $$$ERROR($$$GeneralError,"Error downloading package "_pkg_" "_version_". HTTPSTATUS:"_tRequest.HttpResponse.StatusCode)
    }
    Set tRes = {}.%FromJSON(tRequest.HttpResponse.Data)
    Set tPackageUrl = tRes.url
    Set tHash = tRes.hash

    Do ##class(%Net.URLParser).Parse(tPackageUrl,.tComponents)
    If ($Data(tComponents("path"))#2) {
      If ($Extract(tComponents("path"),1,1)="/") {
          Set path = $Extract(tComponents("path"),2,*)	
      }
    }
    Set tRequest = ..GetHttpRequest()
    Set tRequest.Timeout = 300
    Set tSC = tRequest.Get(..Location_path)
    If $$$ISERR(tSC) { Return tSC }
    If (tRequest.HttpResponse.StatusCode'=200) {
        Return $$$ERROR($$$GeneralError,"Error downloading package file "_pkg_" "_version_". HTTPSTATUS:"_tRequest.HttpResponse.StatusCode)
    }
    Set tTestHash = ##class(ZPM.Package).GetPackageHash(tRequest.HttpResponse.Data)
    If (tTestHash'=tHash) {
        Return $$$ERROR($$$GeneralError,"Download module, hash mismatch: "_pkg_" "_version)
    }
    Do pPackage.package.Rewind()
    Do pPackage.package.CopyFrom(tRequest.HttpResponse.Data)
    return $$$OK
}

Method DeleteNewerVersions(name As %String, version As %String = "")
{
    Set id = ..%Id()
    Set versionMajor = +$Piece(version,".",1)
    Set versionMinor = +$Piece(version,".",2)
    Set versionPatch = +$Piece($Piece($Piece(version,".",3),"-"),"+")
    Set versionPrerelease = $Piece($Piece($Piece(version,".",3,*),"-",2,*),"+")
    Set versionBuildmetadata = $Piece(version,"+",2)
    &sql(DELETE FROM ZPM.Package WHERE name=:name AND UpLink=:id AND versionMajor>:versionMajor 
            AND versionMinor>:versionMinor AND versionPatch>:versionPatch AND versionPrerelease>:versionPrerelease AND versionBuildmetadata>:versionBuildmetadata)
}

Method AddPackage(pPackage As %DynamicObject) As %Status
{
    // If this package Exists as Local (published directly to this repo)
    If ( ##class(ZPM.Package).NameUpLinkExists(pPackage.name, "") ) {
        Return 0
    }
    // this version of this package already exists
    If ( ##class(ZPM.Package).NameVersionExists(pPackage.name, pPackage.versions."0")) {
        Return 0
    }

    // match package name
    If ('..MatchWhiteList(pPackage.name)) {
        Return 0
    }

    // remove newer versions  
    Do ..DeleteNewerVersions(pPackage.name, pPackage.versions."0")
    
    // add
    Set tPackage = ##class(ZPM.Package).%New()
    Set tPackage.UpLink = $this
    Set tPackage.name = pPackage.name
    Set tPackage.version = pPackage.versions."0"
    Set tPackage.description = pPackage.description
    Set tPackage.repository = pPackage.repository
    set status = tPackage.%Save()
    do $System.OBJ.DisplayError(status)
}

Storage Default
{
<Data name="UpLinkDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Name</Value>
</Value>
<Value name="3">
<Value>Host</Value>
</Value>
<Value name="4">
<Value>Port</Value>
</Value>
<Value name="5">
<Value>SSL</Value>
</Value>
<Value name="6">
<Value>Location</Value>
</Value>
<Value name="7">
<Value>Position</Value>
</Value>
<Value name="8">
<Value>Active</Value>
</Value>
<Value name="9">
<Value>PackagesWhiteList</Value>
</Value>
</Data>
<DataLocation>^ZPM.UpLinkD</DataLocation>
<DefaultData>UpLinkDefaultData</DefaultData>
<IdLocation>^ZPM.UpLinkD</IdLocation>
<IndexLocation>^ZPM.UpLinkI</IndexLocation>
<StreamLocation>^ZPM.UpLinkS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
