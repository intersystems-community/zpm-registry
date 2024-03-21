# intersystems zpm-registry
[![Quality Gate Status](https://community.objectscriptquality.com/api/project_badges/measure?project=intersystems_iris_community%2Fzpm-registry&metric=alert_status)](https://community.objectscriptquality.com/dashboard?id=intersystems_iris_community%2Fzpm-registry)

ZPM Registry is a a server part of ObjectScript Package Manager.

ZPM Registry hosts ZPM packages and publishes API to publish, list and deploy packages.

InterSystems Developers Community has the the public ZPM Registry - Commmunity Registry hosted on pm.community.intersystems.com and this code works there. Here is [the list of available packages](https://pm.community.intersystems.com/packages/-/all).
[ZPM Client](https://github.com/intersystems-community/zpm) by default installs packages from Community Registry.
You can use ZPM Registry project to build your own private registry to have the option to install packages with ZPM client from your private registry.

## Prerequisites
ZPM Registry works only on IRIS and IRIS For Health, community and Enterprise versions.

# Installation

## ZPM Installation
`install zpm-registry`

## Docker Installation
Build docker container

## Usual Installation
Import classes from cls and run Installer from Root

# Usage
ZPM Registry exposes REST API, which perfoms listing, publising and deployment services. You can examine the REST in the source class [Registry.cls](https://github.com/intersystems-community/zpm-registry/blob/master/src/cls/ZPM/Registry.cls) or via Swagger

Note, when you publish the repo via API you need to provide the Github URL of the repo, which will contain module.xml.
And published package will remember the repository and will not allow to publish/update package with the same name but with another repository.


## Working With Your Registry From ZPM Client
You can setup ZPM client to work with your registry with the following command:
```
zpm:USER>repo -n registry -r -url https://registry.yourdomain.com
```

## Settings
To configure the registry, utilize the zpm-registry.yaml file located within the IRIS installation folder. Retrieve the IRIS directory in which the file should reside using the following command: `write ##class(%SYSTEM.Util).InstallDirectory()`.


## Proxy-Registry
Starting from version 1.1.2, zpm-registry includes the Proxy feature.
This allows the IPM client to use only your private registry and install packages from your private registry, all the while retaining the capability to install packages from an external registry (Uplink).

External registries that your local registry can access are called Uplinks. You can define one or more external registries. You can also list which packages from the Uplink registry should be available.

These settings are set in the `zpm-registry.yaml` file.

Settings file example:
```
uplinks:
    pm:
        url: https://pm.community.intersystems.com/
        allow_packages: dsw,zpm*,?u*
```

For more information, see https://community.intersystems.com/post/new-zpm-registry-feature-%E2%80%93-proxy-registry


## Delete packages
Starting from version 0.7, IPM introduces support for the "unpublish" command, which facilitates the removal of a package that was previously published.
In order for this command to be executed, it is necessary to explicitly allow the removal of packages on the side of the registry. To do this, add the line "delete-enabled: true" to the settings file `zpm-registry.yaml`

Settings file example:
```
delete-enabled: true
```




