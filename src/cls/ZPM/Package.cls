Class ZPM.Package Extends (%Persistent, ZPM.JSON.Adaptor)
{

Parameter EXTENTQUERYSPEC = "name,version";

Property name As %String(MAXLEN = 50) [ Required ];

Index Name On name;

Property version As %String [ Required ];

Index NameVersion On (name, version) [ IdKey, Unique ];

Property owner As %String;

Index Owner On owner;

Property description As %String(MAXLEN = 200, TRUNCATE = 1);

Property keywords As list Of %String;

Property license As %String;

Property homePage As %String;

Property repository As %String(MAXLEN = 200);

Index Repository On repository;

Property dependencies As array Of %String;

Property package As %Stream.GlobalBinary(%JSONINCLUDE = "INPUTONLY") [ Required ];

Property size As %Integer(%JSONINCLUDE = "OUTPUTONLY");

Property manifest As %Stream.GlobalCharacter(%JSONINCLUDE = "INPUTONLY") [ Required ];

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
  SET host = ""
  IF $ISOBJECT($GET(%request)) {
    set tSecure = %request.Secure 
    SET host = %request.GetCgiEnv("HTTP_X_FORWARDED_HOST", %request.GetCgiEnv("SERVER_NAME"))
    set proto = %request.GetCgiEnv("HTTP_X_FORWARDED_PROTO", $SELECT(tSecure: "https", 1: "http"))
    SET port = %request.GetCgiEnv("HTTP_X_FORWARDED_PORT", %request.GetCgiEnv("SERVER_PORT"))
    SET host = proto _ "://" _ host
    IF '$LISTFIND($LISTBUILD(80, 443), port) {
      SET host = host_":"_port
    }    
  }
  RETURN host
}

Method urlGet() As %String
{
  SET host = ..ServerURL()
  SET name = $ZCONVERT(..name, "O", "URL")
  SET version = $ZCONVERT(..version, "O", "URL")
  RETURN host _ "/" _ name _ "/-/" _ name _ "-" _ version _ ".tgz"
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

  SET name = tRes.GetAt(1).Value
  SET name = $$$lcase(name)
  If ('silent) {
    WRITE !,"Name: ", name
  }

  SET tSC=tDocument.EvaluateExpression("/Export/Document/Module/Version", "text()", .tRes)
  IF $$$ISERR(tSC) Return tSC

  SET version = tRes.GetAt(1).Value
  If ('silent) {
    WRITE !,"Version: ", version
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

  do ..%DeleteId(name _ "||" _version)
  SET package = ..%New()
  SET package.name = name
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

ClassMethod DownloadPackageFromGitHub(url As %String) As %String
{
  SET url = url _ "archive/master.tar.gz"
  Do ##class(%Net.URLParser).Parse(url, .tComponents)
  Set ht = ##class(%Net.HttpRequest).%New()
  Set ht.Server = tComponents("host")
  If $get(tComponents("scheme"))="https" {
    Set ht.SSLConfiguration = ..GetSSLConfiguration(ht.Server)
    Set ht.Https = 1
  }
  If $data(tComponents("port"), port), port'="" {
    Set ht.Port = port
  }
  Set ht.Location = tComponents("path")

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
  Do ##class(%File).CreateDirectory(outputFolder)
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
    Set ht.SSLConfiguration = ..GetSSLConfiguration(ht.Server)
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
  Do ##class(%File).CreateDirectory(tmpFolder)

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
  set jo.name = tResults.GetAt(1).ValueGet()  

  Do ##class(%File).RemoveDirectoryTree(tmpFolder)
  
  return jo
}

ClassMethod UpdatePackage(jo As %DynamicObject) As %Status
{
  Set outputFolder = ""
  Try {
    Set url = jo.repository
    #; set url = $ZCONVERT(url, "L")
    If $Extract(url, *)'="/" {
      Set url = url _ "/"
    }
    Set name = ..GetPackageNameFromRepositoryURL(url) 
    Set meta = ..GetModuleMeta(url)
    If (meta.version = "") { $$$ThrowStatus($$$ERROR(5001, "Invalid package version")) }
    If (meta.name = "") { $$$ThrowStatus($$$ERROR(5001, "Package name is empty")) }
    If (..NameExists(meta.name, .id)) { 
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
      } else {
        Set sc = ..Publish(url, name)	
      }
    }
  } Catch ex {
    Set sc = ex.AsStatus() 
  }
  if (outputFolder'="") {
    do ##class(%File).RemoveDirectoryTree(outputFolder)
  }  
  return sc
}

ClassMethod Publish(url As %String, name As %String) As %Status
{
  Set outputFolder = ..DownloadPackageFromGitHub(url)
  Set packageFolder = ##class(%File).NormalizeDirectory(name _ "-master", outputFolder)
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
  Set outputFolder = ..DownloadPackageFromGitHub(Url)
  Set packageFolder = ##class(%File).NormalizeDirectory(name _ "-master", outputFolder)
  Set tSC = ..LoadPackage(packageFolder, Url)
  If $$$ISERR(tSC) { 
    Do $system.OBJ.DisplayError() 
  } else { 
    Write !,"Success" 
  }
  do ##class(%File).RemoveDirectoryTree(outputFolder)
}

ClassMethod GetSSLConfiguration(host) As %String
{
  NEW $NAMESPACE
  SET $NAMESPACE = "%SYS"
  
  IF '##class(Security.SSLConfigs).Exists(host) {
    DO ##class(Security.SSLConfigs).Create(host)
  }
  QUIT host
}

Query ListLatest(searchTerm As %String = "") As %SQLQuery(ROWSPEC = "name:%String,repository:%String,version:%String")
{
SELECT name, repository, (
  SELECT TOP 1 version FROM ZPM.Package p2 WHERE p1.name=p2.name 
  ORDER BY versionMajor DESC, versionMinor DESC, versionPatch DESC, versionPrerelease DESC, versionBuildmetadata DESC ) version
FROM ZPM.Package p1
WHERE :searchTerm IS NULL OR (
     name %MATCHES :searchTerm
  OR description %MATCHES :searchTerm
  OR keywords %MATCHES :searchTerm
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
