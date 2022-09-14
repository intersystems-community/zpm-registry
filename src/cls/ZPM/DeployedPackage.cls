Class ZPM.DeployedPackage Extends (%Persistent, ZPM.Package)
{

Property platformVersion As %String(%JSONFIELDNAME = "platform_version");

Index NameVersionPlatform On (name, version, platformVersion) [ IdKey, Unique ];

Method filepathGet() As %String [ CodeMode = expression ]
{
..name _ "/" _ ..platformVersion
}

Property platformVersions As list Of %String(%JSONINCLUDE = "NONE") [ Transient ];

Storage Default
{
<Data name="DeployedPackageDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>package</Value>
</Value>
<Value name="3">
<Value>size</Value>
</Value>
<Value name="4">
<Value>manifest</Value>
</Value>
<Value name="5">
<Value>hash</Value>
</Value>
<Value name="6">
<Value>owner</Value>
</Value>
<Value name="7">
<Value>description</Value>
</Value>
<Value name="8">
<Value>keywords</Value>
</Value>
<Value name="9">
<Value>license</Value>
</Value>
<Value name="10">
<Value>homePage</Value>
</Value>
<Value name="11">
<Value>repository</Value>
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
<Value>versionPrerelease</Value>
</Value>
<Value name="17">
<Value>versionBuildmetadata</Value>
</Value>
<Value name="18">
<Value>publishTS</Value>
</Value>
<Value name="19">
<Value>UpLink</Value>
</Value>
<Value name="20">
<Value>deployed</Value>
</Value>
</Data>
<Data name="dependencies">
<Attribute>dependencies</Attribute>
<Structure>subnode</Structure>
<Subscript>"dependencies"</Subscript>
</Data>
<DataLocation>^ZPM.DeployedPackageD</DataLocation>
<DefaultData>DeployedPackageDefaultData</DefaultData>
<IdLocation>^ZPM.DeployedPackageD</IdLocation>
<IndexLocation>^ZPM.DeployedPackageI</IndexLocation>
<StreamLocation>^ZPM.DeployedPackageS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
