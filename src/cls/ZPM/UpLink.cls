/// Linking a Remote Registry
Class ZPM.UpLink Extends %Persistent
{

/// Remote Registry Label 
Property Name As %String;

Property Host As %String(MAXLEN = 200) [ Required ];

Index HostIndex On Host [ Unique ];

Property Port As %Integer;

Property SSL As %Boolean;

Property Location As %String(MAXLEN = 200);

Property Position As %Integer;

Property Active As %Boolean;

Property PackagesAllowlist As %String(MAXLEN = 30000) [ InitialExpression = "*" ];

Method PackagesAllowlistJSON() As %DynamicArray
{
    If (..PackagesAllowlist="") { 
        Return ""
    }
    Set ja = []
    For i=1:1:$Length(..PackagesAllowlist,",") {
        Do ja.%Push($Piece(..PackagesAllowlist,",",i))
    } 
    return ja
}

Method MatchAllowlist(pkg) As %Boolean
{
    For i=1:1:$Length(..PackagesAllowlist,",") {
        Set pattern = $Piece(..PackagesAllowlist,",",i)
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
    Set httprequest.Timeout = 10
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
    Do ..ReadUplinksFromFile()
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
    If (..PackagesAllowlist'="") {
        Set searchTerms = ..PackagesAllowlistJSON()
        Set searchStr = "packages/-/all?q="_$$$URLENCODE(searchTerms.%ToJSON())
    }
    Set tSC = httprequest.Get(..Location_searchStr)
    If ($$$ISERR(tSC)) { Return tSC }
    Try {
        Set packages = [].%FromJSON(httprequest.HttpResponse.Data)
        Set iter = packages.%GetIterator()
        While iter.%GetNext(.key , .package ) {
            Do ..AddPackage(package)
        }
    } Catch ex {
        Do ex.Log() 
        Return ex.AsStatus()
    }
}

Method FindPackageInOneUpLink(pkg As %String)
{
    If ('..MatchAllowlist(pkg)) { 
        Return $$$ERROR($$$GeneralError, "invalid package name "_pkg) 
    }
    Set httprequest = ..GetHttpRequest()
    Set searchStr = "packages/"_pkg
    Set tSC = httprequest.Get(..Location_searchStr)
    If ($$$ISERR(tSC)) { Return tSC }
    Try {
        Set package = {}.%FromJSON(httprequest.HttpResponse.Data)
        Set iter = package.versions.%GetIterator()
        While iter.%GetNext(.key , .version ) {
            set tPackage = {"name":(package.name), "description":"", "repository":(package.repository), "versions":[(version)]}
            Do ..AddPackage(tPackage)
        }
    } Catch ex {
        Do ex.Log()
        Return ex.AsStatus()
    }
}

ClassMethod FindPackagInAllUpLinks(pkg As %String) As %Status
{
    Do ..ReadUplinksFromFile()
    Set sql = "SELECT ID FROM ZPM.UpLink WHERE Active = 1 ORDER BY Position"
    Set statement = ##class(%SQL.Statement).%New()
    Set tSC = statement.%Prepare(sql)
    If $$$ISERR(tSC) { Return tSC }
    Set resultset=statement.%Execute()
    While resultset.%Next() {
        Set uplink = ..%OpenId(resultset.ID)
        Do uplink.FindPackageInOneUpLink(pkg)
    } 
    Return $$$OK
}

ClassMethod LoadPackageFromAllUpLinks(pkg As %String = "", version As %String = "") As ZPM.Package
{
    Do ..ReadUplinksFromFile()
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
    // проверить что пакет подпадает под допустимые маски в Allowlist
    If ('..MatchAllowlist(pkg)) { 
        Return $$$ERROR($$$GeneralError, "invalid package name "_pkg) 
    }
    Try {
        Set pPackage.UpLink = $this
        $$$ThrowOnError(..LoadManifest(pPackage, pkg, version))
        $$$ThrowOnError(..LoadPackage(pPackage, pkg, version))
        $$$ThrowOnError(..LoadInstaller(pPackage, pkg, version))
    } Catch ex {
        do ex.Log()
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
    If ('..MatchAllowlist(pPackage.name)) {
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

/// Use file zpm-registry.yaml in InstallDirectory
/// If file doesn't exists - all existing uplinks will be deleted
/// If file exists but doesn't modified - existing uplinks will be used
/// If file exists and modified - delete all existing uplink and then add new from the file
ClassMethod ReadUplinksFromFile() As %Status
{
    Set sc = $$$OK
    Set tFilename = ##class(%SYSTEM.Util).InstallDirectory()_"zpm-registry.yaml"
    If '##class(%File).Exists(tFilename) {
        // if registry config file doesn't exists - remove all uplinks and related cached pakages
        &sql(TRUNCATE TABLE ZPM.UpLink)
        Return sc 
    }
    Try {
        Set tFile = ##class(%File).%New(tFilename)
        If ($Get(^zpmregistry("filemodified")) = tFile.DateModified) {
            // DateTime hasn't changed - skip file 
            Return sc
        }
        set obj = ##class(YAML.Utils).FileToJSON(tFilename, .sc)

        $$$ThrowOnError(sc)
        Set filemodificationTS = tFile.DateModified
        If (..IsDefaultConfig(obj)) {
            // namespace doesn't specified
            Do ..SaveUplinks(obj."uplinks", filemodificationTS)
        } Else{
            //  namespace specified - search for current ns settings
            Set iter = obj.%GetIterator()
            Set ns = $$$lcase($NAMESPACE)
            While iter.%GetNext(.key , .uplinks) {
                If (ns = $$$lcase(key)) {
                    Do ..SaveUplinks(uplinks."uplinks", filemodificationTS)
                }
            }
        }
    } Catch ex {
        do ex.Log()
        Set sc = ex.AsStatus()
    }
    Return sc
}

ClassMethod SaveUplinks(joUplinks As %DynamicObject, filemodificationTS As %String) As %Status
{
    &sql(TRUNCATE TABLE ZPM.UpLink) 
    Set iter = joUplinks.%GetIterator()
    Set position = 0
    While iter.%GetNext(.key , .joOneUplink) {
        Set position = position + 1
        Do ..AddUplink(key, joOneUplink.url, joOneUplink."allow_packages", position)
    }
    Set ^zpmregistry("filemodified") = filemodificationTS
}

ClassMethod IsDefaultConfig(obj As %DynamicObject) As %Boolean
{
    Try {
        If (obj.%GetTypeOf("uplinks")="object") {
            Set iter = obj.uplinks.%GetIterator()
            If iter.%GetNext(.key , .joOneUplink) {
                If (joOneUplink.%IsDefined("url")) {
                    return 1
                }
            }
        }
    } Catch ex {
        return 0
    }
    return 0
}

ClassMethod AddUplink(name, url, allowList, position) As %Status
{
    If (url = "") { return 0 }
    If (allowList = "") { 
        Set allowList = "*"
    }
    Set tUplink = ..%New()
    Do ##class(%Net.URLParser).Parse(url, .tComponents)
    Set host = tComponents("host")
    Set tUplink.Host = host
    Set tUplink.Position = position
    Set tUplink.PackagesAllowlist = allowList
    Set tUplink.Active = 1
    Set tUplink.Name = name

    If $Data(tComponents("port"), port), port'="" {
        Set tUplink.Port = port
    }
    Set tPath = tComponents("path")
    If ($EXTRACT(tPath,*) = "/") {
        Set tPath = $EXTRACT(tPath,1,*-1)
    }
    Set tUplink.Location = tPath
    If $Get(tComponents("scheme"))="https" {
        Set tUplink.SSL = 1
    }
    Return tUplink.%Save()
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
<Value>PackagesAllowlist</Value>
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
