# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
#
#  MEGALINTER
#
# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
ifndef MEGALINTER_MK
MEGALINTER_MK         := 1

define MEGALINTER_USAGE
Available targets:
  megalinter-all   - Run megalinter-lint
  megalinter-usage - Display this message.
  megalinter-lint  - Run all megalinter components.
  megalinter-clean - Cleanup megalinter temporary artifacts.
endef

MEGALINTER_DEBUG    ?= false
MEGALINTER_DEBUG_CMD = :
ifneq ($(findstring true,$(MEGALINTER_DEBUG) $(BASE_DEBUG)),)
  MEGALINTER_DEBUG_CMD = echo "INFO: TARGET=$@"; set -x
endif

INSIDE_MEGALINTER_OCI := $(shell grep -q -x '0::/' /proc/self/cgroup && echo 1 || echo 0)
# --- Build Rules (Inside OCI) ---
ifeq ($(INSIDE_MEGALINTER_OCI),1)

ifeq ($(SERVICE),megalinter)

PROJECT_NAME        := $(SERVICE)
MEGALINTER_DATA_DIR := data/$(SERVICE)

SHELL            := /bin/bash
.ONESHELL:

ENV_FILE            := .env
BASE_RUN_ID         ?= 0
BASE_RUN_FILE       := $(ENV_FILE).$(BASE_RUN_ID)
-include $(BASE_RUN_FILE)

# --- Directories / Environment ---

MEGALINTER_DIRS      := $(OCI_DATA_DIR)/azure-devops \
                        $(OCI_DATA_DIR)/cache \
                        $(OCI_DATA_DIR)/copy-paste \
                        $(OCI_DATA_DIR)/home \
                        $(OCI_DATA_DIR)/reports \
                        $(OCI_DATA_DIR)/updated_sources

.PHONY: _megalinter-lint
_megalinter-lint:
	@$(MEGALINTER_DEBUG_CMD)
	DEFAULT_BRANCH=$(GIT_BRANCH_SHORT) /entrypoint.sh

.PHONY: _megalinter-lint-%
_megalinter-lint-%:
	@$(DEVOPS_DEBUG_CMD)
	DEFAULT_BRANCH=$(GIT_BRANCH_SHORT) ENABLE_LINTERS="$(SERVICE_TASK_ARGS)" /entrypoint.sh

.PHONY: _megalinter-all
_megalinter-all: _megalinter-lint
	@$(MEGALINTER_DEBUG_CMD)

.PHONY: _megalinter-clean
_megalinter-clean:
	@$(MEGALINTER_DEBUG_CMD)
	$(RM) -r $(MEGALINTER_DIRS)

.PHONY: _megalinter-shell
_megalinter-shell:
	@$(MEGALINTER_DEBUG_CMD)
	SHELL="$(SHELL)" $(SHELL)

.PHONY: _megalinter-shell-%
_megalinter-shell-%: _megalinter-shell
	@$(MEGALINTER_DEBUG_CMD)

.PHONY: _megalinter-usage
_megalinter-usage:
	@$(MEGALINTER_DEBUG_CMD)
	echo "$(MEGALINTER_USAGE)"

.PHONY: _megalinter-test _megalinter-test-arg1 _megalinter-test-arg1-arg2
_megalinter-test _megalinter-test-arg1 _megalinter-test-arg1-arg2 data/megalinter/test data/megalinter/test-arg1 data/megalinter/test-arg1-arg2:
	@$(eval $(call TARGET_INIT_FN,$@))
	$(MEAGLINTER_DEBUG_CMD)
	echo "TARGET_RAW=$(TARGET_RAW),TARGET_TYPE=$(TARGET_TYPE),SERVICE=$(SERVICE),SERVICE_TASK=$(SERVICE_TASK),SERVICE_TASK_ARGS=$(SERVICE_TASK_ARGS)"
	if [ "$(TARGET_TYPE)" = "data" ]; then
	  mkdir -p $(dir $@)
	  touch "$@"
	fi

endif # SERVICE

# --- Build Rules (on HOST) ---
else # INSIDE_MEGALINTER_OCI
.PHONY: ~megalinter-usage
~megalinter-usage:
	@$(MEGALINTER_DEBUG_CMD)
	echo "$(MEGALINTER_USAGE)"

.PHONY: ~megalinter-test ~megalinter-test-arg1 ~megalinter-test-arg1-arg2
~megalinter-test ~megalinter-test-arg1 ~megalinter-test-arg1-arg2:
	@$(eval $(call TARGET_INIT_FN,$@))
	$(MEAGLINTER_DEBUG_CMD)
	echo "TARGET_RAW=$(TARGET_RAW),TARGET_TYPE=$(TARGET_TYPE),SERVICE=$(SERVICE),SERVICE_TASK=$(SERVICE_TASK),SERVICE_TASK_ARGS=$(SERVICE_TASK_ARGS)"

endif # INSIDE_MEGALINTER_OCI

endif # MEGALINTER_MK

