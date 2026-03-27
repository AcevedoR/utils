.PHONY: build install

build:
	goreleaser build --single-target --snapshot --clean --output dist/backport

install: build
	install -m755 dist/backport /usr/local/bin/backport
