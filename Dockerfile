FROM containers.intersystems.com/intersystems/iris-community:2022.2.0.270.0

WORKDIR /opt/registry

USER root

RUN chown irisowner:irisowner .

USER irisowner

COPY --chown=irisowner:irisowner . .

RUN  \
  VERSION=$(sed -n 's|.*<Version>\(.*\)</Version>.*|\1|p' module.xml | head -1) && \
  sed -i 's|^Parameter VERSION .*$|Parameter VERSION = "'"$VERSION"'";|g' \
    ./src/cls/ZPM/Registry.cls                                   && \
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
