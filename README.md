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
## Usual Installation
Import classes from cls and run Installer from Root

## Docker Installation
Build docker container

## ZPM Installation
`install zpm-registry`

# Usage
ZPM Registry exposes REST API, which perfoms listing, publising and deployment services. You can examine the REST in the source class [Registry.cls](https://github.com/intersystems-community/zpm-registry/blob/master/src/cls/ZPM/Registry.cls) or via Swagger

Note, when you publish the repo via API you need to provide the GIthub URL of the repo, which will contain module.xml.
And published package will remember the repository and will not allow to publish/update package with the same name but with another repository.


## Working With Your Registry From ZPM Client
You can setup ZPM client to work with your registry with the following command:
```
ZPM:USER>repo -n registry -r -url https://registry.yourdomain.com
```




