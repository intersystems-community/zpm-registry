Class ZPM.Utils
{

Parameter SSLCONFIGNAME = "zpmregistry";

ClassMethod ServerURL() As %String
{
  Set host = ""
  If '$ISOBJECT($Get(%request)) {
    Quit ""
  }
  Set tSecure = %request.Secure 
  Set host = %request.GetCgiEnv("HTTP_X_FORWARDED_HOST", %request.GetCgiEnv("SERVER_NAME"))
  Set proto = %request.GetCgiEnv("HTTP_X_FORWARDED_PROTO", $SELECT(tSecure: "https", 1: "http"))
  Set port = %request.GetCgiEnv("HTTP_X_FORWARDED_PORT", %request.GetCgiEnv("SERVER_PORT"))
  Set host = proto _ "://" _ host
  If '$LISTFIND($LISTBUILD(80, 443), port) {
    Set host = host_":"_port
  }
  If (%request.GetCgiEnv("HTTP_X_ORIGINAL_URI")'="") {
    Set path = $REPLACE(%request.URL, %request.Application,"",1,1)
    Set urlpart = $EXTRACT(%request.GetCgiEnv("HTTP_X_ORIGINAL_URI"),1,$FIND(%request.GetCgiEnv("HTTP_X_ORIGINAL_URI"), path) - $Length(path)-1)
    Set host = host _ $p(urlpart, "/" ,1,*-1)
  } Else {
    #; If not behind the proxy where it have to be hidden redirect from / to /registry
    If %request.GetCgiEnv("HTTP_X_FORWARDED_HOST")="" {
      Set host = host _ $p(%request.Application, "/" ,1,*-1)
    }
  }
  Return host
}

/// Reads from pStream
/// values of elements specified in xPathArray (Array)
/// returns values in xPathArray values
/// 
/// example 
///    set xPathArray("root/element")=""
///    set xPathArray("root/element2")=""
///    set tSC = ##class(ZPM.Utils).ReadXMLElements(stream, .xPathArray)
/// returns in xPathArray
///    xPathArray("root/element")=""
///    xPathArray("root/element", "text")="value"
///    xPathArray("root/elemen2t")=""
///    xPathArray("root/element2", "text")="value2"
ClassMethod ReadXMLElements(pStream As %Stream.Object, xPathArray) As %Status
{
    Try {
        Set tmpFolder = $$$FileTempDir
        Set tmpFilename = tmpFolder_"/file.xml"

        Set stream=##class(%Stream.FileCharacter).%New()
        Do stream.LinkToFile(tmpFilename)
        Set stream.TranslateTable = "UTF8"
        Do stream.CopyFrom(pStream)
        Do stream.%Save()

        Set binaryStream=##class(%Stream.FileBinary).%New()
        Do binaryStream.LinkToFile(tmpFilename)

        $$$ThrowOnError(##class(%XML.XPATH.Document).CreateFromStream(binaryStream, .xpathdoc))

        Set key = ""
        For {
            Set key = $ORDER(xPathArray(key))
            Quit:(key="")
            $$$ThrowOnError(xpathdoc.EvaluateExpression("/",key_"/text()", .tResults))
            If (tResults.Count()=0) {
                $$$ThrowOnError(xpathdoc.EvaluateExpression("/","Export/Document/"_key_"/text()", .tResults))
            }
            If (tResults.Count()>0) {
                For i=1:1:tResults.Count(){
                    Set xPathArray(key,"text") = $Get(xPathArray(key,"text"))_tResults.GetAt(1).ValueGet()
                }
            } 
        } 
        Do ##class(%File).RemoveDirectoryTree(tmpFolder)
        Return $$$OK
    } Catch ex {
        Return ex.AsStatus() 
    }
}

ClassMethod GetSSLConfiguration() As %String
{
    Set host = ..#SSLCONFIGNAME
    Return host
    Return ""
}

ClassMethod SQLsetup() As %Status
{
    Set tables = $LB("ZPM.Package","ZPM.Package_dependencies","ZPM.UpLink")
    New $NAMESPACE
    Set ns = $NAMESPACE

    Set $NAMESPACE = "%SYS"

    For i=1:1:$LISTLENGTH(tables) {
        Set sp = ##class(Security.SQLPrivileges).%New()
        Set sp.Grantable = 0
        Set sp.Grantee = "_PUBLIC"
        Set sp.Grantor = "_SYSTEM"
        Set sp.Namespace = ns
        Set sp.Privilege = "s"
        Set sp.SQLObject = "1,"_$LISTGET(tables,i)
        Do sp.%Save()
    }
    Return $$$OK
}

ClassMethod AddSSLConfiguration() As %Status
{
    Set host = ..#SSLCONFIGNAME
    New $NAMESPACE
    Set $NAMESPACE = "%SYS"
    If '##class(Security.SSLConfigs).Exists(host) {
        Do ##class(Security.SSLConfigs).Create(host)
    }
    Return host
}

}
