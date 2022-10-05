APP?=my-service
VERSION?=$(shell git describe --tag --always --dirty)
COMMIT_HASH?=$(shell git rev-parse --short HEAD)
BUILD_OUTPUT?=/tmp/${APP}
GO?=go
GOVERSION?=1.19.1
GOLANGCI_LINT_VERSION?=latest
CI_GOLANGCI_LINT_VERSION?=v1.50.0

ENV?=development
PORT?=8080

GOOGLE_APPLICATION_CREDENTIALS=${HOME}/.config/gcloud/application_default_credentials.json


-include .env

.EXPORT_ALL_VARIABLES: local-run


# === CI steps begin ===
.PHONY: check
check: ci-check

.PHONY: build
build: go-build

.PHONY: unit-test
unit-test: test

.PHONY: integration-test
integration-test:
	@echo "integration-test is not implemented"

.PHONY: package
package: VERSION=$(if ${TAG_NAME},${TAG_NAME},${COMMIT_HASH})
package: version docker-build
ifneq (${TAG_NAME},)
	docker tag ${DOCKER_IMAGE} ${DOCKER_IMAGE_NAME}:${COMMIT_HASH}
endif
ifeq (${BRANCH_NAME},master)
	docker tag ${DOCKER_IMAGE} ${DOCKER_IMAGE_NAME}:latest
	docker push ${DOCKER_IMAGE_NAME}:latest
endif
# === CI steps end ===


version:
	@ echo "Version:" ${VERSION}
	@ echo "Commit hash:" ${COMMIT_HASH}

go-build:
	${GO} build -mod=vendor -o ${BUILD_OUTPUT} \
		-ldflags "-X main.version=${VERSION} -X main.commit=${COMMIT_HASH}" \
		cmd/${APP}/main.go

test:
	${GO} test -mod=vendor -cover -race ./...

lint: lint-golangci lint-nargs

lint-golangci-install:
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@${GOLANGCI_LINT_VERSION}

lint-golangci:
	GOFLAGS=-mod=vendor golangci-lint run ./... --timeout 5m

lint-nargs-install:
	GO111MODULE=off ${GO} get -u github.com/alexkohler/nargs/cmd/nargs

lint-nargs:
	GOPRIVATE=github.com/upcload ${GO} list ./... | grep -v /goag/ | xargs -L1 nargs -receivers

ci-lint: GOLANGCI_LINT_VERSION=${CI_GOLANGCI_LINT_VERSION}
ci-lint: lint-golangci-install lint-nargs-install lint

ci-check: ci-lint go-mod-vendor codegen-install codegen-gen update-readme
	$(call check-git-diff-is-clean)

pre-push-checks: go-mod-vendor codegen-gen build test lint update-readme
	$(call check-git-diff-is-clean)


DOCKER_IMAGE_NAME?=${APP}
TAG_NAME?=latest
DOCKER_IMAGE?=${DOCKER_IMAGE_NAME}:${VERSION}
DOCKER_IMAGE_LATEST?=${DOCKER_IMAGE_NAME}:latest

# check if 'docker' command is exists
ifneq (,$(shell which docker))
# check if latest image exists
ifeq (0,$(shell docker image inspect ${DOCKER_IMAGE_LATEST} 2>/dev/null 1>&2; echo $$?))
	DOCKER_IMAGE_CACHE_FROM?=--cache-from ${DOCKER_IMAGE_LATEST}
endif
endif

docker-build:
	docker build -t ${DOCKER_IMAGE} \
		${DOCKER_IMAGE_CACHE_FROM} \
		--build-arg _VERSION=${VERSION} \
		$(if ${GOVERSION},--build-arg _GOVERSION=${GOVERSION},) \
		.

docker-run:
	docker run --rm -it \
		-e ENV=${ENV} \
		-e GOOGLE_APPLICATION_CREDENTIALS=/gcloud/application_default_credentials.json \
		-v ~/.config/gcloud:/gcloud \
		-p 9001:8080 ${DOCKER_IMAGE}

local-run:
	${GO} run cmd/${APP}/main.go

go-mod-vendor:
	${GO} mod tidy
	${GO} mod vendor

update-readme: TMP_FILE=readme_new.md
update-readme: START_LINE=\[cmd-output\]: \# \(PRINT HELP\)
update-readme: END_LINE=\[cmd-output\]: \# \(END\)
update-readme: START_LINE_TEXT=$(shell echo "${START_LINE}" | sed -r 's/\\//g')
update-readme: END_LINE_TEXT=$(shell echo "${END_LINE}" | sed -r 's/\\//g')
update-readme:
	@ grep -F -q "${START_LINE_TEXT}" README.md || (echo "README.md should contain line: ${START_LINE_TEXT}" && exit 1)
	@ grep -F -q "${END_LINE_TEXT}" README.md || (echo "README.md should contain line: ${END_LINE_TEXT}" && exit 1)
	cat README.md | sed -r '/${START_LINE}$$/q' > ${TMP_FILE}
	@ echo "" >> ${TMP_FILE}
	${GO} run cmd/stylefinder-api/main.go -h >> ${TMP_FILE}
	@ echo "" >> ${TMP_FILE}
	cat README.md | sed -r -n '/${END_LINE}$$/,$$ p' >> ${TMP_FILE}
	@ cp -f ${TMP_FILE} README.md
	@ rm ${TMP_FILE}

codegen-gen:
	goag --file openapi.yaml --out goag -package goag

codegen-install:
	${GO} install github.com/vkd/goag/cmd/goag@latest

# $(shell git tag --sort=-creatordate | grep -E '^v\d+\.\d+\.\d+$' | head -1 | awk -F. -v OFS=. '{\$NF++;print}')
next-tag:
	NEXT_TAG=234 echo $$NEXT_TAG && git tag $$NEXT_TAG

define required-var
	@ [ "${$(1)}" ] || (echo "USAGE: 'make $(MAKECMDGOALS) $(1)=<value> $(MAKEFLAGS)': $(1) var is required"; exit 1)
endef

define check-git-diff-is-clean
	@ git diff --exit-code || (echo "Error: git diff is not clean - try to run 'make $@' locally and commit all necessary changes" && exit 2)
endef
