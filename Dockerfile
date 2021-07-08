#FROM store/intersystems/iris-community:2020.1.0.215.0
FROM intersystemsdc/iris-community:2020.4.0.524.0-zpm

USER root

COPY zpm-registry.yaml /usr/irissys/

WORKDIR /opt/zpm
RUN chown ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} .

USER irisowner

COPY --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} . .
COPY irissession.sh /
RUN VERSION=$(grep -oP '(?<=<Version>).*?(?=</Version>)' module.xml) && \
    sed -i "s/Parameter VERSION.*/Parameter VERSION = \"${VERSION}\";/" ./src/CLS/ZPM/Registry.cls
SHELL ["/irissession.sh"]

RUN \
  do $SYSTEM.OBJ.Load("Installer.cls", "ck") \
  set sc = ##class(ZPM.Installer).setup()    \
  zn "registry"                              \
  zpm "install yaml-utils"

# bringing the standard shell back
SHELL ["/bin/bash", "-c"]


