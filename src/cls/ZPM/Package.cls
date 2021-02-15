Class ZPM.Package Extends (%Persistent, ZPM.JSON.Adaptor)
{

Parameter EXTENTQUERYSPEC = "name,version";

Property name As %String(MAXLEN = 50) [ Required ];

Index Name On name;

Property version As %String [ Required ];

Index NameVersion On (name, version) [ IdKey, Unique ];

Property owner As %String;

Index Owner On owner;

Property description As %String(MAXLEN = 1000, TRUNCATE = 1);

Property keywords As list Of %String;

Property license As %String;

Property homePage As %String;

Property repository As %String(MAXLEN = 200);

Index Repository On repository;

Property dependencies As array Of %String;

Property package As %Stream.GlobalBinary(%JSONINCLUDE = "INPUTONLY");

Property size As %Integer(%JSONINCLUDE = "OUTPUTONLY");

Property manifest As %Stream.GlobalCharacter(%JSONINCLUDE = "INPUTONLY");

Property installer As %Stream.GlobalCharacter(%JSONINCLUDE = "INPUTONLY");

Property hash As %String(%JSONINCLUDE = "OUTPUTONLY") [ SqlComputeCode = { set {*} = ..GetPackageHash({package})}, SqlComputed, SqlComputeOnChange = package ];

Property url As %String(%JSONINCLUDE = "OUTPUTONLY", MAXLEN = 200) [ Transient ];

Property installerUrl As %String(%JSONFIELDNAME = "installer", %JSONINCLUDE = "OUTPUTONLY", MAXLEN = 200) [ Transient ];

Property versions As list Of %String(%JSONINCLUDE = "OUTPUTONLY", MAXLEN = 200) [ Transient ];

Property versionMajor As %Integer [ SqlComputeCode = {Set {*} = +$Piece({version},".",1)}, SqlComputed, SqlComputeOnChange = %%INSERT ];

Property versionMinor As %Integer [ SqlComputeCode = {Set {*} = +$Piece({version},".",2)}, SqlComputed, SqlComputeOnChange = %%INSERT ];

Property versionPatch As %Integer [ SqlComputeCode = {Set {*} = +$Piece($Piece($Piece({version},".",3),"-"),"+")}, SqlComputed, SqlComputeOnChange = %%INSERT ];

Property versionPrerelease As %String [ SqlComputeCode = {Set {*} = $Piece($Piece($Piece({version},".",3,*),"-",2,*),"+")}, SqlComputed, SqlComputeOnChange = %%INSERT ];

Property versionBuildmetadata As %String [ SqlComputeCode = {Set {*} = $Piece({version},"+",2)}, SqlComputed, SqlComputeOnChange = %%INSERT ];

Property UpLink As ZPM.UpLink(%JSONINCLUDE = "NONE");

Index NameUpLink On (name, UpLink);

Method nameSet(value As %String) As %Status
{
  set i%name = $$$lcase(value)
  Quit $$$OK
}

Method sizeGet() As %Integer
{
  return ..package.Size
}

ClassMethod GetPackageHash(pStream As %Stream.Object) As %String
{
  If (pStream="") { Return "" }
  If '$isobject(pStream) Set pStream = ..packageOpen(pStream)
  set hash = $system.Encryption.SHA1HashStream(pStream)
  Set str="" 
  For i=1:1:$length(hash) {
		Set str=str_$translate($justify($zhex($ascii(hash, i)),2)," ",0)
	}
  RETURN $$$lcase(str)
}

ClassMethod ServerURL() As %String
{
  Set host = ""
  If $ISOBJECT($Get(%request)) {
    Set tSecure = %request.Secure 
    Set host = %request.GetCgiEnv("HTTP_X_FORWARDED_HOST", %request.GetCgiEnv("SERVER_NAME"))
    Set proto = %request.GetCgiEnv("HTTP_X_FORWARDED_PROTO", $SELECT(tSecure: "https", 1: "http"))
    Set port = %request.GetCgiEnv("HTTP_X_FORWARDED_PORT", %request.GetCgiEnv("SERVER_PORT"))
    Set host = proto _ "://" _ host
    If '$LISTFIND($LISTBUILD(80, 443), port) {
      Set host = host_":"_port
    }    
  }
  Set host = host_$p(%request.Application,"/",1,*-1)
  Return host
}

Method urlGet() As %String
{
  SET host = ..ServerURL()
  SET name = $ZCONVERT(..name, "O", "URL")
  SET version = $ZCONVERT(..version, "O", "URL")
  RETURN host _ "/download/" _ name _ "/-/" _ name _ "-" _ version _ ".tgz"
}

Method installerUrlGet() As %String
{
  If ('..installer.Size) {
    RETURN ""
  }
  SET host = ..ServerURL()
  SET name = $ZCONVERT(..name, "O", "URL")
  SET version = $ZCONVERT(..version, "O", "URL")
  RETURN host _ "/packages/" _ name _ "/" _ version _ "/installer"
}

Method versionsGet() As %ListOfDataTypes
{
  set tList = ##class(%ListOfDataTypes).%New()

  set name = ..name
  &sql(SELECT %DLIST(version) INTO :versions FROM Package WHERE name = :name)
  if (SQLCODE=0) {
    set ptr = 0
    while $LISTNEXT(versions, ptr, version) {
      continue:version=""
      set list(version) = ""
    }
  }

  set version = ""
  for {
    set version = $ORDER(list(version), 1)
    QUIT:version=""
    do tList.Insert(version)
  }
  return tList
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

ClassMethod DeleteExistingPackages(pkg, version) As %Status
{
  // delete all "proxy" packages
  &sql(DELETE FROM ZPM.Package WHERE Name = :pkg AND UpLink IS NOT NULL)
  Do ..NameVersionDelete(pkg, version)
  Return 1
}

ClassMethod versionValidate(pkg As %String = "", version As %String = "") As %String
{
  if (pkg="") {
    Return ""
  }
  if (version = "") || (version = "latest") || (version = "*") {
    &sql(SELECT TOP 1 Version INTO :version FROM ZPM.Package WHERE Name = :pkg 
          ORDER BY versionMajor DESC, versionMinor DESC, versionPatch DESC, versionPrerelease DESC, versionBuildmetadata DESC
    )
    If SQLCODE'=0 Return ""
    Return version
  }
  if ..%ExistsId(pkg _ "||" _ version) {
    Return version
  }
  Return ""
}

ClassMethod Populate(Path As %String, kill = 0)
{
  IF '##class(%File).DirectoryExists(Path) {
    RETURN
  }
  
  DO:kill ..%KillExtent()
  
  SET rs = ##class(%File).FileSetFunc(Path)
  WHILE rs.%Next() {
    SET name = rs.name
    CONTINUE:rs.Type'="D"
    
    SET tSC = ..LoadPackage(name)
    IF $$$ISERR(tSC) {
      DO $System.OBJ.DisplayError(tSC)
    }
  }
}

Method UpdateDescriptionFromManifest() As %Status
{
  Try {
    //save xml to file
    Set tFileName = $$$FileTempDir_"/manifest.xml"
    Set stream=##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(stream.LinkToFile(tFileName))
    $$$ThrowOnError(stream.CopyFrom(..manifest))
    $$$ThrowOnError(stream.%Save())
    Kill stream
    $$$ThrowOnError(##class(%XML.XPATH.Document).CreateFromFile(tFileName, .tDocument))
    $$$ThrowOnError(tDocument.EvaluateExpression("/Module/Description", "text()", .tRes))
    If (tRes.Count()>0) {
      Set ..description = tRes.GetAt(1).Value
    }
  } Catch ex {
    Do ex.Log()
    return ex.AsStatus()
  }
  return $$$OK
}

ClassMethod LoadPackage(Path As %String, repository As %String = "", silent As %Boolean = 0) As %Status
{
  SET tStream = ##class(%Stream.FileCharacter).%New()
  SET moduleFile = ##class(%File).NormalizeFilename("module.xml", Path)
  IF '##class(%File).Exists(moduleFile) {
    SET Path = ##class(%File).NormalizeDirectory("latest", Path)
    SET moduleFile = ##class(%File).NormalizeFilename("module.xml", Path)
  }
  If ('silent) {
    WRITE !!,"Path: ",Path
    WRITE !!,"ModuleFile: ",moduleFile
  }
  SET tSC = ##class(%XML.XPATH.Document).CreateFromFile(moduleFile, .tDocument)
  IF $$$ISERR(tSC) Return tSC

  SET tSC=tDocument.EvaluateExpression("/Export/Document/Module/Name", "text()", .tRes)
  IF $$$ISERR(tSC) Return tSC
  If '$IsObject(tRes.GetAt(1)) {
    Return $$$ERROR($$$GeneralError, "Name required")
  }
  SET name = tRes.GetAt(1).Value
  SET name = $$$lcase(name)
  If ('silent) {
    WRITE !,"Name: ", name
  }

  SET tSC=tDocument.EvaluateExpression("/Export/Document/Module/Version", "text()", .tRes)
  IF $$$ISERR(tSC) Return tSC
  If '$IsObject(tRes.GetAt(1)) {
    Return $$$ERROR($$$GeneralError, "Version required")
  }
  SET version = tRes.GetAt(1).Value
  If ('silent) {
    WRITE !,"Version: ", version
  }

  Set description = ""
  Set tSC=tDocument.EvaluateExpression("/Export/Document/Module/Description", "text()", .tRes)
  IF $$$ISERR(tSC) Return tSC
  If $IsObject(tRes.GetAt(1)) {
    Set description = tRes.GetAt(1).Value
  }

  SET archive = ##class(%Stream.FileBinary).%New()
  SET archiveFileName = ##class(%File).TempFilename("tgz")
  SET archive.Filename = archiveFileName

  SET command = "cd " _ Path _ " && tar -zcvf " _ archiveFileName _ " . "

  SET args = 0
  SET res = $zf(-100, "", "tar", "--exclude=.git", "-zcvf", archiveFileName, "-C",  Path, ".")
  If ('silent) {
    WRITE "ArchiveSize: " _ archive.Size
  }

  do ..DeleteExistingPackages(name,version)
  SET package = ..%New()
  SET package.name = name
  Set package.description = description
  Set package.repository = repository
  SET package.version = version
  SET package.package = archive
  set module = ##class(%Stream.FileCharacter).%New()
  set module.Filename = moduleFile
  Set package.manifest = module
  SET hash = $$$lcase(##class(%File).SHA1Hash(archiveFileName, 1))  
  SET package.hash = hash
  If ('silent) {
    WRITE !,"ArchiveHash: " _ hash
  }
  RETURN package.%Save()
}

ClassMethod GetPackageNameFromRepositoryURL(url As %String) As %String
{
  Return $PIECE(url, "/", *-1)
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
  return branch
}

ClassMethod DownloadPackageFromGitHub(url As %String, Output branch As %String) As %String
{
  Do ##class(%Net.URLParser).Parse(url, .tComponents)
  Set branch = ..GetDefaultBranch(tComponents("path"))
  Set ht = ##class(%Net.HttpRequest).%New()
  Set ht.Server = tComponents("host")
  If $get(tComponents("scheme"))="https" {
    Set ht.SSLConfiguration = ##class(ZPM.Utils).GetSSLConfiguration()
    Set ht.Https = 1
  }
  If $data(tComponents("port"), port), port'="" {
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
  Set res = $zf(-100, "", "tar", "-zxvf", archiveFileName, "-C", outputFolder)

  Return outputFolder
}

ClassMethod GetModuleMeta(url As %String) As %DynamicObject
{
  set jo = {"name":"", "version":""}
  Do ##class(%Net.URLParser).Parse(url, .tComponents)
  Set ht = ##class(%Net.HttpRequest).%New()
  Set ht.Server = "raw.githubusercontent.com"
  If $get(tComponents("scheme"))="https" {
    Set ht.SSLConfiguration = ##class(ZPM.Utils).GetSSLConfiguration()
    Set ht.Https = 1
  }
  If $data(tComponents("port"), port), port'="" {
    Set ht.Port = port
  }
  Set ht.Location = tComponents("path")_"master/module.xml"
  $$$ThrowOnError(ht.Get())
  If (ht.HttpResponse.StatusCode'=200) {
    $$$ThrowStatus($$$ERROR(5001,"Unable to download XML "_ht.Location))
  }
  Set tmpFolder = $$$FileTempDir

  Set stream=##class(%Stream.FileCharacter).%New()
  Do stream.LinkToFile(tmpFolder_"/module.xml")
  Set stream.TranslateTable = "UTF8"
  Do stream.CopyFrom(ht.HttpResponse.Data)
  Do stream.%Save()

  set binaryStream=##class(%Stream.FileBinary).%New()
  do binaryStream.LinkToFile(tmpFolder_"/module.xml")

  $$$ThrowOnError(##class(%XML.XPATH.Document).CreateFromStream(binaryStream, .xpathdoc))
  $$$ThrowOnError(xpathdoc.EvaluateExpression("/","Export/Document/Module/Version/text()", .tResults))
  set jo.version = tResults.GetAt(1).ValueGet()
  $$$ThrowOnError(xpathdoc.EvaluateExpression("/","Export/Document/Module/Name/text()", .tResults))
  set jo.name = $$$lcase(tResults.GetAt(1).ValueGet())

  Do ##class(%File).RemoveDirectoryTree(tmpFolder)
  
  return jo
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
    Set tName = meta.name
    Set id = ""
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
  IF Url="" {
    RETURN ""
  }
  If $e(Url, *)'="/" { 
    Set Url = Url _ "/"
  }
  Set name = ..GetPackageNameFromRepositoryURL(Url)
  Set branch = "master"
  Set outputFolder = ..DownloadPackageFromGitHub(Url, .branch)
  Set packageFolder = ##class(%File).NormalizeDirectory(name_"-"_branch, outputFolder)
  Set tSC = ..LoadPackage(packageFolder, Url)
  If $$$ISERR(tSC) { 
    Do $system.OBJ.DisplayError() 
  } else { 
    Write !,"Success" 
  }
  do ##class(%File).RemoveDirectoryTree(outputFolder)
}

ClassMethod GetTopVersion(pkg As %String) As %String
{
  Set version = ""
  &sql(SELECT TOP 1 version INTO :version FROM ZPM.Package 
        WHERE name = :pkg
        ORDER BY versionMajor DESC, versionMinor DESC, versionPatch DESC, versionPrerelease DESC, versionBuildmetadata DESC ) 
  Return version
}

/// returns latest versions of packages 
ClassMethod GetLatest(searchTerms As %DynamicArray = "", Output pStatus As %Status) As %DynamicArray
{
  Set pStatus = 1
  If ( '($CLASSNAME(searchTerms)="%Library.DynamicArray" ) || (searchTerms.%Size()=0) ) {
    // empty query
    Set searchCondition = " ( 1=1 ) "
  } Else {
    Set searchCondition = " ( "
    Set iter = searchTerms.%GetIterator()
    Set params = 0
    While iter.%GetNext(.key , .value ) {
      if (key=0) {
        Set searchCondition = searchCondition _ " ((name %MATCHES ?) OR (description %MATCHES ?) OR (keywords %MATCHES ?)) "
      } else {
        Set searchCondition = searchCondition _ " OR ((name %MATCHES ?) OR (description %MATCHES ?) OR (keywords %MATCHES ?))"
      }
      Set params(params+1) = value
      Set params(params+2) = value
      Set params(params+3) = value
      Set params = params + 3
    }
    Set searchCondition = searchCondition_ " ) "
  }
  Set sql = "SELECT name, repository, description "_
            "FROM ZPM.Package p1 "_
            "WHERE "_ searchCondition _
            "GROUP BY name "_
            "ORDER BY name"
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
      "description": (tResult.Description),
      "repository": (tResult.repository),
      "versions": [(..GetTopVersion(tResult.name))]
    }
    do tList.%Push(tPkgInfo)
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
