.PHONY: all convert build dev clean

all: build

convert:
	gleam run -m convert

build: convert
	gleam build

run: build
	gleam run

dev: build
	gleam run -m dev_server

clean:
	rm -rf dist build/dev blog
