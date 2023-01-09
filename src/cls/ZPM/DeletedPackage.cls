Class ZPM.DeletedPackage Extends %Persistent
{

Property name As %String(MAXLEN = 50) [ Required ];

Property version As %String [ Required ];

Index NameVersion On (name, version) [ IdKey, Unique ];

Storage Default
{
<Data name="DeletedPackageDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
</Data>
<DataLocation>^ZPM.DeletedPackageD</DataLocation>
<DefaultData>DeletedPackageDefaultData</DefaultData>
<IdLocation>^ZPM.DeletedPackageD</IdLocation>
<IndexLocation>^ZPM.DeletedPackageI</IndexLocation>
<StreamLocation>^ZPM.DeletedPackageS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
