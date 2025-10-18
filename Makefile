# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
#
# Makefile
#
# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
ifndef BASE_MK
BASE_MK := 1

define BASE_USAGE
Available targets:
  <SERVICE>-<TASK>      - run '_' oci (i.e. runs podman-compose <SERVICE> make _<SERVICE>-<TASK>)
  ~<TASK>               - run ~<TASK> on host (make ~<TASK>)
  data/<SERVICE>/<TASK> - run oci file target (podman-compose <SERVICE> make data/<SERVICE>)
  data/base/<TASK>      - run host file target (make data/base/<TASK>)
endef # BASE_USAGE

PROJECT_NAME := base

SHELL             := /bin/bash
.ONESHELL:

ENV_FILE          := .env
BASE_RUN_ID       := $(shell date '+%s')
INSIDE_OCI        := $(shell grep -q -x '0::/' /proc/self/cgroup && echo 1 || echo 0)

SPACE             := $(eval) #
TILDE             := $(eval)~#

BASE_DEBUG        ?= false
BASE_DEBUG_CMD     = :
ifeq ($(BASE_DEBUG),true)
  BASE_DEBUG_CMD   = echo "INFO: TARGET=$@"; set -x
endif

OCI               := podman
OCI_COMPOSE       := $(OCI)-compose
OCI_RUN_ARGS      ?= --rm
OCI_MAKE_CMD      := make
OCI_MAKE_ARGS     ?=

define TARGET_INIT_FN
# host targets: ~service-task(-args)
ifneq (,$(findstring ~,$(1)))
	TARGET_RAW        := $(1)
	TARGET_TYPE       := host
	SERVICE           := $(word 1,$(subst -, ,$(patsubst ~%,%,$(1))))
	SERVICE_TASK      := $(word 2,$(subst -, ,$(patsubst ~%,%,$(1))))
	SERVICE_TASK_ARGS := $(patsubst ~$(word 1,$(subst -, ,$(patsubst ~%,%,$(1))))-$(word 2,$(subst -, ,$(patsubst ~%,%,$(1))))-%,%,$(1))

# data file targets: data/service/task(-args)
else ifneq (,$(findstring data/,$(1)))
	TARGET_RAW        := $(1)
	TARGET_TYPE       := data
	SERVICE           := $(word 2,$(subst /, ,$(1)))
	SERVICE_TASK      := $(word 1,$(subst -, ,$(word 3,$(subst /, ,$(1)))))
	SERVICE_TASK_ARGS := $(patsubst data/$(word 2,$(subst /, ,$(1)))/$(word 1,$(subst -, ,$(word 3,$(subst /, ,$(1)))))-%,%,$(1))

# OCI targets: _service-task(-args)
else ifneq (,$(findstring _,$(1)))
	TARGET_RAW        := $(1)
	TARGET_TYPE       := host
	SERVICE           := $(word 1,$(subst -, ,$(patsubst _%,%,$(1))))
	SERVICE_TASK      := $(word 2,$(subst -, ,$(patsubst _%,%,$(1))))
	SERVICE_TASK_ARGS := $(patsubst _$(SERVICE)-$(SERVICE_TASK)-%,%,$(1))

# OCI phony targets: service-task(-args)
else
	TARGET_RAW        := $$$$(1)
	TARGET_TYPE       := oci
	SERVICE           := $$(word 1,$$(subst -, ,$$(patsubst _%,%,$$(1))))
	SERVICE_ARGS      := $$$$(subst $$(SERVICE)-,,$$$$@)
	SERVICE_TASK      := $$$$(word 2,$$$$(subst -, ,$$$$@))
	SERVICE_TASK_ARGS := $$$$(subst $$(SERVICE_TASK)-,,$$$$(subst $$(SERVICE)-,,$$$$@))

endif

endef # TARGET_INIT_FN

define OCI_RUN_ENV_VARS
	  --podman-run-args="--env-file=$(ENV_FILE)" \
	  --podman-run-args="--env=BASE_DEBUG=$(BASE_DEBUG)" \
	  --podman-run-args="--env=BASE_RUN_ID=$(BASE_RUN_ID)" \
	  --podman-run-args="--env=SERVICE=$(SERVICE)" \
	  --podman-run-args="--env=SERVICE_ARGS=$(SERVICE_ARGS)" \
	  --podman-run-args="--env=SERVICE_TASK=$(SERVICE_TASK)" \
	  --podman-run-args="--env=SERVICE_TASK_ARGS=$(SERVICE_TASK_ARGS)"
endef

OCI_SERVICES      := devops tf pandoc quarto megalinter powershell
SERVICE_MAKEFILES := $(foreach s,$(OCI_SERVICES),makefiles/$(s).mk)

-include $(SERVICE_MAKEFILES)
#
# INSIDE_OCI & __INTROSPECTION_MODE__
#
ifneq ($(filter 1, $(INSIDE_OCI) $(__INTROSPECTION_MODE__)),)

_%:
	@$(BASE_DEBUG_CMD)
	#$ #(error EROR: Private '_*' targets should not be run directly from the host TARGET=$@)

else # INSIDE_OCI & __INTROSPECTION_MODE__

# -------------------------------------------------------------------
# Data / file targets (proxy into container)
# -------------------------------------------------------------------
define FILE_DISPATCHER_RULE
data/$1/%:
	@$(eval $(call TARGET_INIT_FN,$$@))
	$(BASE_DEBUG_CMD)
	$(OCI_COMPOSE) --env-file $(ENV_FILE) $(call OCI_RUN_ENV_VARS) run $(OCI_RUN_ARGS) $(SERVICE) $(OCI_MAKE_CMD) $$@
endef
$(foreach s,$(OCI_SERVICES),$(eval $(call FILE_DISPATCHER_RULE,$s)))

OCI_SERVICES      := devops tf pandoc quarto megalinter powershell

define PHONY_DISPATCHER_RULE
.PHONY: $1-%
$1-%:
	@$(eval $(call TARGET_INIT_FN,$$@))
	$(BASE_DEBUG_CMD)
	$(OCI_COMPOSE) $(call OCI_RUN_ENV_VARS) run $(OCI_RUN_ARGS) $(SERVICE) $(OCI_MAKE_CMD) _$$@

endef
$(foreach s,$(OCI_SERVICES),$(eval $(call PHONY_DISPATCHER_RULE,$s)))

.PHONY: usage
usage: ~usage

.PHONY: ~usage
~usage:
	@$(BASE_DEBUG_CMD)
	$(info $(BASE_USAGE))

.PHONY: ~base-test ~base-test-arg1 ~base-test-arg1-arg2 _base-test _base-test-arg1 _base-test-arg1-arg2
~base-test ~base-test-arg1 ~base-test-arg1-arg2 _base-test _base-test-arg1 _base-test-arg1-arg2 data/base/test data/base/test-arg1 data/base/test-arg1-arg2:
	@$(eval $(call TARGET_INIT_FN,$@))
	$(BASE_DEBUG_CMD)
	echo "TARGET_RAW=$(TARGET_RAW),TARGET_TYPE=$(TARGET_TYPE),SERVICE=$(SERVICE),SERVICE_TASK=$(SERVICE_TASK),SERVICE_TASK_ARGS=$(SERVICE_TASK_ARGS)"
	if [ "$(TARGET_TYPE)" = "data" ]; then
	  mkdir -p $(dir $@)
	  touch "$@"
	fi

endif # INSIDE_OCI & __INTROSPECTION_MODE__
endif # BASE_MK
