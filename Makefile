CONFIG = repo/Fedora-devel-GA-repos.cfg
MODULES = bootstrap hp
ARCHES = --arch=aarch64 \
		 --arch=armv7hl \
		 --arch=i686 \
		 --arch=ppc64 \
		 --arch=ppc64le \
		 --arch=s390x \
		 --arch=x86_64

all: $(MODULES)

$(MODULES): repo-devel
	@echo '*** Generating the $@ module(s) ***'
	./generate_module_lists.sh --version=devel --module=$@ $(ARCHES)
	./make_modulemd.pl -v ./data/Fedora/devel/$@

repo-devel:
	@echo '*** Fetching the development snapshot repository ***'
	./download_repo.sh $(ARCHES) \
		--release=devel \
		--overrides 

repo-rawhide:
	@echo '*** Fetching the Rawhide-based repository ***'
	./download_repo.sh $(ARCHES) \
		--archful-srpm-file=archful-srpms.txt \
		--release=rawhide \
		--overrides 

clean:
	rm -f data/Fedora/devel/*/*.yaml
	rm -f data/Fedora/devel/*/*/runtime-*.txt
	rm -f data/Fedora/devel/*/*/selfhosting-*.txt
