/// class to work with zpm-registry.yaml - file with settings
/// format of this file
/// 
/// uplinks:
///   pm:
///     url: https://pm.community.intersystems.com/
///     allow_packages: dsw,zpm*,?u*
/// delete-enabled: true
/// 
/// or use Namespace at first indent
/// 
/// USER:
///   delete-enabled: true
///   uplinks:
///     pm:
///       url: https://pm.community.intersystems.com/
///       allow_packages: dsw,zpm*,?u*
/// 
Class ZPM.Settings Extends %RegisteredObject
{

Parameter Filename = "zpm-registry.yaml";

Property Exists As %Boolean;

Property DateModified As %String;

Property JSON As %DynamicObject;

Method %OnNew() As %Status
{
    Set ..Exists = 0
    If ##class(%File).Exists(..GetFilename()) {
        Set ..Exists = 1
        Set file = ##class(%File).%New(..GetFilename())
        Set ..DateModified = file.DateModified
        Set ..JSON = ##class(YAML.Utils).FileToJSON(..GetFilename(), .sc)
        Return sc
    } Else {
        Kill ^zpmregistry
    }
    Return $$$OK
}

Method GetFilename() As %String [ CodeMode = expression ]
{
##class(%SYSTEM.Util).InstallDirectory()_..#Filename
}

Method IsModified() As %Boolean
{
    If ..Exists = 0 { 
        Return 0
    }
    If ($Get(^zpmregistry("filemodified")) = ..DateModified) {
        Return 0
    }
    Return 1
}

Method GetUplinks() As %DynamicObject
{
    Set ns = $$$lcase($NAMESPACE)
    If ('..Exists) {
        Return {}
    }
    Try {
        Set links = {}
        Set obj = ..JSON
        Set iter = obj.%GetIterator()
        While iter.%GetNext(.key , .fns) {
            If (ns = $$$lcase(key)) {
                // check found object structure
                If (..IsUplinkSettingsObject(fns)) {
                    Set links = fns."uplinks"
                    Quit
                }
            }
        }
        If (links.%Size()=0) {
            If (..IsUplinkSettingsObject(obj)) {
                Set links = obj."uplinks"
            }
        }
        Return links
    } Catch ex {
        Do ex.Log()
        Set sc = ex.AsStatus()  
    }
}

Method IsUplinkSettingsObject(obj As %DynamicObject) As %Boolean [ Private ]
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

Method GetDeleteEnable() As %Boolean
{
    Set ns = $$$lcase($NAMESPACE)
    If ('..Exists) {
        Return 0
    }
    If ( $Data(^zpmregistry(ns,"delete-enabled")) && '..IsModified() ) {
        Return $Get(^zpmregistry(ns,"delete-enabled"))
    }
    Try {
        Set obj = ..JSON
        Set delete = ""
        Set trueList = $ListBuild("y","Y","yes","Yes","YES","true","True","TRUE","on","On","ON","1")
        Set iter = obj.%GetIterator()
        While iter.%GetNext(.key , .fns) {
            If (ns = $$$lcase(key)) {
                Set delete = fns."delete-enabled"
                Quit
            }
        }
        If (delete = "") {
            Set delete = obj."delete-enabled"
        }
        If ($LISTFIND(trueList,delete)) {
            Set ^zpmregistry(ns,"delete-enabled") = 1
            Return 1
        } Else {
            Set ^zpmregistry(ns,"delete-enabled") = 0
        }

    } Catch ex {
        Do ex.Log()
        Set sc = ex.AsStatus()
    }
    Return 0
}

}
