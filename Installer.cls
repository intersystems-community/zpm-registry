Class ZPM.Installer
{

XData setup
{
<Manifest>
  <Default Name="APPPATH" Dir="#{$system.Process.CurrentDirectory()}" />
  <Default Name="SourceDir" Value="${APPPATH}src"/>
  <Default Name="NAMESPACE" Value="REGISTRY"/>
  <Default Name="DBNAME" Value="REGISTRY"/>
  <Default Name="CSPAPP" Value="/registry" />
  <Default Name="CSPAPPDIR" Dir="${APPPATH}csp" />
  <Default Name="RESOURCE" Value="%DB_${DBNAME}" /> 

  <Namespace Name="${NAMESPACE}" Code="${DBNAME}-CODE" Data="${DBNAME}-DATA" Create="yes" Ensemble="0">
    <Configuration>
      <Database Name="${DBNAME}-CODE" Dir="${APPPATH}${DBNAME}-CODE" Create="yes" Resource="${RESOURCE}"/>
      <Database Name="${DBNAME}-DATA" Dir="${APPPATH}${DBNAME}-DATA" Create="yes" Resource="${RESOURCE}"/>
    </Configuration>

    <Import File="${SourceDir}" Flags="ck" Recurse="1"/>
    
    <CSPApplication Url="${CSPAPP}"
      Directory="${CSPAPPDIR}"
      Grant="${RESOURCE},%SQL"
      AuthenticationMethods="96"
      Recurse="1" />
      
  </Namespace>
  <Invoke Class="ZPM.Installer" Method="SetDispatchClass">
    <Arg Value="${CSPAPP}"/>
    <Arg Value="ZPM.Registry"/>
  </Invoke>

  <Invoke Class="ZPM.Installer" Method="AddSSLConfiguration"></Invoke>

  <Invoke Class="Security.SQLPrivileges" Method="Import" CheckStatus="true">
    <Arg Value="${APPPATH}SQLPriv.xml"/>
  </Invoke>

</Manifest>
}

ClassMethod AddSSLConfiguration()
{
    Set host = "zpmregistry"
    New $NAMESPACE
    Set $NAMESPACE = "%SYS"
    If '##class(Security.SSLConfigs).Exists(host) {
        Do ##class(Security.SSLConfigs).Create(host)
    }
    Return host
}

ClassMethod setup(ByRef pVars, pLogLevel As %Integer = 3, pInstaller As %Installer.Installer, pLogger As %Installer.AbstractLogger) As %Status [ CodeMode = objectgenerator, Internal ]
{
  #; Let XGL document generate code for this method. 
  Quit ##class(%Installer.Manifest).%Generate(%compiledclass, %code, "setup")
}

ClassMethod SetDispatchClass(pApp As %String, pClass As %String) As %Status
{
  New $Namespace
  Set $Namespace = "%SYS"
  Set tSC = ##class(Security.Applications).Get(pApp, .webProperties)
  If $$$ISERR(tSC) {
    Quit tSC
  }
  
  Set webProperties("DispatchClass") = pClass
  Set tSC = ##class(Security.Applications).Modify(pApp, .webProperties)
  Quit tSC
}

}
