Class ZPM.REST.Base Extends %CSP.REST [ System = 3 ]
{

Parameter CHARSET = "utf-8";

Parameter CONTENTTYPE = "application/json";

Parameter HandleCorsRequest = 1;

Parameter PAGESIZE As INTEGER = 20;

Parameter HTTP451LEGAL = "451 Unavailable For Legal Reasons";

ClassMethod OnPreDispatch(pUrl As %String, pMethod As %String, ByRef pContinue As %Boolean) As %Status
{
  Set tSC = $$$OK
  Try {
    // Set the return type according to the Accept type in the request. Default is application/json.
    If ('..AcceptsContentType(..#CONTENTTYPEJSON)) {
      Set tSC = ..ReportHttpStatusCode(..#HTTP406NOTACCEPTABLE)
      Set pContinue = 0
      Quit 
    } Else {   
      // This always returns json
      Set %response.ContentType=..#CONTENTTYPEJSON
    }
    
    If (##class(%Dictionary.CompiledClass).%ExistsId("ZPM.Analytics.IP")) {
      If ('##class(ZPM.Analytics.IP).ValidateIP(..GetRemoteAddr())) {
        Set tSC = ..ReportHttpStatusCode(..#HTTP451LEGAL)
        Set pContinue = 0
        Quit
      }
    }    
        
    // read request object into %DynamicObject format
    If ((pMethod'="POST") && (pMethod'="PUT")) || (%request.Content="") {
      Set %request.Content = {}
    } Else {
      If ($IsObject(%request.Content))&&('%request.Content.Size) {
        Set %request.Content = {}
      } Else {
        Set %request.Content = ##class(%Library.DynamicObject).%FromJSON(%request.Content)
      }
    } 
  } Catch ex {
    Set tSC = ex.AsStatus()
  }
  Quit ##class(%iKnow.REST.Base).%ErrorHandler(tSC, .pContinue)
}

ClassMethod %ProcessResult(pStatus As %Status = {$$$OK}, pResult As %DynamicObject = "") As %Status [ Internal ]
{
  #dim %response As %CSP.Response
  SET tSC = $$$OK
  IF $$$ISERR(pStatus) {
    SET %response.Status = 500
    SET tSC = ..StatusToJSON(pStatus, .tJSON)
    IF $isobject(tJSON) {
      SET pResult = tJSON
    } ELSE {
      SET pResult = { "errors": [ { "error": "Unknown error parsing status code" } ] }
    }
  } 
  ELSEIF pStatus=1 {
    IF '$isobject(pResult){
      SET pResult = {
      }
    }
  }
  ELSE {
    SET %response.Status = pStatus
    SET error = $PIECE(pStatus, " ", 2, *)
    SET pResult = {
      "error": (error)
    }
  }
  
  IF pResult.%Extends("%Library.DynamicAbstractObject") {
    WRITE pResult.%ToJSON()
  }
  ELSEIF pResult.%Extends("%JSON.Adaptor") {
    DO pResult.%JSONExport()
  }
  ELSEIF pResult.%Extends("%Stream.Object") {
    DO pResult.OutputToDevice()
  }
  
  QUIT tSC
}

ClassMethod ReportHttpStatusCode(pHttpStatus, pSC As %Status = {$$$OK}) As %Status
{
  Set %response.Status=pHttpStatus
  
  If $$$ISERR(pSC) Do ..outputStatus(pSC)
  /*
  If (+pHttpStatus>=400) {
    Set %response.ContentType = "application/json"
    SET pResult = {
      "error": ($PIECE(pHttpStatus, " ", 2, *))
    }
    Return ..%ProcessResult($$$OK, pResult)
  }*/
      
  Return $$$OK
}

ClassMethod SwaggerSpec() As %Status
{
  Set tSC = ##class(%REST.API).GetWebRESTApplication($NAMESPACE, %request.Application, .swagger)
  Do swagger.info.%Remove("x-ISC_Namespace")
  Set swagger.basePath = "/"
  Set swagger.info.title = "PackageManager Registry API"
  Set swagger.info.version = "0.1"
  Set swagger.host = "localhost:52773"
  Return ..%ProcessResult($$$OK, swagger)
}

ClassMethod GetRemoteAddr() As %String
{
  Set ip = $Piece(%request.GetCgiEnv("HTTP_X_FORWARDED_FOR"),",",1)
  If (ip'="") {
    Return ip
  } Else {
    Return %request.GetCgiEnv("REMOTE_ADDR")
  } 
  Return ""
}

}
