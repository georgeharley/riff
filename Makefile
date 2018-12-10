.PHONY: build clean test all release gen-mocks check-mockery verify-docs clean-docs

ISWIN:=
ifeq ($(OS),Windows_NT)
	ISWIN=true
    OUTPUT = .\riff
    OUTPUT_EXT = .exe
	VERSION = $(shell type VERSION)
	GITDIRTY = $(shell git diff --quiet HEAD || echo dirty)
	GOBIN = $(shell go env GOPATH)\bin
	MOCKERY_CHECK_CMD = where mockery > NUL || (echo mockery not found: issue "go get -u github.com/vektra/mockery/.../" && exit 1)
	COPY_CMD = copy
	FILE_DELETE_CMD = del /f /q 2>NUL
	DIR_DELETE_CMD = rmdir /s /q 2>NUL
	TOUCH_FILE_CMD = copy /y nul
else
	ISWIN=false
	OUTPUT = ./riff
    OUTPUT_EXT =
	VERSION ?= $(shell cat VERSION)
	GITDIRTY = $(shell git diff --quiet HEAD || echo "dirty")
	GOBIN ?= $(shell go env GOPATH)/bin
	MOCKERY_CHECK_CMD = @which mockery > /dev/null || (echo mockery not found: issue "go get -u github.com/vektra/mockery/.../" && false)
	COPY_CMD = cp
	FILE_DELETE_CMD = rm -f
	DIR_DELETE_CMD = rm -fR
	TOUCH_FILE_CMD = touch
endif

GITSHA = $(shell git rev-parse HEAD)
LDFLAGS_VERSION = -X github.com/projectriff/riff/pkg/env.cli_name=riff \
				  -X github.com/projectriff/riff/pkg/env.cli_version=$(VERSION) \
				  -X github.com/projectriff/riff/pkg/env.cli_gitsha=$(GITSHA) \
				  -X github.com/projectriff/riff/pkg/env.cli_gitdirty=$(GITDIRTY)

all: build test docs

build: $(OUTPUT)

test:
	go test ./...

check-mockery:
	$(MOCKERY_CHECK_CMD)

gen-mocks: check-mockery
	mockery -output pkg/core/mocks/mockbuilder			-outpkg mockbuilder			-dir pkg/core 																					-name Builder
	mockery -output pkg/core/mocks						-outpkg mocks 				-dir pkg/core 																					-name Client
	mockery -output pkg/core/vendor_mocks				-outpkg vendor_mocks 		-dir vendor/k8s.io/client-go/kubernetes 														-name Interface
	mockery -output pkg/core/vendor_mocks/mockserving	-outpkg mockserving 		-dir vendor/github.com/knative/serving/pkg/client/clientset/versioned							-name Interface
	mockery -output pkg/core/vendor_mocks/mockserving	-outpkg mockserving 		-dir vendor/github.com/knative/serving/pkg/client/clientset/versioned/typed/serving/v1alpha1	-name ServingV1alpha1Interface
	mockery -output pkg/core/vendor_mocks/mockserving	-outpkg mockserving 		-dir vendor/github.com/knative/serving/pkg/client/clientset/versioned/typed/serving/v1alpha1	-name ServiceInterface
	mockery -output pkg/core/vendor_mocks				-outpkg vendor_mocks	 	-dir vendor/k8s.io/client-go/kubernetes/typed/core/v1 											-name CoreV1Interface
	mockery -output pkg/core/vendor_mocks				-outpkg vendor_mocks 		-dir vendor/k8s.io/client-go/kubernetes/typed/core/v1 											-name NamespaceInterface
	mockery -output pkg/core/vendor_mocks				-outpkg vendor_mocks	 	-dir vendor/k8s.io/client-go/kubernetes/typed/core/v1 											-name ServiceAccountInterface
	mockery -output pkg/core/vendor_mocks				-outpkg vendor_mocks 		-dir vendor/k8s.io/client-go/kubernetes/typed/core/v1 											-name SecretInterface
	mockery -output pkg/core/vendor_mocks				-outpkg vendor_mocks	 	-dir vendor/k8s.io/client-go/tools/clientcmd     	   											-name ClientConfig
	mockery -output pkg/fileutils/mocks					-outpkg mocks           	-dir pkg/fileutils                                    											-name Checker
	mockery -output pkg/fileutils/mocks					-outpkg mocks				-dir pkg/fileutils																				-name Copier

install: build
	$(COPY_CMD) $(OUTPUT)$(OUTPUT_EXT) $(GOBIN)

$(OUTPUT): vendor VERSION
	go build -o $(OUTPUT)$(OUTPUT_EXE) -ldflags "$(LDFLAGS_VERSION)"

release: vendor VERSION
ifeq ($(ISWIN),true)
	cmd /C "set GOOS=windows&&set GOARCH=amd64&& go build -ldflags "$(LDFLAGS_VERSION)" -o $(OUTPUT)$(OUTPUT_EXT) && 7z a -tzip riff-windows-amd64.zip $(OUTPUT)$(OUTPUT_EXT) && del /q $(OUTPUT)$(OUTPUT_EXT)"
	cmd /C "set GOOS=darwin&&set GOARCH=amd64&& go build -ldflags "$(LDFLAGS_VERSION)" -o $(OUTPUT) && 7z a -ttar riff-darwin-amd64.tar $(OUTPUT) && 7z a -tzip riff-darwin-amd64.tgz riff-darwin-amd64.tar && del /q riff-darwin-amd64.tar && del /q $(OUTPUT)"
	cmd /C "set GOOS=linux&&set GOARCH=amd64&& go build -ldflags "$(LDFLAGS_VERSION)" -o $(OUTPUT) && 7z a -ttar riff-linux-amd64.tar $(OUTPUT) && 7z a -tzip riff-linux-amd64.tgz riff-linux-amd64.tar && del /q riff-linux-amd64.tar && del /q $(OUTPUT)"
else	
	GOOS=darwin   GOARCH=amd64 go build -ldflags "$(LDFLAGS_VERSION)" -o $(OUTPUT)     && tar -czf riff-darwin-amd64.tgz $(OUTPUT) && rm -f $(OUTPUT)
	GOOS=linux    GOARCH=amd64 go build -ldflags "$(LDFLAGS_VERSION)" -o $(OUTPUT)     && tar -czf riff-linux-amd64.tgz $(OUTPUT) && rm -f $(OUTPUT)
	GOOS=windows  GOARCH=amd64 go build -ldflags "$(LDFLAGS_VERSION)" -o $(OUTPUT)$(OUTPUT_EXT) && zip -mq riff-windows-amd64.zip $(OUTPUT)$(OUTPUT_EXT) && rm -f $(OUTPUT)$(OUTPUT_EXT)
endif

docs: $(OUTPUT) clean-docs
	$(OUTPUT) docs

verify-docs: docs
	git diff --exit-code docs

clean-docs:
	$(DIR_DELETE_CMD) docs

clean:
	$(FILE_DELETE_CMD) $(OUTPUT)$(OUTPUT_EXT)
	$(FILE_DELETE_CMD) riff-darwin-amd64.tgz
	$(FILE_DELETE_CMD) riff-linux-amd64.tgz
	$(FILE_DELETE_CMD) riff-windows-amd64.zip

vendor: Gopkg.lock
	dep ensure -vendor-only && $(TOUCH_FILE_CMD) vendor

Gopkg.lock: Gopkg.toml
	dep ensure -no-vendor && $(TOUCH_FILE_CMD) Gopkg.lock


