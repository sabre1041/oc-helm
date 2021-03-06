export GO111MODULE ?= on
export GOARCH      ?= amd64
export CGO_ENABLED ?= 0

INSTALL_PATH ?= /usr/local/bin
PROJECT   ?= oc-helm
DIST_DIRS       := find * -type d -exec
TAR_DIST_DIRS   := find * -type d -not -name "*windows*" -exec
ZIP_DIST_DIRS   := find * -type d  -name "*windows*" -exec
REPOPATH  ?= github.com/redhat-cop/$(PROJECT)
COMMIT    := $(shell git rev-parse HEAD)
VERSION   ?= $(shell git describe --always --tags --dirty)
GOOS      ?= $(shell go env GOOS)
GOPATH    ?= $(shell go env GOPATH)

BINDIR     := $(CURDIR)/bin
BINNAME    := oc-helm
DISTDIR    := ./_dist
PLATFORMS  ?= darwin/amd64 windows/amd64 linux/amd64

VERSION_PACKAGE := $(REPOPATH)/pkg/version
COMPRESS:=gzip --best -k -c

DATE_FMT = %Y-%m-%dT%H:%M:%SZ
ifdef SOURCE_DATE_EPOCH
    BUILD_DATE ?= $(shell date -u -d "@$(SOURCE_DATE_EPOCH)" "+$(DATE_FMT)" 2>/dev/null || date -u -r "$(SOURCE_DATE_EPOCH)" "+$(DATE_FMT)" 2>/dev/null)
else
    BUILD_DATE ?= $(shell date "+$(DATE_FMT)")
endif
GO_LDFLAGS :="-s -w
GO_LDFLAGS += -X $(VERSION_PACKAGE).version=$(VERSION)
GO_LDFLAGS += -X $(VERSION_PACKAGE).buildDate=$(BUILD_DATE)
GO_LDFLAGS += -X $(VERSION_PACKAGE).gitCommit=$(COMMIT)
GO_LDFLAGS +="

GO_FILES  := $(shell find . -type f -name '*.go')

.PHONY: all
all: build

.PHONY: build
build: CGO_ENABLED := 1
build: GO_LDFLAGS := $(subst -s -w,,$(GO_LDFLAGS))
build:
	go build -race -ldflags $(GO_LDFLAGS) -o '$(BINDIR)'/$(BINNAME) main.go

build-cross: LDFLAGS += -extldflags "-static"
build-cross: $(GO_FILES) $(BUILDDIR) gox
	GOFLAGS="-trimpath" gox -osarch="$(PLATFORMS)" -tags netgo -ldflags $(GO_LDFLAGS) -parallel=3 -output="_dist/{{.OS}}-{{.Arch}}/$(BINNAME)"

.PHONY: install
install: build
	@install "$(BINDIR)/$(BINNAME)" "$(INSTALL_PATH)/$(BINNAME)"

gox:
ifeq (, $(shell which gox))
	@{ \
	set -e ;\
	GOX_TMP_DIR=$$(mktemp -d) ;\
	cd $$GOX_TMP_DIR ;\
	go mod init tmp ;\
	go get github.com/mitchellh/gox ;\
	rm -rf $$GOX_TMP_DIR ;\
	}
GOX=$(GOBIN)/controller-gen
else
GOX=$(shell which gox)
endif

.PHONY: clean
clean:
	@rm -rf '$(BINDIR)' $(DISTDIR)

.PHONY: dist
dist:
	( \
		cd $(DISTDIR) && \
		$(DIST_DIRS) cp ../LICENSE {} \; && \
		$(DIST_DIRS) cp ../README.md {} \; && \
		$(TAR_DIST_DIRS) tar -zcf oc-helm-${VERSION}-{}.tar.gz {} \; && \
		$(ZIP_DIST_DIRS) zip -r oc-helm-${VERSION}-{}.zip {} \; \
	)
