# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
#
#  POWERSHELL
#
# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
ifndef POWERSHELL_MK
POWERSHELL_MK         := 
define POWERSHELL_USAGE
Available targets:
  _powershell-all    - Build all powershell components.
  _powershell-usage  - Display this message.
endef

POWERSHELL_DEBUG    ?= false
POWERSHELL_DEBUG_CMD = :
ifneq ($(findstring true,$(POWERSHELL_DEBUG) $(BASE_DEBUG)),)
  POWERSHELL_DEBUG_CMD = echo "INFO: TARGET=$@"; set -x
endif

INSIDE_POWERSHELL_OCI := $(shell grep -q -x '0::/' /proc/self/cgroup && echo 1 || echo 0)
# --- Build Rules (Inside OCI) ---
ifeq ($(INSIDE_POWERSHELL_OCI),1)

ifeq ($(SERVICE),powershell)

DEVOPS_DATA_DIR := data/$(SERVICE)

SHELL        := /bin/bash
.ONESHELL:

ENV_FILE        := .env
BASE_RUN_ID     ?= 0
BASE_RUN_FILE   := $(ENV_FILE).$(BASE_RUN_ID)
-include $(BASE_RUN_FILE)

# --- Directories / Environment ---

.PHONY: _powershell-all
_powershell-all:
	@$(POWERSHELL_DEBUG_CMD)
	$(info INFO: $@ OK)

.PHONY: _powershell-clean
_powershell-clean:
	@$(POWERSHELL_DEBUG_CMD)
	rm -f $(POWERSHELL_DATA_DIR)/*

.PHONY: _powershell-shell
_powershell-shell:
	@$(POWERSHELL_DEBUG_CMD)
	SHELL="$(SHELL)" $(SHELL)

.PHONY: _powershell-shell-%
_powershell-shell-%: _powershell-shell
	@$(POWERSHELL_DEBUG_CMD)

_powershell-usage:
	@$(POWERSHELL_DEBUG_CMD)
	echo "$(POWERSHELL_USAGE)"

.PHONY: _powershell-test _powershell-test-arg1 _powershell-test-arg1-arg2
_powershell-test _powershell-test-arg1 _powershell-test-arg1-arg2 data/powershell/test data/powershell/test-arg1 data/powershell/test-arg1-arg2:
	@$(eval $(call TARGET_INIT_FN,$@))
	$(POWERSHELL_DEBUG_CMD)
	echo "TARGET_RAW=$(TARGET_RAW),TARGET_TYPE=$(TARGET_TYPE),SERVICE=$(SERVICE),SERVICE_TASK=$(SERVICE_TASK),SERVICE_TASK_ARGS=$(SERVICE_TASK_ARGS)"
	if [ "$(TARGET_TYPE)" = "data" ]; then
	  mkdir -p $(dir $@)
	  touch "$@"
	fi

.PHONY: _powershell-run-%
_powershell-run-%:
	@$(eval $(call TARGET_INIT_FN,$@))
	./src/powershell/$(SERVICE_TASK_ARGS)

endif # SERVICE

# --- Build Rules (on HOST) ---
else # INSIDE_POWERSHELL_OCI
.PHONY: ~powershell-usage
~powershell-usage:
	@$(POWERSHELL_DEBUG_CMD)
	echo "$(POWERSHELL_USAGE)"

.PHONY: ~powershell-test ~powershell-test-arg1 ~powershell-test-arg1-arg2
~powershell-test ~powershell-test-arg1 ~powershell-test-arg1-arg2:
	@$(eval $(call TARGET_INIT_FN,$@))
	$(POWERSHELL_DEBUG_CMD)
	echo "TARGET_RAW=$(TARGET_RAW),TARGET_TYPE=$(TARGET_TYPE),SERVICE=$(SERVICE),SERVICE_TASK=$(SERVICE_TASK),SERVICE_TASK_ARGS=$(SERVICE_TASK_ARGS)"

endif # INSIDE_POWERSHELL_OCI

endif # POWERSHELL_MK
