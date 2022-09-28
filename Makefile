#! /bin/make
SHELL:=/bin/bash

script:=inf6
modules:=bash_functions parse_parms parse_yaml
bf_mods:=$(patsubst %,bash-functions/%.sh,${modules})
prefix:=$(shell echo ~/.local)

pre-commit: README.md

README.md: ${script}
	@shdoc ${script} > $@

install:
	@type http;
	@type install;
	@if [[ -d ${prefix}/bin ]]; then\
		mkdir -p ${prefix}/lib/${script};\
    >&2 echo "install ${script} ${prefix}/bin"; \
		install ${bf_mods} ${prefix}/lib/${script};\
    install ${script} ${prefix}/bin; \
	else \
		>&2 echo "installation directory ${prefix}/bin not found"; \
		>&2 echo "Try setting prefix as in make prefix=/usr/local install"; \
		exit 1; \
	fi;
#	@if [[ "$${PATH}" =~ (^|:)"${prefix}/bin"(|/)(:|$$) ]]; then \
#	  echo "Installed to ${prefix}/bin/ezid"; \
#	else \
#	  echo "Installed, but ${prefix}/bin/ezid not in current PATH";\
#	fi;
