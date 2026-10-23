.PHONY: all menu build run release test clean status help

all: build

menu:
	@./manage.sh

build:
	@./manage.sh build

run:
	@./manage.sh run

release:
	@./manage.sh release $(ARGS)

test:
	@./manage.sh test

clean:
	@./manage.sh clean

status:
	@./manage.sh status

help:
	@./manage.sh --help
