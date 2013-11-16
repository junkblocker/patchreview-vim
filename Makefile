.PHONY: test zip
.DEFAULT: test

test:
	vim -U NONE -u test/test.vim
	@echo "Done."

zip:
	@if [ -z "${RELEASE}" ]; then \
		echo "RELEASE not defined." ; \
		exit 1 ; \
	elif ! grep -q "${RELEASE}" autoload/patchreview.vim ; then \
		echo "RELEASE ${RELEASE} not found in autoload/patchreview.vim" ; \
		exit 1; \
	elif ! grep -q "${RELEASE}" doc/patchreview.txt ; then \
		echo "RELEASE ${RELEASE} not found in doc/patchreview.vim" ; \
		exit 1; \
	elif ! grep -q "${RELEASE}" plugin/patchreview.vim ; then \
		echo "RELEASE ${RELEASE} not found in plugin/patchreview.vim" ; \
		exit 1; \
	elif [ -f "patchreview-${RELEASE}.zip" ]; then \
		echo "patchreview-${RELEASE}.zip already exists" ; \
		exit 1; \
	else \
		zip -r patchreview-${RELEASE}.zip autoload plugin doc ; \
	fi
