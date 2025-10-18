# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
#
#  DEVOPS
#
# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
ifndef DEVOPS_MK
DEVOPS_MK         := 1

define DEVOPS_USAGE
Available targets:

 ~devops-build:           (or devops-build_<image>:)
   ~devops-build:
   ~devops-show-latest:
   ~devops-ENV_FILE_B64:
   ~devops-vm_images:
   data/<image.qcow2>:
   ~devops-imagebuilder_dm200-build:
   ~devops-imagebuilder_dm200-upgrade:
   ~devops-vault-run:
   ~devops-secrets:
   ~devops-secrets-clean:

 clean:
   devops-clean:
   devops-cache-clean:
   devops-distclean:
   devops-maintainer-clean:
   devops-pristine:
   devops-realclean:
endef

DEVOPS_DEBUG    ?= false
DEVOPS_DEBUG_CMD = TARGET_RAW=$@
ifneq ($(findstring true,$(DEVOPS_DEBUG) $(BASE_DEBUG)),)
  DEVOPS_DEBUG_CMD = TARGET_RAW=$@; echo "INFO: TARGET_RAW=$${TARGET_RAW}"; set -x
endif

INSIDE_DEVOPS_OCI := $(shell grep -q -x '0::/' /proc/self/cgroup && echo 1 || echo 0)
# --- Build Rules (Inside OCI) ---
ifeq ($(INSIDE_DEVOPS_OCI),1)

ifeq ($(SERVICE),devops)

DEVOPS_DATA_DIR := data/$(SERVICE)

SHELL           := /bin/bash
.ONESHELL:

ENV_FILE        := .env
BASE_RUN_ID     ?= 0
BASE_RUN_FILE   := $(ENV_FILE).$(BASE_RUN_ID)
-include $(BASE_RUN_FILE)

# --- Directories / Environment ---

SPACE             := $(eval) #
COMMA             := $(eval),#

#_$(ENV_FILE):
#	@:
#	$(if $(wildcard $(ENV_FILE)),, $ (info INFO: $(ENV_FILE) doesn't exist, copying $(ENV_FILE))$(file > $(ENV_FILE), $(file < $(ENV_TEMPLATE_FILE))))
#.PHONY: $(ENV_FILE)

IAC_TARGETS_ALL     ?= $(sort $(patsubst %/,%,$(dir $(wildcard tf/*/*/main.tf))))
IAC_TARGETS         ?= tf/terraway/citadell-dom0 tf/ironway/lenoline-dom0

IAC_SITE_NODE_PAIRS := $(patsubst tf/%,%,$(IAC_TARGETS_ALL))
IAC_SITES := $(sort $(foreach pair,$(IAC_SITE_NODE_PAIRS),$(word 1,$(subst /, ,$(pair)))))
IAC_NODES := $(sort $(foreach pair,$(IAC_SITE_NODE_PAIRS),$(notdir $(pair))))

.PHONY: _devops-iac
_devops-iac: _tf 
	@$(DEVOPS_DEBUG_CMD)

.PHONY: _devops-iac-info
_devops-iac-info: _tf-info 
	@$(DEVOPS_DEBUG_CMD)

.PHONY: _devops-iac-update
_devops-iac-update:
	@$(DEVOPS_DEBUG_CMD)
	echo git pull --ff-only

define IAC_RULES
$(call TF_RULES,$(1))
endef

$(foreach t,$(IAC_TARGETS_ALL),$(eval $(call IAC_RULES,$(t))))

.PHONY: _devops-all
_devops-all:
	@$(DEVOPS_DEBUG_CMD)

.PHONY: _devops-clean
_devops-clean:
	@$(DEVOPS_DEBUG_CMD)
	$(RM) -r $(DEVOPS_DATA_DIR)/*
	#$(OCI) system prune --all --force
	#$(OCI) volume prune --force
	#$(OCI) rmi $(OCI_IMAGE_DEVOPS)

.PHONY: _devops-shell
_devops-shell:
	@$(DEVOPS_DEBUG_CMD)
	SHELL="$(SHELL)" $(SHELL)

.PHONY: _devops-shell-%
_devops-shell-%: _devops-shell
	@$(DEVOPS_DEBUG_CMD)

.PHONY: _devops-usage
_devops-usage:
	@$(DEVOPS_DEBUG_CMD)
	echo "$(DEVOPS_USAGE)"

.PHONY: _devops-test _devops-test-arg1 _devops-test-arg1-arg2
_devops-test _devops-test-arg1 _devops-test-arg1-arg2 data/devops/test data/devops/test-arg1 data/devops/test-arg1-arg2:
	@$(eval $(call TARGET_INIT_FN,$@))
	$(DEVOPS_DEBUG_CMD)
	echo "TARGET_RAW=$(TARGET_RAW),TARGET_TYPE=$(TARGET_TYPE),SERVICE=$(SERVICE),SERVICE_TASK=$(SERVICE_TASK),SERVICE_TASK_ARGS=$(SERVICE_TASK_ARGS)"
	if [ "$(TARGET_TYPE)" = "data" ]; then
	  mkdir -p $(dir $@)
	  touch "$@"
	fi

endif # SERVICE
# --- Build Rules (on HOST) ---
else # INSIDE_DEVOPS_OCI

.PHONY: ~devops-usage
~devops-usage:
	@$(DEVOPS_DEBUG_CMD)
	echo "$(DEVOPS_USAGE)"

OCI               := podman
OCI_ENV_VARS       ?= $(shell grep -v '^#' $(ENV_FILE) | sed -e 's/^\(^[^=]*\)=.*/\1/' | tr '\n' ' ')
OCI_BUILD_DIR      ?= oci
OCI_BUILD_VERSION  ?= 0.0.1
OCI_BUILD_ARGS     ?= $(OCI_ARGS) $(foreach _t,$(OCI_ENV_VARS),--build-arg '$(_t)=$${$(_t)}')
OCI_BUILD_ARGS_END ?=
OCI_BUILD_IMAGE    ?=
OCI_BUILD          ?= $(OCI_COMPOSE) $(OCI_COMPOSE_ARGS) --podman-build-args="$(OCI_BUILD_ARGS) $(OCI_BUILD_ARGS_END)" build
OCI_RUN_ARGS       ?= $(OCI_ARGS) $(OCI_ENV_ARGS) -e _DEBUG=$(_DEBUG) --secret TF_VAR_ENV_FILE_B64,type=env
OCI_BUILD_TARGETS  ?= $(foreach DEF,$(OCI_SERVICES),~devops-build_$(DEF))

.PHONY: ~devops-build
~devops-build: $(OCI_BUILD_TARGETS)
	@$(DEVOPS_DEBUG_CMD)

define OCI_BUILD_DEF
.PHONY: ~devops-build_$(1)
~devops-build-$(1):
	@$(DEVOPS_DEBUG_CMD)
	$(eval OCI_BUILD_TAG := localhost/whateverany/$(1):$(OCI_BUILD_VERSION))
	$(eval OCI_BUILD_IMAGE := $(1))
	$(eval OCI_BUILD_ARGS_END := )
  $(eval OCI_COMPOSE_ARGS   += --podman-build-args=--build-arg=OCI_SERVICE_NAME=$(1))
  $(eval OCI_COMPOSE_ARGS   += --podman-build-args=--env=OCI_SERVICE_NAME=$(1))
  $(eval OCI_COMPOSE_ARGS   += --podman-build-args=--build-arg=OCI_DATA_DIR=/a/data/$(1))
  $(eval OCI_COMPOSE_ARGS   += --podman-build-args=--env=OCI_DATA_DIR=/a/data/$(1))
	$(eval OCI_BUILD_ARGS_END += --file "$(OCI_BUILD_DIR)/$(1)/Containerfile")
	$(eval OCI_BUILD_ARGS_END += --tag localhost/whateverany/$(1):$(OCI_BUILD_VERSION))
	$(eval OCI_BUILD_ARGS_END += --tag localhost/whateverany/$(1):latest)
	$(eval OCI_BUILD_ARGS_END += --no-cache)
	$(OCI_BUILD) $(1)
	$(OCI) images --filter "reference=$(OCI_BUILD_TAG)" --format "{{.Repository}}:{{.Tag}}" | grep -q "$(OCI_BUILD_TAG)" && echo $(OCI) rmi $(OCI_BUILD_TAG)

endef

$(foreach _i,$(OCI_SERVICES),$(eval $(call OCI_BUILD_DEF,$(_i))))

.PHONY: ~devops-secrets
~devops-secrets:
	@$(DEVOPS_DEBUG_CMD)
	while IFS='=' read -r _KEY _VAL; do
	  [ -z "$${_KEY}" ] && continue
	  case "$${_KEY}" in \#*) continue ;; esac
	  if ! $(OCI) secret ls --filter Name="$${_KEY}" --format '{{.Name}}' | grep -q "^$${_KEY}$$"; then
	    echo -n "$${_VAL}" | $(OCI) secret create --label "project=devops" "$${_KEY}" -
	  fi
	  _TF_KEY="TF_VAR_$${_KEY}"
	  if ! $(OCI) secret ls --filter Name="$${_TF_KEY}" --format '{{.Name}}' | grep -q "^$${_TF_KEY}$$"; then
	    echo -n "$${_VAL}" | $(OCI) secret create --label "project=devops" "$${_TF_KEY}" -
	  fi
	done < $(ENV_FILE)

.PHONY: ~devops-secrets-clean
~devops-secrets-clean:
	@$(DEVOPS_DEBUG_CMD)
	for _KEY in $$($(OCI) secret ls --noheading | cut -d' ' -f1); do
	  $(OCI) secret rm "$${_KEY}"
	done

.PHONY: ~devops-show-latest
~devops-show-latest:
	@$(DEVOPS_DEBUG_CMD)
	./scripts/oci_show_latest.sh

.PHONY: ~ENV_FILE_B64
~ENV_FILE_B64:
	@$(DEVOPS_DEBUG_CMD)
	$(OCI) secret ls --filter Name="ENV_FILE_B64" --format '{{.Name}}' | grep -q "ENV_FILE_B64" || (base64 -w0 $(ENV_FILE) | $(OCI) secret create --label "project=$(SERVICE)" ENV_FILE_B64 -) && (base64 -w0 $(ENV_FILE) | $(OCI) secret create --label "project=$(SERVICE)" "TF_VAR_ENV_FILE_B64" -)

.PHONY: ~devops-clean
~devops-clean:
	@$(DEVOPS_DEBUG_CMD)
	$(OCI) system prune --all --force
	$(OCI) volume prune --force
	$(OCI) rmi $(OCI_IMAGE_DEVOPS)

.PHONY: ~devops-test ~devops-test-arg1 ~devops-test-arg1-arg2
~devops-test ~devops-test-arg1 ~devops-test-arg1-arg2:
	@$(eval $(call TARGET_INIT_FN,$@))
	$(DEVOPS_DEBUG_CMD)
	echo "TARGET_RAW=$(TARGET_RAW),TARGET_TYPE=$(TARGET_TYPE),SERVICE=$(SERVICE),SERVICE_TASK=$(SERVICE_TASK),SERVICE_TASK_ARGS=$(SERVICE_TASK_ARGS)"

endif # INSIDE_DEVOPS_OCI
endif # DEVOPS_MK
