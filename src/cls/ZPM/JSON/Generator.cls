Class ZPM.JSON.Generator Extends %JSON.Generator [ System = 2 ]
{

/// Generate code for getting the field value from a binary stream and storing in variable named data.
ClassMethod GenImportBinaryStream(class As %String, propertyMap As %List, indent As %String, isCollectionValue As %Integer) [ Internal ]
{
	Set property=$$$jsonproperty(propertyMap)
	
	// If present, then must be the expected JSON type
	$$$GENERATE(indent_"  If jsontype'=""string"" Goto %JSONImportError")
	// Get the field value
	If isCollectionValue {
		// Code for new stream to insert
		Set indexarg=$select(isCollectionValue=$$$isCollectionList:"index+1",1:"index")
		$$$GENERATE(indent_"  Set stream=..##class("_$$$jsontype(propertyMap)_").%New()")
		If $$$jsonliteraltype(propertyMap)["hex" {
			$$$GENERATE(indent_"  For i=1:2:$length(value) {")
			$$$GENERATE(indent_"    Set bin=bin_$char($zhex($extract(value,i,i+1)))")
			$$$GENERATE(indent_"  }")
			$$$GENERATE(indent_"  Set sc=stream.Write(value) If $$$ISERR(sc) Goto %JSONImportExit")
		} Else {
			$$$GENERATE(indent_"  Set sc=stream.Write($system.Encryption.Base64Decode(value)) If $$$ISERR(sc) Goto %JSONImportExit")
		}
		If isCollectionValue=$$$isCollectionList {
			// Generate code to save value in list
			$$$GENERATE(indent_"  Do .."_$$$jsonpropertyQN(propertyMap)_".Insert(stream)")
		} Else {
			// Generate code to save value in array
			$$$GENERATE(indent_"  Do .."_$$$jsonpropertyQN(propertyMap)_".SetAt(stream,index)")
		}
	} Else {
		// Code to use property stream
    $$$GENERATE(indent_"  Set tStream = %JSONObject.%Get("""_$$$jsonfieldname(propertyMap)_""",,""stream"")")
		$$$GENERATE(indent_"  Set stream=.."_$$$jsonpropertyQN(propertyMap)_" Do stream.Rewind()")
    $$$GENERATE(indent_"  If tStream.Size>0 { While 'tStream.AtEnd {")
		If $$$jsonliteraltype(propertyMap)["hex" {
			$$$GENERATE(indent_"  Set value=tStream.Read(32000),bin=""""")
			$$$GENERATE(indent_"  For i=1:2:$length(value) {")
			$$$GENERATE(indent_"    Set bin=bin_$char($zhex($extract(value,i,i+1)))")
			$$$GENERATE(indent_"  }")
			$$$GENERATE(indent_"  Set sc=stream.Write(bin) If $$$ISERR(sc) Goto %JSONImportExit")
		} Else {
			$$$GENERATE(indent_"    do stream.Write($system.Encryption.Base64Decode(tStream.Read(43540,.sc))) If $$$ISERR(sc) Goto %JSONImportExit")
		}
    $$$GENERATE(indent_"  }}")
    $$$GENERATE(indent_"  Set %JSONObject."_$$$QN($$$jsonfieldname(propertyMap))_" = """"")
    $$$GENERATE(indent_"  Do %JSONObject.%Remove("""_$$$jsonfieldname(propertyMap)_""")")
	}
}

/// Generate code for exporting a binary stream as JSON.
ClassMethod GenExportBinaryStream(class As %String, propertyMap As %List, fieldName As %String, indent As %String, isCollectionValue As %Integer) [ Internal ]
{
	Do ..GenWriteField(fieldName,indent,"")
	If $$$jsonliteraltype(propertyMap)["hex" {
		$$$GENERATE(indent_"  "_%outputCode_""""""""" Do value.Rewind() If value.Size>0 { While 'value.AtEnd { ")
		$$$GENERATE(indent_"    Set first=value.Read(.len,.sc) If $$$ISERR(sc) Goto "_%exitCode)
    	$$$GENERATE(indent_"    For k=1:1:$length(first) {"_%outputCode_"$select($ascii(first,k)<16:""0"",1:"""")_$zhex($ascii(first,k)) }")
		$$$GENERATE(indent_"  }} "_%outputCode_"""""""""")
	} Else {
		$$$GENERATE(indent_"  "_%outputCode_""""""""" Do value.Rewind() If value.Size>0 { While 'value.AtEnd { "_%outputCode_"$system.Encryption.Base64Encode(value.Read(32655,.sc),1) If $$$ISERR(sc) Goto "_%exitCode_" }} "_%outputCode_"""""""""")
	}
}

}
