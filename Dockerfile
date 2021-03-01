#FROM store/intersystems/iris-community:2020.1.0.215.0
FROM intersystemsdc/iris-community:2020.4.0.524.0-zpm

USER root

COPY zpm-registry.yaml /usr/irissys/

WORKDIR /opt/zpm
RUN chown ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} .

USER irisowner

COPY  Installer.cls .
COPY  SQLPriv.xml .
COPY  src src
COPY irissession.sh /
SHELL ["/irissession.sh"]

RUN \
  do $SYSTEM.OBJ.Load("Installer.cls", "ck") \
  set sc = ##class(ZPM.Installer).setup()    \
  zn "registry"                              \
  zpm "install yaml-utils"

# bringing the standard shell back
SHELL ["/bin/bash", "-c"]


