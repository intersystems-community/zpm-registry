FROM containers.intersystems.com/intersystems/iris-community:2022.1.0.152.0

USER root

WORKDIR /opt/zpm
RUN chown ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} .

USER irisowner

COPY  Installer.cls SQLPriv.xml ./
COPY  src src
COPY zpm-registry.yaml /usr/irissys/

RUN                                                                 \
  iris start ${ISC_PACKAGE_INSTANCENAME}                         && \
  /bin/echo -e ""                                                   \
    " zn \"%SYS\""                                                  \
    " do ##class(%SYSTEM.Process).CurrentDirectory(\"$PWD\")"       \
    " do ##class(%SYSTEM.OBJ).Load(\"Installer.cls\", \"ck\")"      \
    " set sc = ##class(ZPM.Installer).setup() "                     \
    " if '\$Get(sc) { do ##class(%SYSTEM.Process).Terminate(, 1) }" \
    " halt"                                                         \
  | iris session ${ISC_PACKAGE_INSTANCENAME} -U %SYS             && \
  tail /usr/irissys/mgr/messages.log && \
  iris stop ${ISC_PACKAGE_INSTANCENAME} quietly                  && \
  rm -rf /usr/irissys/mgr/IRIS.WIJ                               && \
  rm -rf /usr/irissys/mgr/journal/*
