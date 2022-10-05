# This super set of usefull makefile tricks
# ===========================

# .PHONY: test
# test:
# 	[ "$(shell make cmd-with-args filename1)" ] || (echo "Oh" && exit 1)
# 	@ echo "ok"

# --------------------------------------------------------
# [DOESN'T WORK] pass arguments throught make targets
# potential solution - reverse order of targets
# --------------------------------------------------------
# works:
# - make cmd-with-args filename1
# known issues:
# - make cmd-with-args --color=red
# - make cmd-with-args -a
cmd-with-args:
	@ echo "cmd args->" $(filter-out $@,$(MAKECMDGOALS))

# this wildcard's target of doing nothing
# to be able to pass args like `make import arg1 arg2`
%:
	@:
# --------------------------------------------------------


# --------------------------------------------------------
# yes\no question to stop target
# --------------------------------------------------------
yesno:
	@ ( read -p "Are you sure? [y/N]: " sure && case "$$sure" in [yY]) true;; *) false;; esac )

destroy: yesno
	@ echo "DESTROY"
# --------------------------------------------------------


# --------------------------------------------------------
# confirm target, like yes/no
# --------------------------------------------------------
.PHONY: confirm
confirm:
	@ bash -c 'read -p "Are you sure(y/N)? " -n 1 -r && [[ "$$REPLY" =~ ^[Yy]$$ ]] || (echo -e "\ndeployment cancelled\n";false)'
	@ echo ""
# --------------------------------------------------------



# --------------------------------------------------------
# "switch" operator by variable
# --------------------------------------------------------
ifeq ($(ENV),staging)
KUBE_CONTEXT?=staging_instance
endif
ifeq ($(ENV),production)
KUBE_CONTEXT?=production_instance
endif
# --------------------------------------------------------



# --------------------------------------------------------
# run the same target by for-loop, like "make cmd ARG=1, make cmd ARG=2, ... make cmd ARG=20
# --------------------------------------------------------
NUM_STAGING := 20
STAGINGS := $(shell seq 1 ${NUM_STAGING})
STAGE_UPGRADE_JOBS := $(addprefix stage-upgrade-,${STAGINGS})
.PHONY: stage-upgrade-all ${STAGE_UPGRADE_JOBS}
stage-upgrade-all: ${STAGE_UPGRADE_JOBS}
	@ echo "$@ success"

${STAGE_UPGRADE_JOBS}: stage-upgrade-%:
	$(MAKE) stage-upgrade STAGE=$* || echo "Skipped STAGE=$*"
# --------------------------------------------------------



# --------------------------------------------------------
# export ENV variables from file
# - but doesn't export ENV from Makefile
# --------------------------------------------------------
DOESNT_BE_EXPORTED?=xxx

-include .env

export_env_vars:
	$(eval export $(shell sed -ne 's/ *#.*$$//; /./ s/=.*$$// p' .env))

local-run: export_env_vars
	${GOBINARY} run cmd/${APP}/main.go
# --------------------------------------------------------


# --------------------------------------------------------
# check required var
# --------------------------------------------------------
define required-var
	@ [ "${$(1)}" ] || (echo "USAGE: 'make $(MAKECMDGOALS) $(1)=<value> $(MAKEFLAGS)': $(1) var is required"; exit 1)
endef

my_target:
	@ $(call required-var,SHOP)
# --------------------------------------------------------



# --------------------------------------------------------
# commit hash and version
# --------------------------------------------------------
VERSION?=$(shell git describe --tag --always --dirty)
COMMIT_HASH?=$(shell git rev-parse --short HEAD)
# --------------------------------------------------------

# --------------------------------------------------------
# check if docker command exists
# --------------------------------------------------------
ifneq (,$(shell which docker))
# check if latest image exists
ifeq (0,$(shell docker image inspect ${DOCKER_IMAGE_LATEST} 2>/dev/null 1>&2; echo $$?))
	DOCKER_IMAGE_CACHE_FROM?=--cache-from ${DOCKER_IMAGE_LATEST}
endif
endif

# install if not exists
gen-go:
ifeq (,$(shell which buf))
	GOFLAGS= go install github.com/bufbuild/buf/cmd/buf@latest
endif
# --------------------------------------------------------


# --------------------------------------------------------
# check if terraform version is matched
# --------------------------------------------------------
TF_CMD=terraform
# check if 'terraform' command is exists
ifneq (v${TF_VERSION},$(shell command -v ${TF_CMD} &> /dev/null && ${TF_CMD} version | head -1 | cut -d " " -f 2))
# -e GOOGLE_APPLICATION_CREDENTIALS=/gcloud/application_default_credentials.json
# -v ~/.config/gcloud:/gcloud
TF_CMD=docker run -ti --rm \
	-v ~/.config/gcloud:/root/.config/gcloud \
	-v $(shell pwd):/terraform \
	-w /terraform \
	hashicorp/terraform:${TF_VERSION}
endif
# --------------------------------------------------------


# --------------------------------------------------------
# get ENV values by prefix
# --------------------------------------------------------
$(foreach v, $(filter TF_VAR_%,$(.VARIABLES)),--env $(v)=${$(v)})
# --------------------------------------------------------



# --------------------------------------------------------
# check versions
# --------------------------------------------------------
ci-check-versions:
	[ "${NANCY_VERSION}" = "$(shell curl -Ls -o /dev/null -w %{url_effective} https://github.com/sonatype-nexus-community/nancy/releases/latest/download | cut -c 69-)" ] && echo "equals" || echo "not equals"

# 2

define check-version
	@ [ "$(1)" = "$(2)" ] || (echo "[nancy:$(1)] A new release is available ($(2)): $(3)" && false)
endef

ci-check-versions:
	@ $(call check-version,${NANCY_VERSION},$(shell curl -Ls -o /dev/null -w %{url_effective} https://github.com/sonatype-nexus-community/nancy/releases/latest/download | cut -c 69-),https://github.com/sonatype-nexus-community/nancy/releases/)

# 3

define check-version
	@ [ "$(2)" = "$(3)" ] || (echo "[$(1):$(2)] A new release is available ($(3)): $(4)" && false)
endef

define check-github-release-version
	$(call check-version,$(1),$(2),$(shell curl -Ls -o /dev/null -w %{url_effective} $(3)/releases/latest/download | cut -c $(shell echo -n "$(3)"| awk '{print length}')- | cut -c 18- ),$(3)/releases/)
endef

ci-check-versions:
	$(call check-github-release-version,golangci-lint,${CI_GOLANGCI_LINT_VERSION},https://github.com/golangci/golangci-lint)
	$(call check-github-release-version,nancy,${NANCY_VERSION},https://github.com/sonatype-nexus-community/nancy)

# --------------------------------------------------------









# --------------------------------------------------------
# DRAFT
# --------------------------------------------------------
target1 := file1

$(target1):
    @echo "Hello from $@"

variable-%:
    $(MAKE) $($*)
gives

$ make variable-target1
make file1
Hello from file1
# --------------------------------------------------------
