# Copr's "make srpm" source method calls this target as:
#   make -f <repo>/.copr/Makefile srpm outdir="<outdir>" spec="<spec_path>"
#
# The spec intentionally pins Source0 to an upstream AppImage release URL.
# rpmbuild does not fetch URL sources on its own, so this target downloads the
# pinned AppImage into a temporary SOURCES directory before creating the SRPM.

REPO_ROOT := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST))))..)
SOURCES_DIR := $(REPO_ROOT)/.copr-sources

.PHONY: srpm
srpm:
	@test -n "$(outdir)" || { echo "missing outdir=..." >&2; exit 1; }
	@test -n "$(spec)" || { echo "missing spec=..." >&2; exit 1; }
	rm -rf "$(SOURCES_DIR)"
	mkdir -p "$(SOURCES_DIR)" "$(outdir)"
	source0="$$(awk '/^Source0:/ { print $$2; exit }' "$(spec)")"; \
	  test -n "$$source0" || { echo "missing Source0 in $(spec)" >&2; exit 1; }; \
	  curl -fL "$$source0" -o "$(SOURCES_DIR)/$$(basename "$$source0")"
	cp "$(REPO_ROOT)/t3code-wrapper.sh" "$(SOURCES_DIR)/"
	cp "$(REPO_ROOT)/t3code.desktop" "$(SOURCES_DIR)/"
	cp "$(REPO_ROOT)/LICENSE" "$(SOURCES_DIR)/"
	cp "$(REPO_ROOT)/README.md" "$(SOURCES_DIR)/"
	rpmbuild -bs \
	  --target x86_64 \
	  --define "_sourcedir $(SOURCES_DIR)" \
	  --define "_srcrpmdir $(outdir)" \
	  "$(spec)"
