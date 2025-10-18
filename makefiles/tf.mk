# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
#
# TF
#
# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
ifndef TF_MK
TF_MK                := 1

define TF_USAGE
Available targets:
  tf-all    - Build all tf components.
  tf-usage  - Display this message.
  tf-info:       (or tf-info/iac/<site>/<node>:))
  tfapply:       (or tfapply/iac/<site>/<node>:))
  tfclean:       (or tfclean/iac/<site>/<node>:))
  tfdestroy:     (or tfdestroy/iac/<site>/<node>:))
  tfinit:        (or tfinit/iac/<site>/<node>:))
  tfplan:        (or tfplan/iac/<site>/<node>:))
  tfimport:      (or tfimport/iac/<site>/<node>:))
endef # TF_USAGE

TF_DEBUG      ?= false
TF_DEBUG_CMD   = :
ifneq ($(findstring true,$(TF_DEBUG) $(BASE_DEBUG)),)
TF_DEBUG_CMD = echo "INFO: TARGET=$@"; set -x
endif

INSIDE_TF_OCI := $(shell grep -q -x '0::/' /proc/self/cgroup && echo 1 || echo 0)
# --- Build Rules (Inside OCI) ---
ifeq ($(INSIDE_TF_OCI),1)

ifeq ($(SERVICE),tf)

TF_DATA_DIR  := data/$(SERVICE)

SHELL    := /bin/bash
.ONESHELL:

ENV_FILE      := .env
BASE_RUN_ID   ?= 0
BASE_RUN_FILE := $(ENV_FILE).$(BASE_RUN_ID)
-include $(BASE_RUN_FILE)

# --- Directories / Environment ---
IAC_TARGETS := $(sort \
  $(subst /,_, \
    $(patsubst tf/%,%,$(patsubst %/,%,$(dir $(wildcard tf/*/*/main.tf)))) \
  ) \
)

# derive useful pieces
TF_DATA_ROOT := /data/tf

define TF_VARS
$(eval TF_NODE             := $(word 2,$(subst _, ,$(1))))
$(eval TF_SITE             := $(word 1,$(subst _, ,$(1))))
$(eval TF_SRC_DIR          := $(TF_DATA_DIR)/src)
$(eval TF_NODE_DIR         := $(TF_SRC_DIR)/$(TF_SITE)/$(TF_NODE))
$(eval TF_STATE_DIR        := .terraform)

$(eval TF_BACKUP_FILE      := $(TF_STATE_DIR)/$(TF_NODE).tf_backup)
$(eval TF_PLAN_FILE        := $(TF_STATE_DIR)/$(TF_NODE).tf_plan)
$(eval TF_STATE_FILE       := $(TF_STATE_DIR)/$(TF_NODE).tf_state)

$(eval TF_APPLY_ARGS       := -input=false \
                                -auto-approve \
                                -backup="$(TF_BACKUP_FILE)" \
                                -state="$(TF_STATE_FILE)" \
                                -lock-timeout=15m \
                                $(TF_PLAN_FILE))
$(eval TF_IMPORT_ARGS      := -input=false \
                                -state="$(TF_STATE_FILE)" \
                                -lock-timeout=15m)
$(eval TF_PLAN_ARGS        := -input=false \
                                -out="$(TF_PLAN_FILE)" \
                                -state="$(TF_STATE_FILE)" \
                                -lock-timeout=15m)
endef

.PHONY: _tf-info-%
_tf-info-%:
	@$(TF_DEBUG_CMD)
	$(call TF_VARS,$*)

.PHONY: _tf-init-%
_tf-init-%:
	@$(TF_DEBUG_CMD)
	$(call TF_VARS,$*)
	mkdir -p $(TF_NODE_DIR) $(TF_SRC_DIR)
	rsync -av --delete --exclude='.terraform/' tf/ $(TF_SRC_DIR)
	echo "TF_SITE=$(TF_SITE) TF_NODE=$(TF_NODE) TF_SRC=$(TF_SRC) TF_NODE_DIR=$(TF_NODE_DIR)"
	tofu -chdir=$(TF_NODE_DIR) init -var-file="../site.tfvars"

.PHONY: _tf-plan-%
_tf-plan-%:
	@$(TF_DEBUG_CMD)
	$(call TF_VARS,$*)
	tofu -chdir=$(TF_NODE_DIR) plan -var-file="../site.tfvars" -out=$(TF_PLAN_FILE)

.PHONY: _tf-apply-%
_tf-apply-%:
	@$(TF_DEBUG_CMD)
	$(call TF_VARS,$*)
	tofu -chdir=$(TF_NODE_DIR) apply -auto-approve $(TF_PLAN_FILE)

.PHONY: _tf-destroy-%
_tf-destroy-%:
	@$(TF_DEBUG_CMD)
	$(call TF_VARS,$*)
	tofu -chdir=$(TF_NODE_DIR) destroy -auto-approve

.PHONY: _tf-clean-%
_tf-clean-%:
	@$(TF_DEBUG_CMD)
	$(call TF_VARS,$*)
	$(RM) -r $(TF_NODE_DIR)-*

.PHONY: _tf-all-%
_tf-all-%: _tf-init-%
_tf-all-%: _tf-plan-%
_tf-all-%: _tf-apply-%

# --- Directories / Environment ---
.PHONY: _tf-all
_tf-all:
	@$(TF_DEBUG_CMD)

.PHONY: _tf-clean
_tf-clean:
	@$(TF_DEBUG_CMD)

.PHONY: _tf-shell
_tf-shell:
	@$(TF_DEBUG_CMD)
	SHELL="$(SHELL)" $(SHELL)

.PHONY: _tf-shell-%
_tf-shell-%: _tf-shell
	@$(TF_DEBUG_CMD)

.PHONY: _tf-usage
_tf-usage:
	@$(TF_DEBUG_CMD)
	echo "$(TF_USAGE)"

.PHONY: _tf-test _tf-test-arg1 _tf-test-arg1-arg2
_tf-test _tf-test-arg1 _tf-test-arg1-arg2 data/tf/test data/tf/test-arg1 data/tf/test-arg1-arg2:
	@$(eval $(call TARGET_INIT_FN,$@))
	$(TF_DEBUG_CMD)
	echo "TARGET_RAW=$(TARGET_RAW),TARGET_TYPE=$(TARGET_TYPE),SERVICE=$(SERVICE),SERVICE_TASK=$(SERVICE_TASK),SERVICE_TASK_ARGS=$(SERVICE_TASK_ARGS)"
	if [ "$(TARGET_TYPE)" = "data" ]; then
	  mkdir -p $(dir $@)
	  touch "$@"
	fi

endif # SERVICE

# --- Build Rules (on HOST) ---
else # INSIDE_TF_OCI
.PHONY: ~tf-usage
~tf-usage: 
	@$(TF_DEBUG_CMD)
	echo "$(TF_USAGE)"

.PHONY: ~tf-test ~tf-test-arg1 ~tf-test-arg1-arg2
~tf-test ~tf-test-arg1 ~tf-test-arg1-arg2:
	@$(eval $(call TARGET_INIT_FN,$@))
	$(TF_DEBUG_CMD)
	echo "TARGET_RAW=$(TARGET_RAW),TARGET_TYPE=$(TARGET_TYPE),SERVICE=$(SERVICE),SERVICE_TASK=$(SERVICE_TASK),SERVICE_TASK_ARGS=$(SERVICE_TASK_ARGS)"

endif # INSIDE_TF_OCI

endif # TF_MK
