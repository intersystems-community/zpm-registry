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

Property repository As %String;

Property dependencies As array Of %String;

Property package As %Stream.GlobalBinary(%JSONINCLUDE = "INPUTONLY") [ Required ];

Property size As %Integer(%JSONINCLUDE = "OUTPUTONLY");

Property manifest As %Stream.GlobalCharacter(%JSONINCLUDE = "INPUTONLY") [ Required ];

Property installer As %Stream.GlobalCharacter(%JSONINCLUDE = "INPUTONLY");

Property hash As %String(%JSONINCLUDE = "OUTPUTONLY") [ SqlComputeCode = { set {*} = ..GetPackageHash({package})}, SqlComputed, SqlComputeOnChange = package ];

Property url As %String(%JSONINCLUDE = "OUTPUTONLY", MAXLEN = 200) [ Transient ];

Property installerUrl As %String(%JSONFIELDNAME = "installer", %JSONINCLUDE = "OUTPUTONLY", MAXLEN = 200) [ Transient ];

Property versions As list Of %String(%JSONINCLUDE = "OUTPUTONLY", MAXLEN = 200) [ Transient ];

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
    &sql(SELECT TOP 1 Version INTO :version FROM ZPM.Package WHERE Name = :pkg ORDER BY ID DESC)
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

ClassMethod LoadPackage(Path As %String) As %Status
{
  SET tStream = ##class(%Stream.FileCharacter).%New()
  SET moduleFile = ##class(%File).NormalizeFilename("module.xml", Path)
  IF '##class(%File).Exists(moduleFile) {
    SET Path = ##class(%File).NormalizeDirectory("latest", Path)
    SET moduleFile = ##class(%File).NormalizeFilename("module.xml", Path)
  }

  WRITE !!,"Path: ",Path
  WRITE !!,"ModuleFile: ",moduleFile
  SET tSC = ##class(%XML.XPATH.Document).CreateFromFile(moduleFile, .tDocument)
  IF $$$ISERR(tSC) Return tSC

  SET tSC=tDocument.EvaluateExpression("/Export/Document/Module/Name", "text()", .tRes)
  IF $$$ISERR(tSC) Return tSC

  SET name = tRes.GetAt(1).Value
  SET name = $$$lcase(name)
  WRITE !,"Name: ", name

  SET tSC=tDocument.EvaluateExpression("/Export/Document/Module/Version", "text()", .tRes)
  IF $$$ISERR(tSC) Return tSC

  SET version = tRes.GetAt(1).Value
  WRITE !,"Version: ", version

  SET archive = ##class(%Stream.FileBinary).%New()
  SET archiveFileName = ##class(%File).TempFilename("tgz")
  SET archive.Filename = archiveFileName

  SET command = "cd " _ Path _ " && tar -zcvf " _ archiveFileName _ " . "

  SET args = 0
  SET res = $zf(-100, "", "tar", "--exclude=.git", "-zcvf", archiveFileName, "-C",  Path, ".")
  WRITE "ArchiveSize: " _ archive.Size
  
  do ..%DeleteId(name _ "||" _version)
  SET package = ..%New()
  SET package.name = name
  SET package.version = version
  SET package.package = archive
  set module = ##class(%Stream.FileCharacter).%New()
  set module.Filename = moduleFile
  Set package.manifest = module
  SET hash = $$$lcase(##class(%File).SHA1Hash(archiveFileName, 1))  
  SET package.hash = hash
  WRITE !,"ArchiveHash: " _ hash

  RETURN package.%Save()
}

ClassMethod LoadFromGitHub(Url = "")
{
  IF Url="" {
    RETURN ""
  }

  IF $e(Url, *)'="/" set Url = Url _ "/"
  Set name = $PIECE(Url, "/", *-1)
  SET Url = Url _ "archive/master.tar.gz"
  DO ##class(%Net.URLParser).Parse(Url, .tComponents)

  SET ht = ##class(%Net.HttpRequest).%New()
  SET ht.Server = tComponents("host")
  IF $get(tComponents("scheme"))="https" {
    SET ht.SSLConfiguration = ..GetSSLConfiguration(ht.Server)
    SET ht.Https = 1
  }
  IF $data(tComponents("port"), port), port'="" {
    SET ht.Port = port
  }

  SET ht.Location = tComponents("path")

  SET tSC = ht.Get()
  IF $$$ISERR(tSC) do $SYSTEM.OBJ.DisplayError(tSC) QUIT

  IF ht.HttpResponse.StatusCode'=200 QUIT

  #dim response As %Net.HttpResponse
  SET fs = ##class(%Stream.FileBinary).%New()
  set archiveFileName = ##class(%File).TempFilename("tgz")
  SET fs.Filename = archiveFileName

  DO fs.CopyFromAndSave(ht.HttpResponse.Data)

  set outputFolder = $$$FileTempDir
  do ##class(%File).CreateDirectory(outputFolder)
  set res = $zf(-100, "", "tar", "-zxvf", archiveFileName, "-C", outputFolder)

  set packageFolder = ##class(%File).NormalizeDirectory(name _ "-master", outputFolder)
  set tSC = ..LoadPackage(packageFolder)
  if $$$ISERR(tSC) { do $system.OBJ.DisplayError() }
  else { write !,"Success" }
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

Query ListLatest(searchTerm As %String = "") As %SQLQuery(ROWSPEC = "name:%String,version:%String")
{
SELECT name, (
  SELECT TOP 1 version FROM ZPM.Package p2 WHERE p1.name=p2.name ORDER BY ID DESC ) version
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
