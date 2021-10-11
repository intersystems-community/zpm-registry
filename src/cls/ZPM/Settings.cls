Class ZPM.Settings Extends %ZPM.PackageManager.Developer.AbstractSettings
{

/// Username for use in basic authentication with GitHub (where relevant); optional if only public repositories are used.
Property BasicAuthUsername As %String(MAXLEN = 255);

/// Personal access token for use in basic / token authentication with GitHub (where relevant); optional if only public repositories are used.
Property BasicAuthAccessToken As %String(MAXLEN = "");

Storage Default
{
<Data name="SettingsDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>BasicAuthUsername</Value>
</Value>
<Value name="3">
<Value>BasicAuthPassword</Value>
</Value>
</Data>
<DataLocation>^ZPM.SettingsD</DataLocation>
<DefaultData>SettingsDefaultData</DefaultData>
<IdLocation>^ZPM.SettingsD</IdLocation>
<IndexLocation>^ZPM.SettingsI</IndexLocation>
<StreamLocation>^ZPM.SettingsS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
