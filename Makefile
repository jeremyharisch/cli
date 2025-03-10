.DEFAULT_GOAL := local

ifndef VERSION
	VERSION = ${shell git rev-parse --abbrev-ref HEAD}-${shell git rev-parse --short HEAD}

	ifneq (${shell git tag -l "stable"},) # if there is a stable tag
		ifeq (${shell git rev-list -n 1 tags/stable},${shell git rev-parse HEAD}) # if stable tag is the same as current commit
			VERSION = stable-${shell git rev-parse --short HEAD}
		endif
	endif
endif

FLAGS = -ldflags '-s -w -X github.com/kyma-project/cli/cmd/kyma/version.Version=$(VERSION)'

.PHONY: resolve
resolve:
	go mod tidy -compat=1.18

.PHONY: validate
validate:
	./hack/verify-lint.sh
	./hack/verify-generated-docs.sh

.PHONY: build
build: build-windows build-linux build-darwin build-windows-arm build-linux-arm

.PHONY: build-windows
build-windows:
	CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build -o ./bin/kyma.exe $(FLAGS) ./cmd

.PHONY: build-windows-arm
build-windows-arm:
	CGO_ENABLED=0 GOOS=windows GOARCH=arm go build -o ./bin/kyma-arm.exe $(FLAGS) ./cmd

.PHONY: build-linux
build-linux:
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o ./bin/kyma-linux $(FLAGS) ./cmd

.PHONY: build-linux-arm
build-linux-arm:
	CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -o ./bin/kyma-linux-arm $(FLAGS) ./cmd

.PHONY: build-darwin
build-darwin:
	CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 go build -o ./bin/kyma-darwin $(FLAGS) ./cmd

# .PHONY: build-darwin-arm
# build-darwin-arm:
# 	CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -o ./bin/kyma-darwin-arm $(FLAGS) ./cmd

.PHONY: docs
docs:
	rm -f ./docs/gen-docs/*
	go run ./cmd/gendocs/gendocs.go

.PHONY: test
test:
	go test -race -coverprofile=cover.out ./...
	@echo "Total test coverage: $$(go tool cover -func=cover.out | grep total | awk '{print $$3}')"
	@rm cover.out

.PHONY: integration-test
integration-test:
	./bin/kyma-linux help

.PHONY: archive
archive:
	cp -r bin/* $(ARTIFACTS)

.PHONY: upload-binaries
upload-binaries:
ifeq ($(STABLE), true)
	gcloud auth activate-service-account --key-file "$(GOOGLE_APPLICATION_CREDENTIALS)"
	gsutil cp bin/* $(KYMA_CLI_STABLE_BUCKET)
endif
ifeq ($(UNSTABLE), true)
	gcloud auth activate-service-account --key-file "$(GOOGLE_APPLICATION_CREDENTIALS)"
	gsutil cp bin/* $(KYMA_CLI_UNSTABLE_BUCKET)
endif

.PHONY: release
release:
	./hack/release.sh

.PHONY: clean
clean:
	rm -rf bin

.PHONY: install
install:
	CGO_ENABLED=0 go build -o ./bin/kyma $(FLAGS) ./cmd
	mv ./bin/kyma ${GOPATH}/bin

.PHONY: local
local: validate test install

.PHONY: ci-pr
ci-pr: resolve validate build test integration-test

.PHONY: ci-main
ci-main: resolve validate build test integration-test upload-binaries

.PHONY: ci-release
ci-release: resolve validate build test integration-test archive release
