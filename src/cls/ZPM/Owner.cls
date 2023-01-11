Class ZPM.Owner
{

/// Check if user is not UnknownUser
ClassMethod IsAuth() As %Status
{
    If ($Username="UnknownUser") {
        Return $$$ERROR($$$GeneralError, "Authentification required")
    } 
    Return $$$OK
}

ClassMethod IsOwner(packageName As %String) As %Status
{
    Set owner = ""
    &sql(SELECT TOP 1 owner INTO :owner FROM ZPM.Package WHERE name = :packageName ORDER BY publishTS)
    If ( (owner'="") && (owner '= $Username) ){
        Return $$$ERROR($$$GeneralError, "Invalid package owner")
    }
    Return $$$OK
}

ClassMethod SaveOwner(packageName, packageVersion) As %Status
{
    Set owner = $Username
    Set package = ##class(ZPM.Package).NameVersionOpen(packageName, packageVersion)
    Set package.owner = owner
    Return package.%Save()
}

}
