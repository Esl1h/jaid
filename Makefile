BIN := jaid

.PHONY: build test fmt fmt-check vet check install uninstall clean

build:
	v -o $(BIN) .

test:
	v test .

fmt:
	v fmt -w .

fmt-check:
	v fmt -diff .

vet:
	v vet .

check: fmt-check vet test

PREFIX  ?= /usr/local
BINDIR  ?= $(PREFIX)/bin

install: build
	install -m755 $(BIN) $(BINDIR)/$(BIN)

uninstall:
	rm -f $(BINDIR)/$(BIN)

clean:
	rm -f $(BIN)
