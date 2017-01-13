# minimal-make-menuconfig

This is still in development phase, the template is still not minimal yet. Do not expect it to work.

# Workflow

## Kconfig (top-level)(root folder) 

- the home page or the main page of the menuconfig

## Makefile (top-level)(root folder)

- scans every component folder to find for Makefiles and scans user folder to find Makefiles to build the whole program based on the given configurations given by sdkconfig(auto generated by menuconfig)

## Kconfig (component folder)

- in each component folder, it'll contain a Kconfig that provides the menu interface or settings for each component

## Makefile (component folder)

- in each component folder it'll contain a Makefile that informs/instructs how to build the component

## make folder

- make folder contains common.mk and project_config.mk, both of which is needed to build the kconfig, menuconfig and other makefiles

## tools folder

- tools folder contains all the basic libraries needed to run menuconfig like lxdialog. Do not touch this as this is needed to run menuconfig

## sdkconfig (auto generated by menuconfig DO NOT TOUCH!)

- An auto generated configuration file from menuconfig. It contains all the configurations that you selected after performing 'make menuconfig'. These configurations are used by the Makefile that parses thru the sdkconfig to use these to select the needed components.

## User application (main.c)

- Might change into user folder. Tentatively main.c for testing purposes only 
