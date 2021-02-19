#FROM store/intersystems/iris-community:2020.1.0.215.0
FROM intersystemsdc/iris-community:2020.4.0.524.0-zpm

USER root

WORKDIR /opt/zpm
RUN chown ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} .

USER irisowner

COPY  Installer.cls .
COPY  SQLPriv.xml .
COPY  src src

RUN                                                            \
  iris start ${ISC_PACKAGE_INSTANCENAME}                    && \
  /bin/echo -e ""                                              \
    " zn \"%SYS\""                                             \
    " do ##class(%SYSTEM.Process).CurrentDirectory(\"$PWD\")"  \
    " do ##class(%SYSTEM.OBJ).Load(\"Installer.cls\", \"ck\")" \
    " do ##class(ZPM.Installer).setup()"                       \
    " halt"                                                    \
  | iris session ${ISC_PACKAGE_INSTANCENAME} -U %SYS        && \
  iris stop ${ISC_PACKAGE_INSTANCENAME} quietly             && \
  rm -rf /usr/irissys/mgr/IRIS.WIJ                          && \
  rm -rf /usr/irissys/mgr/journal/*


