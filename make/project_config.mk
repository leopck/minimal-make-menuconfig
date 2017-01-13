
#[Testing] For debugging purposes only
IDF_PATH=.
# Makefile support for the menuconfig system
####################################
# # Component directories. These directories are searched for components.
# # The project Makefile can override these component dirs, or define extra component directories.
# COMPONENT_DIRS ?= $(PROJECT_PATH)/components $(EXTRA_COMPONENT_DIRS) $(IDF_PATH)/components
# export COMPONENT_DIRS

# # Source directories of the project itself (a special, project-specific component.) Defaults to only "main".
# SRCDIRS ?= main

# # The project Makefile can define a list of components, but if it does not do this we just take
# # all available components in the component dirs.
# ifndef COMPONENTS
# # Find all component names. The component names are the same as the
# # directories they're in, so /bla/components/mycomponent/ -> mycomponent. We then use
# # COMPONENT_DIRS to build COMPONENT_PATHS with the full path to each component.
# $(info "[Debug Info] project_config.mk-17- COMPONENTS being initialized!")
# COMPONENTS := $(foreach dir,$(COMPONENT_DIRS),$(wildcard $(dir)/*))
# COMPONENTS := $(sort $(foreach comp,$(COMPONENTS),$(lastword $(subst /, ,$(comp)))))
# endif
# export COMPONENTS

# # Resolve all of COMPONENTS into absolute paths in COMPONENT_PATHS.
# #
# # If a component name exists in multiple COMPONENT_DIRS, we take the first match.
# #
# # NOTE: These paths must be generated WITHOUT a trailing / so we
# # can use $(notdir x) to get the component name.
# COMPONENT_PATHS := $(foreach comp,$(COMPONENTS),$(firstword $(foreach dir,$(COMPONENT_DIRS),$(wildcard $(dir)/$(comp)))))
# COMPONENT_PATHS += $(abspath $(SRCDIRS))

# # A component is buildable if it has a component.mk makefile in it
# COMPONENT_PATHS_BUILDABLE := $(foreach cp,$(COMPONENT_PATHS),$(if $(wildcard $(cp)/component.mk),$(cp)))

# # If TESTS_ALL set to 1, set TEST_COMPONENTS to all components
# ifeq ($(TESTS_ALL),1)
# TEST_COMPONENTS := $(COMPONENTS)
# endif

# # If TEST_COMPONENTS is set, create variables for building unit tests
# ifdef TEST_COMPONENTS
# override TEST_COMPONENTS := $(foreach comp,$(TEST_COMPONENTS),$(wildcard $(IDF_PATH)/components/$(comp)/test))
# TEST_COMPONENT_PATHS := $(TEST_COMPONENTS)
# TEST_COMPONENT_NAMES :=  $(foreach comp,$(TEST_COMPONENTS),$(lastword $(subst /, ,$(dir $(comp))))_test)
# endif

# # Initialise project-wide variables which can be added to by
# # each component.
# #
# # These variables are built up via the component_project_vars.mk
# # generated makefiles (one per component).
# #
# # See docs/build-system.rst for more details.
# COMPONENT_INCLUDES :=
# COMPONENT_LDFLAGS :=
# COMPONENT_SUBMODULES :=

# # COMPONENT_PROJECT_VARS is the list of component_project_vars.mk generated makefiles
# # for each component.
# #
# # Including $(COMPONENT_PROJECT_VARS) builds the COMPONENT_INCLUDES,
# # COMPONENT_LDFLAGS variables and also targets for any inter-component
# # dependencies.
# #
# # See the component_project_vars.mk target in component_wrapper.mk
# COMPONENT_PROJECT_VARS := $(addsuffix /component_project_vars.mk,$(notdir $(COMPONENT_PATHS_BUILDABLE) ) $(TEST_COMPONENT_NAMES))
# COMPONENT_PROJECT_VARS := $(addprefix $(BUILD_DIR_BASE)/,$(COMPONENT_PROJECT_VARS))
# # this line is -include instead of include to prevent a spurious error message on make 3.81
# -include $(COMPONENT_PROJECT_VARS)

# # Also add top-level project include path, for top-level includes
# COMPONENT_INCLUDES += $(abspath $(BUILD_DIR_BASE)/include/)

# export COMPONENT_INCLUDES

# ###################################

# Set variables common to both project & component
include $(IDF_PATH)/make/common.mk
# #Find all Kconfig files for all components
# COMPONENT_KCONFIGS := $(foreach component,$(COMPONENT_PATHS),$(wildcard $(component)/Kconfig))
# COMPONENT_KCONFIGS_PROJBUILD := $(foreach component,$(COMPONENT_PATHS),$(wildcard $(component)/Kconfig.projbuild))
# $(info "[Debug Info] project_config.mk-83- Printing component variable")
# $(info $(component))
# $(info "[Debug Info] project_config.mk-85- Printing component kconfig variable")
# $(info $(COMPONENT_KCONFIGS))

#For doing make menuconfig etc
KCONFIG_TOOL_DIR=./tools/kconfig

# set SDKCONFIG to the project's sdkconfig,
# unless it's overriden (happens for bootloader)
SDKCONFIG ?= ./sdkconfig

# SDKCONFIG_DEFAULTS is an optional file containing default
# overrides (usually used for esp-idf examples)
SDKCONFIG_DEFAULTS ?= ./sdkconfig.defaults

# reset MAKEFLAGS as the menuconfig makefile uses implicit compile rules
$(KCONFIG_TOOL_DIR)/mconf $(KCONFIG_TOOL_DIR)/conf:
	MAKEFLAGS=$(ORIGINAL_MAKEFLAGS) CC=$(HOSTCC) LD=$(HOSTLD) \
	$(MAKE) -C $(KCONFIG_TOOL_DIR)

# use a wrapper environment for where we run Kconfig tools
KCONFIG_TOOL_ENV=KCONFIG_AUTOHEADER=$(abspath $(BUILD_DIR_BASE)/include/sdkconfig.h) \
	COMPONENT_KCONFIGS="$(COMPONENT_KCONFIGS)" KCONFIG_CONFIG=$(SDKCONFIG) \
	COMPONENT_KCONFIGS_PROJBUILD="$(COMPONENT_KCONFIGS_PROJBUILD)"

menuconfig: $(KCONFIG_TOOL_DIR)/mconf ./Kconfig $(call prereq_if_explicit,defconfig)
	$(info "[Debug Info] Line 113: " + $(call prereq_if_explicit,defconfig))
	$(info "[Debug Info] Line 114: summary: "+$(summary))
	$(summary) MENUCONFIG
	$(KCONFIG_TOOL_ENV) $(KCONFIG_TOOL_DIR)/mconf ./Kconfig
	$(info "[Debug Info] project_config.mk-116-" + $(KCONFIG_TOOL_ENV) $(KCONFIG_TOOL_DIR)/mconf $(IDF_PATH)/Kconfig)

ifeq ("$(wildcard $(SDKCONFIG))","")
ifeq ("$(call prereq_if_explicit,defconfig)","")
# if not configuration is present and defconfig is not a target, run defconfig then menuconfig
$(SDKCONFIG): defconfig menuconfig
else
# otherwise, just defconfig
$(SDKCONFIG): defconfig
endif
endif

# defconfig creates a default config, based on SDKCONFIG_DEFAULTS if present
defconfig: $(KCONFIG_TOOL_DIR)/mconf $(IDF_PATH)/Kconfig $(BUILD_DIR_BASE)
	$(summary) DEFCONFIG
ifneq ("$(wildcard $(SDKCONFIG_DEFAULTS))","")
	cat $(SDKCONFIG_DEFAULTS) >> $(SDKCONFIG)  # append defaults to sdkconfig, will override existing values
endif
	mkdir -p $(BUILD_DIR_BASE)/include/config
	$(KCONFIG_TOOL_ENV) $(KCONFIG_TOOL_DIR)/conf --olddefconfig $(IDF_PATH)/Kconfig

# Work out of whether we have to build the Kconfig makefile
# (auto.conf), or if we're in a situation where we don't need it
NON_CONFIG_TARGETS := clean %-clean help menuconfig defconfig
AUTO_CONF_REGEN_TARGET := $(SDKCONFIG_MAKEFILE)

# disable AUTO_CONF_REGEN_TARGET if all targets are non-config targets
# (and not building default target)
ifneq ("$(MAKECMDGOALS)","")
ifeq ($(filter $(NON_CONFIG_TARGETS), $(MAKECMDGOALS)),$(MAKECMDGOALS))
AUTO_CONF_REGEN_TARGET :=
# dummy target
$(SDKCONFIG_MAKEFILE):
endif
endif

$(AUTO_CONF_REGEN_TARGET) $(BUILD_DIR_BASE)/include/sdkconfig.h: $(SDKCONFIG) $(KCONFIG_TOOL_DIR)/conf $(COMPONENT_KCONFIGS) $(COMPONENT_KCONFIGS_PROJBUILD)
	$(summary) GENCONFIG
	mkdir -p $(BUILD_DIR_BASE)/include/config
	cd $(BUILD_DIR_BASE); $(KCONFIG_TOOL_ENV) $(KCONFIG_TOOL_DIR)/conf --silentoldconfig $(IDF_PATH)/Kconfig
	touch $(AUTO_CONF_REGEN_TARGET) $(BUILD_DIR_BASE)/include/sdkconfig.h
# touch to ensure both output files are newer - as 'conf' can also update sdkconfig (a dependency). Without this,
# sometimes you can get an infinite make loop on Windows where sdkconfig always gets regenerated newer
# than the target(!)

.PHONY: config-clean
config-clean:
	$(summary RM CONFIG)
	$(MAKE) -C $(KCONFIG_TOOL_DIR) clean
	rm -rf $(BUILD_DIR_BASE)/include/config $(BUILD_DIR_BASE)/include/sdkconfig.h
