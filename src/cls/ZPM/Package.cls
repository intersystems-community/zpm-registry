Class ZPM.Package Extends (%Persistent, %JSON.Adaptor)
{

Parameter EXTENTQUERYSPEC = "name,version";

Parameter %JSONIGNOREINVALIDFIELD As BOOLEAN = 1;

Property name As %String(MAXLEN = 50) [ Required ];

Index Name On name;

Property version As %String [ Required ];

Index NameVersion On (name, version) [ IdKey, Unique ];

Property owner As %String(%JSONINCLUDE = "NONE");

Index Owner On owner;

Property description As %String(MAXLEN = 1000, TRUNCATE = 1);

Property keywords As list Of %String;

Property license As %String;

Property homePage As %String;

Property repository As %String(MAXLEN = 200);

Index Repository On repository;

Property dependencies As array Of %String;

Property package As %Stream.GlobalBinary(%JSONINCLUDE = "NONE");

Property size As %Integer(%JSONINCLUDE = "OUTPUTONLY");

Property manifest As %Stream.GlobalCharacter(%JSONINCLUDE = "INPUTONLY");

Property installer As %Stream.GlobalCharacter(%JSONINCLUDE = "INPUTONLY");

Property hash As %String(%JSONINCLUDE = "OUTPUTONLY") [ SqlComputeCode = { Set {*} = ..GetPackageHash({package})}, SqlComputed, SqlComputeOnChange = %%UPDATE ];

Property url As %String(%JSONINCLUDE = "OUTPUTONLY", MAXLEN = 200) [ Transient ];

Property installerUrl As %String(%JSONFIELDNAME = "installer", %JSONINCLUDE = "OUTPUTONLY", MAXLEN = 200) [ Transient ];

Property versions As list Of %String(%JSONINCLUDE = "OUTPUTONLY", MAXLEN = 200) [ Transient ];

Property platformVersions As list Of %String(%JSONFIELDNAME = "platform_versions", %JSONINCLUDE = "OUTPUTONLY", MAXLEN = 10) [ Transient ];

Property versionMajor As %Integer(%JSONINCLUDE = "NONE") [ SqlComputeCode = {Set {*} = +$Piece({version},".",1)}, SqlComputed, SqlComputeOnChange = %%INSERT ];

Property versionMinor As %Integer(%JSONINCLUDE = "NONE") [ SqlComputeCode = {Set {*} = +$Piece({version},".",2)}, SqlComputed, SqlComputeOnChange = %%INSERT ];

Property versionPatch As %Integer(%JSONINCLUDE = "NONE") [ SqlComputeCode = {Set {*} = +$Piece($Piece($Piece({version},".",3),"-"),"+")}, SqlComputed, SqlComputeOnChange = %%INSERT ];

Property versionPrerelease As %String(%JSONINCLUDE = "NONE") [ SqlComputeCode = {Set {*} = $Piece($Piece($Piece({version},".",3,*),"-",2,*),"+")}, SqlComputed, SqlComputeOnChange = %%INSERT ];

Property versionBuildmetadata As %String(%JSONINCLUDE = "NONE") [ SqlComputeCode = {Set {*} = $Piece({version},"+",2)}, SqlComputed, SqlComputeOnChange = %%INSERT ];

Property publishTS As %PosixTime [ SqlComputeCode = {Set {*} = ##class(%Library.PosixTime).CurrentUTCTimeStamp()}, SqlComputed, SqlComputeOnChange = %%INSERT ];

Property UpLink As ZPM.UpLink(%JSONINCLUDE = "NONE");

ForeignKey UpLinkFK(UpLink) References ZPM.UpLink() [ OnDelete = cascade ];

Index NameUpLink On (name, UpLink);

Property deployed As %Boolean;

Property deleted As %Boolean [ InitialExpression = 0 ];

Method nameSet(value As %String) As %Status
{
  Set i%name = $$$lcase(value)
  Quit $$$OK
}

Method sizeGet() As %Integer
{
  Return:'..package.Size ""
  Return ..package.Size
}

Method packageFromBase64(base64 As %Stream.DynamicBinary) As %Status
{
  Set sc = $$$OK
  Do ..package.Clear()
  Do base64.Rewind()
  While 'base64.AtEnd {
    Set tSC = ..package.Write($System.Encryption.Base64Decode(base64.Read(43540, .sc))) 
    Set:$$$ISERR(tSC) sc = $$$ADDSC(sc,tSC)
  }
  Quit sc
}

Method filepathGet() As %String [ CodeMode = expression ]
{
..name _ "/-"
}

Method filenameGet() As %String [ CodeMode = expression ]
{
..name _ "-" _ ..version
}

ClassMethod GetPackageHash(pStream As %Stream.Object) As %String
{
  If (pStream="") { Return "" }
  If '$IsObject(pStream) { Set pStream = ..packageOpen(pStream) }
  Set hash = $System.Encryption.SHA1HashStream(pStream)
  Set str="" 
  For i=1:1:$Length(hash) {
		Set str=str_$Translate($Justify($ZHex($Ascii(hash, i)),2)," ",0)
	}
  Return $$$lcase(str)
}

Method urlGet() As %String
{
  Quit:'..size ""
  Set host = ##class(ZPM.Utils).ServerURL()
  Return host _ "/download/" _ $ZConvert(..filepathGet() _ "/" _ ..filenameGet() _ ".tgz", "O", "URL")
}

Method installerUrlGet() As %String
{
  If ('..installer.Size) {
    Return ""
  }
  Set host =  ##class(ZPM.Utils).ServerURL()
  Set name = $ZConvert(..name, "O", "URL")
  Set version = $ZConvert(..version, "O", "URL")
  Return host _ "/packages/" _ name _ "/" _ version _ "/installer"
}

Method versionsGet() As %ListOfDataTypes
{
  Set tList = ##class(%ListOfDataTypes).%New()

  Set name = ..name
  &sql(SELECT %DLIST(version) INTO :versions FROM Package WHERE name = :name)
  If (SQLCODE=0) {
    Set ptr = 0
    While $ListNext(versions, ptr, version) {
      Continue:version=""
      Set list(version) = ""
    }
  }

  Set version = ""
  For {
    Set version = $Order(list(version), 1)
    Quit:version=""
    Do tList.Insert(version)
  }
  Return tList
}

ClassMethod VersionFind(pkg As %String = "", version As %String = "") As %String
{
  If (version = "") || (version = "latest") || (version = "*") {
    // package was published directly in this registry - return the last version
    &sql(SELECT TOP 1 Version INTO :version FROM ZPM.Package WHERE Name = :pkg AND UpLink IS NULL
          ORDER BY versionMajor DESC, versionMinor DESC, versionPatch DESC, versionPrerelease DESC, versionBuildmetadata DESC
    )
    If SQLCODE=0 { 
      // found 
      Return version
    } Else {
      // find the latest version in UpLinks 
      Do ##class(ZPM.UpLink).LoadPackageFromAllUpLinks(pkg, "latest")
      &sql(SELECT TOP 1 Version INTO :version FROM ZPM.Package WHERE Name = :pkg
          ORDER BY versionMajor DESC, versionMinor DESC, versionPatch DESC, versionPrerelease DESC, versionBuildmetadata DESC
      )
      If SQLCODE=0 { 
        // if manifest doesn''t exists - find in uplinks
        Set package = ##class(ZPM.Package).%OpenId(pkg_"||"_version)
        If ('$IsObject(package)) { Return ""}
        If (package.manifest.Size) { Return version }
        Do ##class(ZPM.UpLink).LoadPackageFromAllUpLinks(pkg, version)
        Return version
      } 
      Return ""
    }
  } Else {
    If ( ##class(ZPM.Package).NameUpLinkExists(pkg, "") ) {
      If ..%ExistsId(pkg _ "||" _ version) {
        Return version
      } 
      Return ""
    } Else {
      If ..%ExistsId(pkg _ "||" _ version) {
        Set package = ##class(ZPM.Package).%OpenId(pkg_"||"_version)
        If ('$IsObject(package)) { Return ""}
        If (package.manifest.Size) { Return version }
      } 
      Do ##class(ZPM.UpLink).LoadPackageFromAllUpLinks(pkg, version)
      If ..%ExistsId(pkg _ "||" _ version) {
        Return version
      }
      Return ""
    }
  }
}

Trigger DeletePackageTrigger [ Event = DELETE, Foreach = row/object ]
{
  // delete DeployedPackage
  New id,package,name,version
  Set id = {ID}
  Set package = ##class(Package).%OpenId(id)
  Set name = package.name
  Set version = package.version
  &sql(DELETE FROM ZPM.DeployedPackage WHERE name = :name AND version = :version)
}

ClassMethod MarkAsDeleted(name, version) As %Boolean
{
  Set package = ##class(ZPM.Package).NameVersionOpen(name, version, , .tSC)
  If ($ISOBJECT(package) && (package.deleted = 1)) {
    Return 1
  }
  Return 0
}

Method platformVersionsGet() As %ListOfDataTypes
{
  Set tList = ##class(%ListOfDataTypes).%New()

  Set name = ..name
  Set version = ..version
  &sql(SELECT %DLIST(platformVersion) INTO :versions FROM DeployedPackage WHERE name = :name AND version = :version)
  If (SQLCODE=0) {
    Set ptr = 0
    While $ListNext(versions, ptr, version) {
      Continue:version=""
      Set list(version) = ""
    }
  }

  Set version = ""
  For {
    Set version = $Order(list(version), 1)
    Quit:version=""
    Do tList.Insert(version)
  }
  Return tList
}

ClassMethod DeleteExistingPackages(pkg As %String, version As %String) As %Status
{
  // delete all "proxy" packages
  &sql(DELETE FROM ZPM.Package WHERE Name = :pkg AND UpLink IS NOT NULL)
  Set tSC = ..NameVersionDelete(pkg, version)
  Return:$$$ISERR(tSC) tSC

  Return $$$OK
}

ClassMethod DeletePackageVersion(pkg As %String, version As %String) As %Status
{
  Set package = ##class(ZPM.Package).NameVersionOpen(pkg, version, , .tSC)
  Return:$$$ISERR(tSC) tSC
  Set package.deleted = 1
  Return package.%Save()
}

ClassMethod DeletePackage(pkg As %String) As %Status
{
  &sql(DELETE FROM ZPM.Package WHERE name = :pkg)
  If SQLCODE'=0 Return $$$ERROR($$$SQLError, SQLCODE, $g(%msg))
  Return $$$OK
}

ClassMethod versionValidate(pkg As %String = "", version As %String = "") As %String
{
  If (pkg="") {
    Return ""
  }
  If (version = "") || (version = "latest") || (version = "*") {
    &sql(SELECT TOP 1 Version INTO :version FROM ZPM.Package WHERE Name = :pkg 
          ORDER BY versionMajor DESC, versionMinor DESC, versionPatch DESC, versionPrerelease DESC, versionBuildmetadata DESC
    )
    If SQLCODE'=0 Return ""
    Return version
  }
  If ..%ExistsId(pkg _ "||" _ version) {
    Return version
  }
  Return ""
}

ClassMethod Populate(Path As %String, kill = 0)
{
  If '##class(%File).DirectoryExists(Path) {
    Return
  }
  
  Do:kill ..%KillExtent()
  
  Set rs = ##class(%File).FileSetFunc(Path)
  While rs.%Next() {
    Set name = rs.name
    Continue:rs.Type'="D"
    
    Set tSC = ..LoadPackage(name)
    If $$$ISERR(tSC) {
      Do $System.OBJ.DisplayError(tSC)
    }
  }
}

Method UpdateDescriptionFromManifest() As %Status
{
  Try {
    Quit:'..manifest.Size
    $$$ThrowOnError(##class(%XML.XPATH.Document).CreateFromStream(..manifest, .tDocument))
    $$$ThrowOnError(tDocument.EvaluateExpression("/Module/Description", "text()", .tRes))
    If (tRes.Count()>0) {
      Set ..description = tRes.GetAt(1).Value
    }
  } Catch ex {
    Do ex.Log()
    Return ex.AsStatus()
  }
  Return $$$OK
}

ClassMethod LoadPackage(Path As %String, repository As %String = "", silent As %Boolean = 0) As %Status
{
  Set tStream = ##class(%Stream.FileCharacter).%New()
  Set moduleFile = ##class(%File).NormalizeFilename("module.xml", Path)
  If '##class(%File).Exists(moduleFile) {
    Set Path = ##class(%File).NormalizeDirectory("latest", Path)
    Set moduleFile = ##class(%File).NormalizeFilename("module.xml", Path)
  }
  If ('silent) {
    Write !!,"Path: ",Path
    Write !!,"ModuleFile: ",moduleFile
  }
  Set tSC = ##class(%XML.XPATH.Document).CreateFromFile(moduleFile, .tDocument)
  If $$$ISERR(tSC) Return tSC

  Set tSC=tDocument.EvaluateExpression("/Export/Document/Module/Name", "text()", .tRes)
  If $$$ISERR(tSC) Return tSC
  If '$IsObject(tRes.GetAt(1)) {
    Return $$$ERROR($$$GeneralError, "Name required")
  }
  Set name = tRes.GetAt(1).Value
  Set name = $$$lcase(name)
  If ('silent) {
    Write !,"Name: ", name
  }

  Set tSC=tDocument.EvaluateExpression("/Export/Document/Module/Version", "text()", .tRes)
  If $$$ISERR(tSC) Return tSC
  If '$IsObject(tRes.GetAt(1)) {
    Return $$$ERROR($$$GeneralError, "Version required")
  }
  Set version = tRes.GetAt(1).Value
  If ('silent) {
    Write !,"Version: ", version
  }

  Set description = ""
  Set tSC=tDocument.EvaluateExpression("/Export/Document/Module/Description", "text()", .tRes)
  If $$$ISERR(tSC) Return tSC
  If $IsObject(tRes.GetAt(1)) {
    Set description = tRes.GetAt(1).Value
  }

  Set archive = ##class(%Stream.FileBinary).%New()
  Set archiveFileName = ##class(%File).TempFilename("tgz")
  Set archive.Filename = archiveFileName

  Set command = "cd " _ Path _ " && tar -zcvf " _ archiveFileName _ " . "

  Set args = 0
  Set res = $Zf(-100, "", "tar", "--exclude=.git", "-zcvf", archiveFileName, "-C",  Path, ".")
  If ('silent) {
    Write "ArchiveSize: " _ archive.Size
  }

  Do ..DeleteExistingPackages(name,version)
  Set package = ..%New()
  Set package.name = name
  Set package.description = description
  Set package.repository = repository
  Set package.version = version
  Set package.package = archive
  Set module = ##class(%Stream.FileCharacter).%New()
  Set module.Filename = moduleFile
  Set package.manifest = module
  Set hash = $$$lcase(##class(%File).SHA1Hash(archiveFileName, 1))  
  Set package.hash = hash
  If ('silent) {
    Write !,"ArchiveHash: " _ hash
  }
  Return package.%Save()
}

ClassMethod GetPackageNameFromRepositoryURL(url As %String) As %String
{
  Return $Piece(url, "/", *-1)
}

ClassMethod GetDefaultBranch(path As %String) As %String
{
  If ($Extract(path,$Length(path))="/") {
    Set path = $Extract(path,1,*-1)
  }
  Set branch = "main"
  Set ht = ##class(%Net.HttpRequest).%New()
  Set ht.Server = "api.github.com"
  Set ht.SSLConfiguration = ##class(ZPM.Utils).GetSSLConfiguration()
  Set ht.Https = 1
  Set ht.Location = "/repos"_path 
  $$$ThrowOnError(ht.Get())
  If (ht.HttpResponse.StatusCode=200) {
    Set jo = {}.%FromJSON(ht.HttpResponse.Data)
    Set branch = jo."default_branch" 
  }
  Return branch
}

ClassMethod DownloadPackageFromGitHub(url As %String, Output branch As %String) As %String
{
  Do ##class(%Net.URLParser).Parse(url, .tComponents)
  Set branch = ..GetDefaultBranch(tComponents("path"))
  Set ht = ##class(%Net.HttpRequest).%New()
  Set ht.Server = tComponents("host")
  If $Get(tComponents("scheme"))="https" {
    Set ht.SSLConfiguration = ##class(ZPM.Utils).GetSSLConfiguration()
    Set ht.Https = 1
  }
  If $Data(tComponents("port"), port), port'="" {
    Set ht.Port = port
  }
  Set ht.Location = tComponents("path")_"archive/"_branch_".tar.gz"
  $$$ThrowOnError(ht.Get())
  If (ht.HttpResponse.StatusCode'=200) {
    $$$ThrowStatus($$$ERROR(5001,"Unable to download repository "_url))
  }

  #dim response As %Net.HttpResponse
  Set fs = ##class(%Stream.FileBinary).%New()
  Set archiveFileName = ##class(%File).TempFilename("tgz")
  Set fs.Filename = archiveFileName
  Do fs.CopyFromAndSave(ht.HttpResponse.Data)

  Set outputFolder = $$$FileTempDir
  Set res = $Zf(-100, "", "tar", "-zxvf", archiveFileName, "-C", outputFolder)

  Return outputFolder
}

ClassMethod GetModuleMeta(url As %String) As %DynamicObject
{
  Set jo = {"name":"", "version":""}
  Do ##class(%Net.URLParser).Parse(url, .tComponents)
  Set ht = ##class(%Net.HttpRequest).%New()
  Set ht.Server = "raw.githubusercontent.com"
  If $Get(tComponents("scheme"))="https" {
    Set ht.SSLConfiguration = ##class(ZPM.Utils).GetSSLConfiguration()
    Set ht.Https = 1
  }
  If $Data(tComponents("port"), port), port'="" {
    Set ht.Port = port
  }
  Set ht.Location = tComponents("path")_"master/module.xml"
  $$$ThrowOnError(ht.Get())
  If (ht.HttpResponse.StatusCode'=200) {
    $$$ThrowStatus($$$ERROR(5001,"Unable to download XML "_ht.Location))
  }

  Set xPathArray("Module/Version")=""
  Set xPathArray("Module/Name")=""
  $$$ThrowOnError(##class(ZPM.Utils).ReadXMLElements(ht.HttpResponse.Data, .xPathArray))

  Set jo.name = $Get(xPathArray("Module/Name","text"))
  Set jo.version = $Get(xPathArray("Module/Version","text"))
  
  Return jo
}

ClassMethod UpdatePackage(jo As %DynamicObject) As %Status
{
  Set outputFolder = ""
  Try {
    Set url = jo.repository
    If $Extract(url, *)'="/" {
      Set url = url _ "/"
    } 
    Set name = ..GetPackageNameFromRepositoryURL(url)
    Set meta = ..GetModuleMeta(url)
    If (meta.version = "") { $$$ThrowStatus($$$ERROR(5001, "Invalid package version")) }
    If (meta.name = "") { $$$ThrowStatus($$$ERROR(5001, "Package name is empty")) }
    Set tName = $$$lcase(meta.name)
    Set id = ""

    &sql(DELETE FROM ZPM.Package WHERE Name = :tName AND UpLink IS NOT NULL) // delete all "proxy" packages

    &sql(SELECT ID into :id FROM ZPM.Package WHERE name=:tName ORDER BY versionMajor DESC, versionMinor DESC, versionPatch DESC, versionPrerelease  DESC)
    If (id'="") { 
      If (..repositoryGetStored(id)'=url) { 
        $$$ThrowStatus($$$ERROR(5001, "Invalid repository for this Package"))
      } Else { 
        If (..NameVersionExists(meta.name,meta.version)) { 
          $$$ThrowStatus($$$ERROR(5001, "Version "_meta.version_" of Package "_meta.name_" is already published"))
        }
      	Set sc = ..Publish(url, name)	
      }
    } Else {
      If (..RepositoryExists(url, .id)) {
	      $$$ThrowStatus($$$ERROR(5001, "This repository was published under a different name"))
      } Else {
        Set sc = ..Publish(url, name)	
      }
    }
  } Catch ex {
    Set sc = ex.AsStatus() 
  }
  If (outputFolder'="") {
    Do ##class(%File).RemoveDirectoryTree(outputFolder)
  }  
  Return sc
}

ClassMethod Publish(url As %String, name As %String) As %Status
{
  Set branch = "master"
  Set outputFolder = ..DownloadPackageFromGitHub(url, .branch)
  Set packageFolder = ##class(%File).NormalizeDirectory(name_"-"_branch, outputFolder)
  Return ..LoadPackage(packageFolder, url, 1)
}

ClassMethod LoadFromGitHub(Url = "")
{
  If Url="" {
    Return ""
  }
  If $Extract(Url, *)'="/" { 
    Set Url = Url _ "/"
  }
  Set name = ..GetPackageNameFromRepositoryURL(Url)
  Set branch = "master"
  Set outputFolder = ..DownloadPackageFromGitHub(Url, .branch)
  Set packageFolder = ##class(%File).NormalizeDirectory(name_"-"_branch, outputFolder)
  Set tSC = ..LoadPackage(packageFolder, Url)
  If $$$ISERR(tSC) { 
    Do $System.OBJ.DisplayError() 
  } Else { 
    Write !,"Success" 
  }
  Do ##class(%File).RemoveDirectoryTree(outputFolder)
}

/// returns latest versions of packages 
ClassMethod GetLatest(searchTerms As %DynamicArray = "", manifest As %String = "", allVersions As %String = "", owner As %String = "", Output pStatus As %Status) As %DynamicArray
{
  Set pStatus = 1
  Set params = 1
  Set params(params) = owner

  If ( '($ClassName(searchTerms)="%Library.DynamicArray" ) || (searchTerms.%Size()=0) ) {
    // empty query
    Set searchCondition = " ( 1=1 ) "
  } Else {
    Set searchCondition = " ( "
    Set iter = searchTerms.%GetIterator()
    While iter.%GetNext(.key , .value ) {
      If (key=0) {
        Set searchCondition = searchCondition _ " ((p1.name %MATCHES ?) OR (p1.description %MATCHES ?) OR (p1.keywords %MATCHES ?)) "
      } Else {
        Set searchCondition = searchCondition _ " OR ((p1.name %MATCHES ?) OR (p1.description %MATCHES ?) OR (p1.keywords %MATCHES ?))"
      }
      Set params(params+1) = value
      Set params(params+2) = value
      Set params(params+3) = value
      Set params = params + 3
    }
    Set searchCondition = searchCondition_ " ) "
  }

  Set sql = "SELECT p1.name, p1.repository, p1.description, p1.version, ul.Host, IFNULL( (SELECT TOP 1 1 FROM ZPM.Package p3 WHERE p1.name=p3.name AND p3.owner = ? ORDER BY p3.versionMajor DESC, p3.versionMinor DESC, p3.versionPatch DESC, p3.versionPrerelease DESC, p3.versionBuildmetadata DESC ), 0, 1) as owner"_
            "  FROM ZPM.Package p1 "_
            "  LEFT JOIN ZPM.UpLink ul ON ul.ID = p1.UpLink " _
            "  WHERE deleted = 0 OR deleted IS NULL AND "_searchCondition_" "_ 
            " AND p1.version = ( SELECT TOP 1 version FROM ZPM.Package p2 WHERE p1.name=p2.name ORDER BY p2.versionMajor DESC, p2.versionMinor DESC, p2.versionPatch DESC, p2.versionPrerelease DESC, p2.versionBuildmetadata DESC ) "

  Set tStatement = ##class(%SQL.Statement).%New()
  Set tStatus = tStatement.%Prepare(sql)
  If ($$$ISERR(tStatus)) { 
    Set pStatus = tStatus
    Return []
  }
  Set tResult = tStatement.%Execute(params...)
  If (tResult.%SQLCODE<0) {
    Set pStatus = $$$ERROR(5001, "Error executing sql statement")
    Return []
  }
  Set tList = []
  While tResult.%Next() {
    Set tPkgInfo = {
      "name": (tResult.name),
      "description": (tResult.description),
      "repository": (tResult.repository),
      "origin": (tResult.Host),
      "versions": [(tResult.version)],
      "is_owner":(tResult.owner)
    }

    If (manifest = "1") {
      Set tPkgInfo.manifest = ""
      Set package = ##class(ZPM.Package).%OpenId(tResult.name_"||"_tResult.version)
      If ($IsObject(package.manifest)) {
        While ('package.manifest.AtEnd) {
          Set tPkgInfo.manifest = tPkgInfo.manifest _ package.manifest.Read(100)
        }
      }
    }

    If (allVersions = "1") {
      Set tPkgInfo.allVersions = []
      Set sql2 = "SELECT version "_
            " FROM ZPM.Package WHERE name = ? "_
            " ORDER BY versionMajor DESC, versionMinor DESC, versionPatch DESC, versionPrerelease DESC, versionBuildmetadata DESC"
      Set versionsResult = ##class(%SQL.Statement).%ExecDirect(, sql2, tResult.name)
      While versionsResult.%Next() {
        Do tPkgInfo.allVersions.%Push(versionsResult.version)
      }
    }

    Do tList.%Push(tPkgInfo)
  }
  Return tList
}

Query ListLatest(searchTerm As %String = "") As %SQLQuery(ROWSPEC = "name:%String,description:%String,repository:%String,version:%String")
{
SELECT name, repository, version, description 
FROM ZPM.Package p1
WHERE 
  version= (  
    SELECT TOP 1 version FROM ZPM.Package p2 WHERE p1.name=p2.name 
    ORDER BY versionMajor DESC, versionMinor DESC, versionPatch DESC, versionPrerelease DESC, versionBuildmetadata DESC ) 
  AND (:searchTerm IS NULL OR (
     name %MATCHES :searchTerm
  OR description %MATCHES :searchTerm
  OR keywords %MATCHES :searchTerm)
)
GROUP BY name
ORDER BY name
}

Storage Default
{
<Data name="PackageDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>owner</Value>
</Value>
<Value name="3">
<Value>description</Value>
</Value>
<Value name="4">
<Value>keywords</Value>
</Value>
<Value name="5">
<Value>license</Value>
</Value>
<Value name="6">
<Value>homePage</Value>
</Value>
<Value name="7">
<Value>repository</Value>
</Value>
<Value name="8">
<Value>package</Value>
</Value>
<Value name="9">
<Value>hash</Value>
</Value>
<Value name="10">
<Value>manifest</Value>
</Value>
<Value name="11">
<Value>size</Value>
</Value>
<Value name="12">
<Value>installer</Value>
</Value>
<Value name="13">
<Value>versionMajor</Value>
</Value>
<Value name="14">
<Value>versionMinor</Value>
</Value>
<Value name="15">
<Value>versionPatch</Value>
</Value>
<Value name="16">
<Value>versionLabel</Value>
</Value>
<Value name="17">
<Value>versionPrerelease</Value>
</Value>
<Value name="18">
<Value>versionBuildmetadata</Value>
</Value>
<Value name="19">
<Value>UpLink</Value>
</Value>
<Value name="20">
<Value>publishTS</Value>
</Value>
<Value name="21">
<Value>deployed</Value>
</Value>
<Value name="22">
<Value>platformVersion</Value>
</Value>
<Value name="23">
<Value>deleted</Value>
</Value>
</Data>
<Data name="dependencies">
<Attribute>dependencies</Attribute>
<Structure>subnode</Structure>
<Subscript>"dependencies"</Subscript>
</Data>
<DataLocation>^ZPM.PackageD</DataLocation>
<DefaultData>PackageDefaultData</DefaultData>
<IdLocation>^ZPM.PackageD</IdLocation>
<IndexLocation>^ZPM.PackageI</IndexLocation>
<StreamLocation>^ZPM.PackageS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
