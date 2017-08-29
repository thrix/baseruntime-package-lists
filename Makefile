MODULES = bootstrap atomic hp
ARCHES = aarch64 armv7hl i686 ppc64 ppc64le s390x x86_64
INPUT ?= https://raw.githubusercontent.com/fedora-modularity/hp/master
TOPLEVEL = toplevel-binary-packages.txt

.PHONY: all clean test update-input

all: $(MODULES)

$(MODULES): repo/devel
	./generate_module_lists.sh \
		--version=devel \
		--module=$@ \
		$(foreach arch,$(ARCHES),--arch $(arch))
	./make_modulemd.pl -v ./data/Fedora/devel/$@

repo/devel:
	./download_repo.sh \
		$(foreach arch,$(ARCHES),--arch $(arch)) \
		--release=devel \
		--overrides 

repo/rawhide:
	./download_repo.sh \
		$(foreach arch,$(ARCHES),--arch $(arch)) \
		--archful-srpm-file=archful-srpms.txt \
		--release=rawhide \
		--overrides 

clean:
	rm -f data/Fedora/devel/*/*.yaml
	rm -f data/Fedora/devel/*/*/runtime-*.txt
	rm -f data/Fedora/devel/*/*/selfhosting-*.txt

test:
	$(foreach test,$(sort $(wildcard tests/*)),./$(test);)

update-input:
	$(foreach module,$(MODULES),\
		$(foreach arch,$(ARCHES),\
		curl "$(INPUT)/$(module)/$(arch)/$(TOPLEVEL)" \
		> "data/Fedora/devel/$(module)/$(arch)/$(TOPLEVEL)";))
	curl "$(INPUT)/bootstrap.csv" \
		> "data/Fedora/devel/bootstrap/bootstrap.csv"
	curl "$(INPUT)/atomic.csv" \
		> "data/Fedora/devel/atomic/atomic.csv"
	curl "$(INPUT)/host.csv" \
		> "data/Fedora/devel/hp/host.csv"
	curl "$(INPUT)/platform.csv" \
		> "data/Fedora/devel/hp/platform.csv"
	curl "$(INPUT)/shim.csv" \
		> "data/Fedora/devel/hp/shim.csv"
