FROM store/intersystems/iris-community:2019.4.0.383.0

USER root

WORKDIR /opt/zpm
RUN chown ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} .

USER irisowner

COPY  Installer.cls .
COPY  src src
COPY irissession.sh /
SHELL ["/irissession.sh"]

RUN \
  do $SYSTEM.OBJ.Load("Installer.cls", "ck") \
  set sc = ##class(ZPM.Installer).setup()

# bringing the standard shell back
SHELL ["/bin/bash", "-c"]