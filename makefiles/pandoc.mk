# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
#
# PANDOC MAKEFILE
#
# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
ifndef PANDOC_MK
PANDOC_MK         := 1

define PANDOC_USAGE
Available targets:
 Build targets:
  pandoc-all              - pandoc-src pandoc-docs
  pandoc-docs             - pandoc-txt pandoc-pdf pandoc-sig pandoc-signed_pdf
  pandoc-src              - pandoc-version pandoc-md
  pandoc-version          -
  pandoc-md               -
  pandoc-txt              -
  pandoc-pdf              -
  pandoc-sig       -
  pandoc-signed_pdf       -

 Clean targets:
  pandoc-clean            - pandoc-clean-src pandoc-clean-docs pandoc-clean-certs
  pandoc-clean-docs       - pandoc-clean-txt pandoc-clean-pdf pandoc-clean-sig pandoc-clean-signed_pdf
  pandoc-clean-src        - pandoc-clean-md
  pandoc-clean-md         -
  pandoc-clean-txt        -
  pandoc-clean-pdf        -
  pandoc-clean-sig -
  pandoc-clean-signed_pdf -
  pandoc-clean-certs      -

 Other targets:
  pandoc-shell            - container shell
  pandoc-shell-root       - container root shell
  pandoc-usage            - show this message

 File targets:
  data/pandoc/docs/signed/**/*.sig-verify - verify signed artifact
  data/pandoc/docs/signed/**/*.sig-info   - show signed artifact information
  data/pandoc/docs/signed/**/*.sig-log    - log signed artifacts LOG_AUDIT_FILE=$(LOG_AUDIT_FILE)
endef # PANDOC_USAGE

PANDOC_DEBUG    ?= false
PANDOC_DEBUG_CMD = :
ifneq ($(findstring true,$(PANDOC_DEBUG) $(BASE_DEBUG)),)
  PANDOC_DEBUG_CMD = echo "INFO: TARGET=$@"; set -x
endif

INSIDE_PANDOC_OCI := $(shell grep -q -x '0::/' /proc/self/cgroup && echo 1 || echo 0)
# --- Build Rules (Inside OCI) ---
ifeq ($(INSIDE_PANDOC_OCI),1)

ifeq ($(SERVICE),pandoc)

PANDOC_DATA_DIR := data/$(SERVICE)

SHELL        := /bin/bash
.ONESHELL:

ENV_FILE        := .env
BASE_RUN_ID     ?= 0
BASE_RUN_FILE   := $(ENV_FILE).$(BASE_RUN_ID)
-include $(BASE_RUN_FILE)

# --- Directories / Environment ---

J2_MD_DIR := src/docs

J2_MD_FILES    := $(shell find $(J2_MD_DIR)/*/ -mindepth 2 -type f -name '*.md.j2')

DOCS_DIR       := $(PANDOC_DATA_DIR)/docs

TMP_DIR        := $(PANDOC_DATA_DIR)/.tmp

# Document metadata
DOC_VERSION    ?= $(shell git rev-parse --short HEAD)
DOC_REPO       ?= $(shell git config --get remote.origin.url)
DOC_AUTHOR     ?= "."
DOC_RECIPIENT  ?= "."

LOG_ENTRY_TIME ?= $(shell date -u --iso-8601=seconds --date='@$(BASE_RUN_ID)')

DATA_CLEAN     ?= sed -E 's/(MI[A-Za-z0-9+/=]{14}).*/\1.../'

# Tools
B2SUM     ?= b2sum
BASE64    ?= base64
EXIFTOOL  ?= exiftool
J2        ?= j2
JQ        ?= jq
OPENSSL   ?= openssl
PANDOC    ?= pandoc

### # ----------------------
### # Certs
### # ----------------------

TMP_DOCME_CA_CERT    := $(TMP_DIR)/docme_ca.cert
TMP_DOCME_CRYPT_CERT := $(TMP_DIR)/docme_crypt.cert
TMP_DOCME_CRYPT_KEY  := $(TMP_DIR)/docme_crypt.key
TMP_DOCME_SIGN_CERT  := $(TMP_DIR)/docme_sign.cert
TMP_DOCME_SIGN_KEY   := $(TMP_DIR)/docme_sign.key
TMP_HOME_CA_CERT     := $(TMP_DIR)/home_ca.cert

TMP_CERT_FILES       := $(TMP_DOCME_CA_CERT) \
                          $(TMP_DOCME_CRYPT_CERT) \
                          $(TMP_DOCME_CRYPT_KEY)  \
                          $(TMP_DOCME_SIGN_CERT) \
                          $(TMP_DOCME_SIGN_KEY) \
                          $(TMP_HOME_CA_CERT)

.PHONY: _pandoc-clean-certs
_pandoc-clean-certs:
	@$(RM) $(TMP_CERT_FILES)

$(TMP_DOCME_CA_CERT):
	@echo -e "$(DOCME_CA_CERT)"    | install -D -m u+rw,go= /dev/stdin $@

$(TMP_DOCME_CRYPT_CERT):
	@echo -e "$(DOCME_CRYPT_CERT)" | install -D -m u+rw,go= /dev/stdin $@

$(TMP_DOCME_CRYPT_KEY):
	@echo -e "$(DOCME_CRYPT_KEY)"  | install -D -m u+rw,go= /dev/stdin $@

$(TMP_DOCME_SIGN_CERT):
	@echo -e "$(DOCME_SIGN_CERT)"  | install -D -m u+rw,go= /dev/stdin $@

$(TMP_DOCME_SIGN_KEY):
	@echo -e "$(DOCME_SIGN_KEY)"   | install -D -m u+rw,go= /dev/stdin $@

$(TMP_HOME_CA_CERT):
	@echo -e "$(HOME_CA_CERT)"     | install -D -m u+rw,go= /dev/stdin $@

### # ----------------------
### # handy macros
### # ----------------------
define DOC_METADATA
	_VERSION_FILE="${1}"
	read -r FILE_VERSION <"$${_VERSION_FILE}"
	_DOC_PATH_REL="$${_VERSION_FILE#$(VERSION_DIR)/}"
	_DOC_PATH_BASE="$${_DOC_PATH_REL%.md.version}"
	_DOC_PATH_ARRAY=($${_DOC_PATH_BASE//\// })
	DOC_TYPE="$${_DOC_PATH_ARRAY[0]}"
	DOC_RECIPIENT="$${_DOC_PATH_ARRAY[1]}"
	DOC_NAME="$${_DOC_PATH_ARRAY[2]}"
	if [ -f "$(J2_MD_DIR)/$${DOC_TYPE}/whateverany.tex" ]; then
	  PANDOC_TEX="$(J2_MD_DIR)/$${DOC_TYPE}/whateverany.tex"
	else
	  PANDOC_TEX="$(J2_MD_DIR)/whateverany.tex"
	fi
	PANDOC_LUA="$(J2_MD_DIR)/whateverany.lua"
	case "$${DOC_TYPE}" in \
	dummy_example) PANDOC_ENGINE="xelatex" ;;
	*) PANDOC_ENGINE="lualatex" ;;
	esac
	export DOC_NAME DOC_RECIPIENT DOC_TYPE FILE_VERSION PANDOC_ENGINE PANDOC_LUA PANDOC_TEX
endef

define EXTRACT_METADATA
	export X_JSON_OUT="$$($(EXIFTOOL) -j "$${SIGNED_FILE}")"
	export X_OUT_THUMBPRINT="$$($(JQ) -r '.[0].UserComment | fromjson | .thumbprint'<<<"$${X_JSON_OUT}")"
	export X_OUT_B2SUM="$$(     $(JQ) -r '.[0].UserComment | fromjson | .b2sum'     <<<"$${X_JSON_OUT}")"
	export X_OUT_DATA="$$(      $(JQ) -r '.[0].UserComment | fromjson | .data'      <<<"$${X_JSON_OUT}")"
	export X_IN_JSON="$$($(BASE64) -w0 -d <<<"$${X_OUT_DATA}" | \
	    $(OPENSSL) cms \
	      -decrypt \
	      -inform DER \
	      -in /dev/stdin \
	      -CAfile "$(TMP_HOME_CA_CERT)" \
	      -recip "$(TMP_DOCME_CRYPT_CERT)" \
	      -inkey "$(TMP_DOCME_CRYPT_KEY)")"
	export X_DOC_AUTHOR="$$(             $(JQ) -r '.DOC_AUTHOR'              <<<"$${X_IN_JSON}")"
	export X_DOC_REPO="$$(               $(JQ) -r '.DOC_REPO'                <<<"$${X_IN_JSON}")"
	export X_DOC_ORIGINAL_B2SUM="$$(     $(JQ) -r '.DOC_ORIGINAL_B2SUM'      <<<"$${X_IN_JSON}")"
	export X_DOC_ORIGINAL_THUMBPRINT="$$($(JQ) -r '.DOC_ORIGINAL_THUMBPRINT' <<<"$${X_IN_JSON}")"
	export X_DOC_RECIPIENT="$$(          $(JQ) -r '.DOC_RECIPIENT'           <<<"$${X_IN_JSON}")"
	export X_FILE_SIG="$$(               $(JQ) -r '.FILE_SIG'                <<<"$${X_IN_JSON}")"
	export X_FILE_VERSION="$$(           $(JQ) -r '.FILE_VERSION'            <<<"$${X_IN_JSON}")"
	export X_LOG_ENTRY_TIME="$$(         $(JQ) -r '.LOG_ENTRY_TIME'          <<<"$${X_IN_JSON}")"
	export X_PDF_FILE="$$(               $(JQ) -r '.PDF_FILE'                <<<"$${X_IN_JSON}")"
	export X_SIGNED_FILE="$$(            $(JQ) -r '.SIGNED_FILE'             <<<"$${X_IN_JSON}")"
endef

### # ----------------------
### # version history
### # ----------------------
VERSION_DIR        := $(DOCS_DIR)/versions
VERSION_FILES      := $(patsubst $(J2_MD_DIR)/%.md.j2,$(VERSION_DIR)/%.md.version,$(J2_MD_FILES))

.PHONY: _pandoc-version
_pandoc-version: $(VERSION_FILES)
	@$(PANDOC_DEBUG_CMD)

.PHONY: _pandoc-clean-version
_pandoc-clean-version:
	@$(PANDOC_DEBUG_CMD)
	$(RM) $(VERSION_FILES)

$(VERSION_DIR)/%.md.version: $(J2_MD_DIR)/%.md.j2
	@$(PANDOC_DEBUG_CMD)
	mkdir -p $(dir $@)
	VERSION_FILE="$@"
	CURRENT_VERSION="$$(git rev-parse --short HEAD -- "$<")"
	read -r FILE_VERSION 2>/dev/null <"$${VERSION_FILE}"
	if [ "$${CURRENT_VERSION}" != "$${FILE_VERSION}" ]; then \
		echo "$${CURRENT_VERSION}" > "$@"
	fi

### # ----------------------
### # Jinja2 > source
### # ----------------------
MD_DIR           := $(DOCS_DIR)/md
MD_FILES         := $(patsubst $(VERSION_DIR)/%.md.version,$(MD_DIR)/%.md,$(VERSION_FILES))

.PHONY: _pandoc-md
_pandoc-md: $(MD_FILES)
	@$(PANDOC_DEBUG_CMD)

.PHONY: _pandoc-clean-md
_pandoc-clean-md:
	@$(PANDOC_DEBUG_CMD)
	$(RM) $(MD_FILES)

$(MD_DIR)/%.md: $(J2_MD_DIR)/%.md.j2 $(VERSION_DIR)/%.md.version
	@$(PANDOC_DEBUG_CMD)
	mkdir -p $(dir $@)
	J2_MD_FILE="$(filter $(J2_MD_DIR)/%.md.j2, $^)"
	VERSION_FILE="$(filter $(VERSION_DIR)/%.md.version, $^)"
	$(call DOC_METADATA,$${VERSION_FILE})
	$(J2) \
	  -D DOC_AUTHOR="$(DOC_AUTHOR)" \
	  -D DOC_RECIPIENT="$${DOC_RECIPIENT}" \
	  -D DOC_REPO="$(DOC_REPO)" \
	  -D DOC_SRC="$(@F)" \
	  -D DOC_TYPE="$${DOC_TYPE}" \
	  -D DOC_VERSION="$${FILE_VERSION}" \
	  -o "$@" "$${J2_MD_FILE}"
	echo "INFO: J2_MD_FILE=$<"
	echo "INFO: MD_FILE=$@"

### # ----------------------
### # pandoc > TXT
### # ----------------------
TXT_DIR          := $(DOCS_DIR)/txt
TXT_FILES        := $(patsubst $(MD_DIR)/%.md,$(TXT_DIR)/%.txt,$(MD_FILES))

.PHONY: _pandoc-txt
_pandoc-txt: $(TXT_FILES)
	@$(PANDOC_DEBUG_CMD)

.PHONY: _pandoc-clean-txt
_pandoc-clean-txt:
	@$(PANDOC_DEBUG_CMD)
	$(RM) $(TXT_FILES)

$(TXT_DIR)/%.txt: $(MD_DIR)/%.md $(VERSION_DIR)/%.md.version
	@$(PANDOC_DEBUG_CMD)
	mkdir -p $(dir $@)
	MD_FILE="$(filter $(MD_DIR)/%.md, $^)"
	VERSION_FILE="$(filter $(VERSION_DIR)/%.md.version, $^)"
	$(call DOC_METADATA,$${VERSION_FILE})
	$(PANDOC) \
	  -t plain \
		"$${MD_FILE}" \
		-o "$@"
	echo "INFO: TXT_FILE=$@"
	

### # ----------------------
### # pandoc > TEX
### # ----------------------
TEX_DIR          := $(DOCS_DIR)/tex
TEX_FILES        := $(patsubst $(MD_DIR)/%.md,$(TEX_DIR)/%.tex,$(MD_FILES))

.PHONY: _pandoc-tex
_pandoc-tex: $(TEX_FILES)
	@$(PANDOC_DEBUG_CMD)

.PHONY: _pandoc-clean-tex
_pandoc-clean-tex:
	@$(PANDOC_DEBUG_CMD)
	$(RM) $(TEX_FILES)

$(TEX_DIR)/%.tex: $(MD_DIR)/%.md $(VERSION_DIR)/%.md.version $(PANDOC_LUA)
	@$(PANDOC_DEBUG_CMD)
	$(PANDOC_DEBUG_CMD)
	mkdir -p $(dir $@)
	MD_FILE="$(filter $(MD_DIR)/%.md, $^)"
	VERSION_FILE="$(filter $(VERSION_DIR)/%.md.version, $^)"
	$(call DOC_METADATA,$${VERSION_FILE})
	$(PANDOC) \
	  --lua-filter="$${PANDOC_LUA}" \
	  --pdf-engine="$${PANDOC_ENGINE}" \
	  --template="$${PANDOC_TEX}" \
	  "$${MD_FILE}" \
		-o "$@"
	echo "INFO: TEX_FILE=$@"

### # ----------------------
### # pandoc > PDF
### # ----------------------
PDF_DIR          := $(DOCS_DIR)/unsigned-pdf
PDF_FILES        := $(patsubst $(MD_DIR)/%.md,$(PDF_DIR)/%.pdf,$(MD_FILES))

.PHONY: _pandoc-pdf
_pandoc-pdf: $(PDF_FILES)
	@$(PANDOC_DEBUG_CMD)

.PHONY: _pandoc-clean-pdf
_pandoc-clean-pdf:
	@$(PANDOC_DEBUG_CMD)
	$(RM) $(PDF_FILES)

$(PDF_DIR)/%.pdf: $(MD_DIR)/%.md $(VERSION_DIR)/%.md.version $(PANDOC_LUA)
	@$(PANDOC_DEBUG_CMD)
	mkdir -p $(dir $@)
	MD_FILE="$(filter $(MD_DIR)/%.md, $^)"
	VERSION_FILE="$(filter $(VERSION_DIR)/%.md.version, $^)"
	$(call DOC_METADATA,$${VERSION_FILE})
	$(PANDOC) \
	  --lua-filter="$${PANDOC_LUA}" \
	  --pdf-engine="$${PANDOC_ENGINE}" \
	  --template="$${PANDOC_TEX}" \
		"$${MD_FILE}" \
	  -o "$@"
	echo "INFO: UNSIGNED_PDF_FILE=$@"

### # ----------------------
### # .sig files from PDF's
### # ----------------------
SIG_DIR          := $(DOCS_DIR)/sigs
SIG_FILES        := $(patsubst $(PDF_DIR)/%.pdf,$(SIG_DIR)/%.pdf.sig,$(PDF_FILES))

.PHONY: _pandoc-sig
_pandoc-sig: $(SIG_FILES)
	@$(PANDOC_DEBUG_CMD)

.PHONY: _pandoc-clean-sig
_pandoc-clean-sig:
	@$(PANDOC_DEBUG_CMD)
	$(RM) $(SIG_FILES)

$(SIG_DIR)/%.pdf.sig: $(PDF_DIR)/%.pdf $(VERSION_DIR)/%.md.version $(TMP_CERT_FILES)
	@$(PANDOC_DEBUG_CMD)
	mkdir -p $(dir $@)
	PDF_FILE="$(filter $(PDF_DIR)/%.pdf, $^)"
	VERSION_FILE="$(filter $(VERSION_DIR)/%.md.version, $^)"
	$(call DOC_METADATA,$${VERSION_FILE})
	$(OPENSSL) cms \
	  -sign \
	  -signer "$(TMP_DOCME_SIGN_CERT)" \
	  -inkey "$(TMP_DOCME_SIGN_KEY)" \
	  -certfile "$(TMP_DOCME_CA_CERT)" \
	  -CAfile "$(TMP_HOME_CA_CERT)" \
	  -binary -outform DER -in "$${PDF_FILE}" | \
	    $(BASE64) -w0 >"$@"
	echo "INFO: SIG_FILE=$@"

### # ----------------------
### # Final signed PDFs
### # ----------------------
SIGNED_DIR       := $(DOCS_DIR)/pdf
SIGNED_FILES     := $(patsubst $(SIG_DIR)/%.pdf.sig,$(SIGNED_DIR)/%.pdf,$(SIG_FILES))

.PHONY: _pandoc-signed_pdf
_pandoc-signed_pdf: $(SIGNED_FILES)
	@$(PANDOC_DEBUG_CMD)

.PHONY: _pandoc-clean-signed_pdf
_pandoc-clean-signed_pdf:
	@$(PANDOC_DEBUG_CMD)
	$(RM) $(SIGNED_FILES)

$(SIGNED_DIR)/%.pdf: $(SIG_DIR)/%.pdf.sig $(PDF_DIR)/%.pdf $(VERSION_DIR)/%.md.version $(TMP_CERT_FILES)
	@$(PANDOC_DEBUG_CMD)
	mkdir -p $(dir $@)
	SIG_FILE="$(filter $(SIG_DIR)/%.pdf.sig, $^)"
	VERSION_FILE="$(filter $(VERSION_DIR)/%.md.version, $^)"
	$(call DOC_METADATA,$${VERSION_FILE})
	SIGNED_FILE="$@"
	PDF_FILE="$(filter $(PDF_DIR)/%.pdf, $^)"
	PDF_FILE_NAME="$(notdir $(filter $(PDF_DIR)/%.pdf, $^))"
	read -r FILE_SIG < "$${SIG_FILE}"
	DOC_ORIGINAL_B2SUM="$$($(B2SUM) "$${PDF_FILE}" | cut -d' ' -f1)"
	DOC_ORIGINAL_THUMBPRINT="$${DOC_ORIGINAL_B2SUM:0:16}"
	METADATA_IN_JSON=$$($(JQ) -j -c -n \
	  --arg DOC_AUTHOR "$(DOC_AUTHOR)" \
	  --arg DOC_ORIGINAL_B2SUM "$${DOC_ORIGINAL_B2SUM}" \
	  --arg DOC_ORIGINAL_THUMBPRINT "$${DOC_ORIGINAL_THUMBPRINT}" \
	  --arg DOC_RECIPIENT "$${DOC_RECIPIENT}" \
	  --arg DOC_REPO "$(DOC_REPO)" \
	  --arg FILE_SIG "$${FILE_SIG}" \
	  --arg FILE_VERSION "$${FILE_VERSION}" \
	  --arg LOG_ENTRY_TIME "$(LOG_ENTRY_TIME)" \
	  --arg PDF_FILE "$${PDF_FILE}" \
	  --arg SIGNED_FILE "$${SIGNED_FILE}" \
	  '{"DOC_AUTHOR":$$DOC_AUTHOR,"DOC_ORIGINAL_B2SUM":$$DOC_ORIGINAL_B2SUM,"DOC_ORIGINAL_THUMBPRINT":$$DOC_ORIGINAL_THUMBPRINT,"DOC_RECIPIENT":$$DOC_RECIPIENT,"DOC_REPO":$$DOC_REPO,"FILE_SIG":$$FILE_SIG,"FILE_VERSION":$$FILE_VERSION,"LOG_ENTRY_TIME":$$LOG_ENTRY_TIME,"PDF_FILE":$$PDF_FILE,"SIGNED_FILE":$$SIGNED_FILE}')
	METADATA_IN_ENCRYPTED_DATA=$$( \
	  printf '%s' "$${METADATA_IN_JSON}" | \
	  $(OPENSSL) cms -encrypt -outform DER \
	    -CAfile "$(TMP_HOME_CA_CERT)" \
	    "$(TMP_DOCME_CRYPT_CERT)" | \
	  $(BASE64) -w0 )
	METADATA_IN_ENCRYPTED_B2SUM="$$($(B2SUM) <<<"$${METADATA_IN_ENCRYPTED_DATA}" | cut -d' ' -f1)"
	METADATA_IN_ENCRYPTED_THUMBPRINT="$${METADATA_IN_ENCRYPTED_B2SUM:0:16}"
	METADATA_OUT_JSON=$$($(JQ) -j -c -n \
	  --arg thumbprint "$${METADATA_IN_ENCRYPTED_THUMBPRINT}" \
	  --arg b2sum "$${METADATA_IN_ENCRYPTED_B2SUM}" \
	  --arg data "$${METADATA_IN_ENCRYPTED_DATA}" \
	  '{"thumbprint":$$thumbprint,"b2sum":$$b2sum,"data":$$data}')
	$(RM) "$@"
	$(EXIFTOOL) -q \
		-Keywords="md, pandoc, LuaLaTeX, $${PDF_FILE_NAME}, $${FILE_VERSION}, $${DOC_RECIPIENT}" \
	  -UserComment="$$(printf '%s' "$${METADATA_OUT_JSON}")" \
	  -o "$@" "$${PDF_FILE}"
	echo "INFO: PDF_FILE=$@"

### # ----------------------
### # Log audit metadata
### # ----------------------
LOG_DIR        := $(DOCS_DIR)/logs
LOG_FILES      := $(patsubst $(SIGNED_DIR)/%.pdf,$(LOG_DIR)/%.log,$(SIGNED_FILES))
LOG_AUDIT_FILE ?= $(LOG_DIR)/recipient_git_crypt_sign_inventory.txt

.PHONY: _pandoc-log
_pandoc-log: $(LOG_FILES)

$(LOG_DIR)/%.log: $(SIGNED_DIR)/%.pdf $(SIG_DIR)/%.pdf.sig $(VERSION_DIR)/%.md.version
	@$(PANDOC_DEBUG_CMD)
	mkdir -p $(dir $@)
	SIGNED_FILE="$(filter $(SIGNED_DIR)/%.pdf, $^)"
	VERSION_FILE="$(filter $(VERSION_DIR)/%.md.version, $^)"
	$(call DOC_METADATA,$${VERSION_FILE})
	SIG_FILE="$(filter $(SIG_DIR)/%.pdf.sig, $^)"
	$(EXTRACT_METADATA)
	if [ ! -f "$(LOG_AUDIT_FILE)" ]; then \
		echo -e "Timestamp________________\tVersion\tMetaThumbprint__\tFileThumbprint__\tDocument File" >> "$(LOG_AUDIT_FILE)"
	fi
	echo -e "$${X_LOG_ENTRY_TIME}\t$${X_FILE_VERSION}\t$${X_OUT_THUMBPRINT}\t$${X_DOC_ORIGINAL_THUMBPRINT}\t$${X_PDF_FILE}" >> "$(LOG_AUDIT_FILE)"
	touch "$@"

### # ----------------------
### # Verify Signed docs
### # ----------------------
VERIFY_DIR     := $(DOCS_DIR)/verify
VERIFY_FILES   := $(patsubst $(SIG_DIR)/%.pdf.sig,$(VERIFY_DIR)/%.verify,$(SIG_FILES))

.PHONY: _pandoc-verify
_pandoc-verify: $(VERIFY_FILES)

.PHONY: _pandoc-clean-verify
_pandoc-clean-verify:
	@$(RM) $(VERIFY_FILES)

$(VERIFY_DIR)/%.verify: $(SIG_DIR)/%.pdf.sig $(PDF_DIR)/%.pdf $(VERSION_DIR)/%.md.version $(TMP_CERT_FILES)
	@$(PANDOC_DEBUG_CMD)
	mkdir -p $(dir $@)
	SIG_FILE="$(filter $(SIG_DIR)/%.pdf.sig, $^)"
	VERSION_FILE="$(filter $(VERSION_DIR)/%.md.version, $^)"
	$(call DOC_METADATA,$${VERSION_FILE})
	PDF_FILE="$(filter $(PDF_DIR)/%.pdf, $^)"
	echo "INFO: SIG_FILE=$${SIG_FILE}"
	echo "INFO: PDF_FILE=$${PDF_FILE}"
	$(BASE64) \
	  -w0 \
	  -d <"$${SIG_FILE}" | \
	    $(OPENSSL) cms \
	      -verify \
	      -inform DER \
	      -binary \
	      -in /dev/stdin \
	      -content "$${PDF_FILE}" \
	      -CAfile "$(TMP_HOME_CA_CERT)" \
	      -out /dev/null

### # ----------------------
### # Get signed doc info
### # ----------------------
INFO_DIR       := $(DOCS_DIR)/info
INFO_FILES     := $(patsubst $(SIGNED_DIR)/%.pdf,$(INFO_DIR)/%.info,$(SIGNED_FILES))

.PHONY: _pandoc-info
_pandoc-info: $(INFO_FILES)

.PHONY: _pandoc-clean-info
_pandoc-clean-info:
	@$(RM) $(INFO_FILES)

$(INFO_DIR)/%.info: $(SIGNED_DIR)/%.pdf $(SIG_DIR)/%.pdf.sig $(PDF_DIR)/%.pdf $(VERSION_DIR)/%.md.version $(TMP_CERT_FILES)
	@$(PANDOC_DEBUG_CMD)
	mkdir -p $(dir $@)
	SIGNED_FILE="$(filter $(SIGNED_DIR)/%.pdf, $^)"
	VERSION_FILE="$(filter $(VERSION_DIR)/%.md.version, $^)"
	$(call DOC_METADATA,$${VERSION_FILE})
	SIG_FILE="$(filter $(SIG_DIR)/%.pdf.sig, $^)"
	PDF_FILE="$(filter $(PDF_DIR)/%.pdf, $^)"
	echo "INFO: SIGNED_FILE=$${SIGNED_FILE}"
	echo "INFO: SIG_FILE=$${SIG_FILE}"
	echo "INFO: PDF_FILE=$${PDF_FILE}"
	$(EXTRACT_METADATA)
	echo "INFO: X_DOC_AUTHOR=$${X_DOC_AUTHOR}"
	echo "INFO: X_DOC_ORIGINAL_B2SUM=$${X_DOC_ORIGINAL_B2SUM}"
	echo "INFO: X_DOC_ORIGINAL_THUMBPRINT=$${X_DOC_ORIGINAL_THUMBPRINT}"
	echo "INFO: X_DOC_RECIPIENT=$${X_DOC_RECIPIENT}"
	echo "INFO: X_DOC_REPO=$${X_DOC_REPO}"
	echo "INFO: X_FILE_SIG=$${X_FILE_SIG}" | $(DATA_CLEAN)
	echo "INFO: X_FILE_VERSION=$${X_FILE_VERSION}"
	echo "INFO: X_LOG_ENTRY_TIME=$${X_LOG_ENTRY_TIME}"
	echo "INFO: X_OUT_B2SUM=$${X_OUT_B2SUM}"
	echo "INFO: X_OUT_DATA=$${X_OUT_DATA}" | $(DATA_CLEAN)
	echo "INFO: X_OUT_THUMBPRINT=$${X_OUT_THUMBPRINT}"
	echo "INFO: X_PDF_FILE=$${X_PDF_FILE}"
	echo "INFO: X_SIGNED_FILE=$${X_SIGNED_FILE}"
	read -r X_SIG_FILE_SIGNATURE < "$${SIG_FILE}"
	echo "INFO: X_SIG_FILE_SIGNATURE=$${X_SIG_FILE_SIGNATURE}" | $(DATA_CLEAN)

# Aggregate targets
.PHONY: _pandoc-src
_pandoc-src: _pandoc-version _pandoc-md
	@$(PANDOC_DEBUG_CMD)

.PHONY: _pandoc-docs
_pandoc-docs: _pandoc-txt _pandoc-tex _pandoc-pdf _pandoc-sig _pandoc-signed_pdf _pandoc-log
	@$(PANDOC_DEBUG_CMD)

.PHONY: _pandoc-clean-docs
_pandoc-clean-docs: _pandoc-clean-txt _pandoc-clean-tex _pandoc-clean-pdf _pandoc-clean-sig _pandoc-clean-signed_pdf
	@$(PANDOC_DEBUG_CMD)

.PHONY: _pandoc-pristine
_pandoc-pristine: _pandoc-clean _pandoc-clean-version _pandoc-clean-verify _pandoc-clean-info
	@$(PANDOC_DEBUG_CMD)

.PHONY: _pandoc-run
_pandoc-run:
	@$(PANDOC_DEBUG_CMD)
	/bin/bash -c echo "SERVICE_TASK_ARG=$(SERVICE_TASK_ARG)"

.PHONY: _pandoc-all
_pandoc-all: _pandoc-src _pandoc-docs
	@$(PANDOC_DEBUG_CMD)

.PHONY: _pandoc-clean
_pandoc-clean: _pandoc-clean-md _pandoc-clean-docs _pandoc-clean-certs
	@$(PANDOC_DEBUG_CMD)

.PHONY: _pandoc-shell
_pandoc-shell:
	@$(PANDOC_DEBUG_CMD)
	SHELL="$(SHELL)" $(SHELL)

.PHONY: _pandoc-shell-%
_pandoc-shell-%: _pandoc-shell
	@$(PANDOC_DEBUG_CMD)

.PHONY: _pandoc-usage
_pandoc-usage:
	@$(PANDOC_DEBUG_CMD)
	echo "$(PANDOC_USAGE)"

.PHONY: _pandoc-test _pandoc-test-arg1 _pandoc-test-arg1-arg2
_pandoc-test _pandoc-test-arg1 _pandoc-test-arg1-arg2 data/pandoc/test data/pandoc/test-arg1 data/pandoc/test-arg1-arg2:
	@$(eval $(call TARGET_INIT_FN,$@))
	$(PANDOC_DEBUG_CMD)
	echo "TARGET_RAW=$(TARGET_RAW),TARGET_TYPE=$(TARGET_TYPE),SERVICE=$(SERVICE),SERVICE_TASK=$(SERVICE_TASK),SERVICE_TASK_ARGS=$(SERVICE_TASK_ARGS)"
	if [ "$(TARGET_TYPE)" = "data" ]; then
	  mkdir -p $(dir $@)
	  touch "$@"
	fi

endif # SERVICE

# --- Build Rules (on HOST) ---
else # INSIDE_PANDOC_OCI
.PHONY: ~pandoc-usage
~pandoc-usage:
	@$(PANDOC_DEBUG_CMD)
	echo "$(PANDOC_USAGE)"

.PHONY: ~pandoc-test ~pandoc-test-arg1 ~pandoc-test-arg1-arg2
~pandoc-test ~pandoc-test-arg1 ~pandoc-test-arg1-arg2:
	@$(eval $(call TARGET_INIT_FN,$@))
	$(PANDOC_DEBUG_CMD)
	echo "TARGET_RAW=$(TARGET_RAW),TARGET_TYPE=$(TARGET_TYPE),SERVICE=$(SERVICE),SERVICE_TASK=$(SERVICE_TASK),SERVICE_TASK_ARGS=$(SERVICE_TASK_ARGS)"

endif # INSIDE_PANDOC_OCI

endif # PANDOC_MK
