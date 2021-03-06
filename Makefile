.PHONY: all deps compile clean eunit test rel

all: deps compile

compile:
	./rebar compile

deps:
	./rebar get-deps

clean:
	./rebar clean

eunit:
	./rebar skip_deps=true compile eunit

test: eunit

distclean: clean devclean relclean
	./rebar delete-deps

rel: all
	./rebar skip_deps=true generate

relclean:
	rm -rf rel/west

devrel: dev1 dev2 dev3

devclean:
	rm -rf dev

dev1 dev2 dev3:
	mkdir -p dev
	(cd rel && ../rebar generate target_dir=../dev/$@ overlay_vars=vars/$@.config)

clean_all:
	rm -rf rel/west
	rm -rf dev
	./rebar clean
