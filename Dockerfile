FROM store/intersystems/iris-community:2020.1.0.215.0

USER root

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
  set sc = ##class(ZPM.Installer).setup()

# bringing the standard shell back
SHELL ["/bin/bash", "-c"]