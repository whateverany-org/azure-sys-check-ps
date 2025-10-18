# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
#
#  QUARTO
#
# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
ifndef QUARTO_MK
QUARTO_MK := 1

define QUARTO_USAGE
Available targets:
  quarto-site       - build all sites 
  quarto-shell      - container shell
  quarto-shell-root - container root shell
  quarto-clean      - clean me up
  quarto-all        - synonym for quarto-docs
  quarto-usage      - show this message
endef # QUARTO_USAGE

QUARTO_DEBUG    ?= false
QUARTO_DEBUG_CMD = :
ifneq ($(findstring true,$(QUARTO_DEBUG) $(BASE_DEBUG)),)
  QUARTO_DEBUG_CMD = echo "INFO: TARGET=$@"; set -x
endif

INSIDE_QUARTO_OCI := $(shell grep -q -x '0::/' /proc/self/cgroup && echo 1 || echo 0)
# --- Build Rules (Inside OCI) ---
ifeq ($(INSIDE_QUARTO_OCI),1)

ifeq ($(SERVICE),quarto)

QUARTO_DATA_DIR := data/$(SERVICE)

SHELL        := /bin/bash
.ONESHELL:

ENV_FILE        := .env
BASE_RUN_ID     ?= 0
BASE_RUN_FILE   := $(ENV_FILE).$(BASE_RUN_ID)
-include $(BASE_RUN_FILE)

# --- Directories / Environment ---
QUARTO_SRC_DIR    := src/site
QUARTO_SITE_DIR   := $(QUARTO_DATA_DIR)/site
QUARTO_ASSETS_DIR := $(QUARTO_SITE_DIR)/.site-assets
GFONT_DIR         := $(QUARTO_ASSETS_DIR)/gfonts
GFONT_FILES       := $(GFONT_DIR)/Roboto+Slab-400.woff2 \
                    $(GFONT_DIR)/Roboto+Slab-700.woff2 \
                    $(GFONT_DIR)/EB+Garamond-400.woff2 \
                    $(GFONT_DIR)/EB+Garamond-700.woff2 \
                    $(GFONT_DIR)/Fira+Mono-400.woff2 \
                    $(GFONT_DIR)/Fira+Mono-700.woff2
GFONT_URL         := https://fonts.googleapis.com/css2
TFONT_DIR         := $(QUARTO_ASSETS_DIR)/tfonts
TFONT_FILES       := $(TFONT_DIR)/texgyretermes-regular.woff2 \
                    $(TFONT_DIR)/texgyretermes-bold.woff2 \
                    $(TFONT_DIR)/texgyrecursor-regular.woff2 \
                    $(TFONT_DIR)/texgyrecursor-bold.woff2 \
                    $(TFONT_DIR)/texgyreheros-regular.woff2 \
                    $(TFONT_DIR)/texgyreheros-bold.woff2
TFONT_URL         := https://au.mirrors.cicku.me/ctan/fonts/tex-gyre/opentype
WGET_CMD          := wget -q --header="User-Agent: Mozilla/5.0" -O -

$(GFONT_DIR)/%.woff2:
	@$(QUARTO_DEBUG_CMD)
	mkdir -p $(dir $@)
	_FONT_FILE="$$(basename $@)"
	_FAMILY="$${_FONT_FILE/-*}"
	_WEIGHT="$${_FONT_FILE//*-}"
	_WEIGHT="$${_WEIGHT/.woff2}"
	_URL="$$($(WGET_CMD) $(GFONT_URL)?family="$${_FAMILY}":wght@"$${_WEIGHT}" | grep -E '^\s*src:' | sed -e 's/\s*src:\s*url(//' -e 's/) .*//')"
	$(WGET_CMD) "$${_URL}" > "$@"

$(TFONT_DIR)/%.woff2:
	@$(QUARTO_DEBUG_CMD)
	mkdir -p $(dir $@)
	_BASE="$$(basename $@ .woff2)"
	_OTF="$(dir $@)$${_BASE}.otf"
	$(WGET_CMD) "$(TFONT_URL)/$${_BASE}.otf" > "$${_OTF}"
	woff2_compress "$${_OTF}"
	$(RM) "$${_OTF}"

.PHONY: _quarto-fonts
_quarto-fonts: $(GFONT_FILES) $(TFONT_FILES)
	@$(QUARTO_DEBUG_CMD)

.PHONY: _quarto-site
_quarto-site: _quarto-fonts
	@$(QUARTO_DEBUG_CMD)
	rsync -a --delete --exclude="$$(basename $(QUARTO_ASSETS_DIR))/" $(QUARTO_SRC_DIR)/ $(QUARTO_SITE_DIR)/
	quarto render $(QUARTO_SITE_DIR)

.PHONY: _quarto-clean-site
_quarto-clean-site:
	@$(QUARTO_DEBUG_CMD)
	$(RM) -r $(filter-out $(QUARTO_ASSETS_DIR), $(wildcard $(QUARTO_SITE_DIR)/*) $(QUARTO_SITE_DIR)/.dummy)

.PHONY: _quarto-clean-site_assets
_quarto-clean-site_assets:
	@$(QUARTO_DEBUG_CMD)
	$(RM) -r $(QUARTO_ASSETS_DIR)

.PHONY: _quarto-all
_quarto-all:
	@$(QUARTO_DEBUG_CMD)

.PHONY: _quarto-clean
_quarto-clean:
	@$(QUARTO_DEBUG_CMD)
	$(RM) -r $(QUARTO_SITE_DIR) $(QUARTO_ASSETS_DIR)

.PHONY: _quarto-shell
_quarto-shell:
	@$(QUARTO_DEBUG_CMD)
	SHELL="$(QUARTO_SHELL)" $(QUARTO_SHELL)

.PHONY: _quarto-shell-%
_quarto-shell-%: _quarto-shell
	@$(QUARTO_DEBUG_CMD)

.PHONY: _quarto-usage
_quarto-usage:
	@$(QUARTO_DEBUG_CMD)
	echo "$(QUARTO_USAGE)"

.PHONY: _quarto-test _quarto-test-arg1 _quarto-test-arg1-arg2
_quarto-test _quarto-test-arg1 _quarto-test-arg1-arg2 data/quarto/test data/quarto/test-arg1 data/quarto/test-arg1-arg2:
	@$(eval $(call TARGET_INIT_FN,$@))
	$(QUARTO_DEBUG_CMD)
	echo "TARGET_RAW=$(TARGET_RAW),TARGET_TYPE=$(TARGET_TYPE),SERVICE=$(SERVICE),SERVICE_TASK=$(SERVICE_TASK),SERVICE_TASK_ARGS=$(SERVICE_TASK_ARGS)"
	if [ "$(TARGET_TYPE)" = "data" ]; then
	  mkdir -p $(dir $@)
	  touch "$@"
	fi

endif # SERVICE

# --- Build Rules (on HOST) ---
else
.PHONY: ~quarto-usage
~quarto-usage:
	@$(QUARTO_DEBUG_CMD)
	echo "$(QUARTO_USAGE)"

.PHONY: ~quarto-test ~quarto-test-arg1 ~quarto-test-arg1-arg2
~quarto-test ~quarto-test-arg1 ~quarto-test-arg1-arg2:
	@$(eval $(call TARGET_INIT_FN,$@))
	$(QUARTO_DEBUG_CMD)
	echo "TARGET_RAW=$(TARGET_RAW),TARGET_TYPE=$(TARGET_TYPE),SERVICE=$(SERVICE),SERVICE_TASK=$(SERVICE_TASK),SERVICE_TASK_ARGS=$(SERVICE_TASK_ARGS)"

endif # INSIDE_QUARTO_OCI

endif # QUARTO_MK

