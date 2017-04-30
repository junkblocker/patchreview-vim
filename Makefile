.PHONY: test zip
.DEFAULT: test

test:
	vim -U NONE -u test/test.vim
	@echo "Done."

zip:
	@if [ -z "$(RELEASE)" ]; then \
		echo "RELEASE not defined." ; \
		exit 1 ; \
	fi
	@missing="$$(grep -L "$(RELEASE)" $$(git ls-files | grep -Ev '^(README|Makefile|test/|.gitignore)'))" ; \
		if [ -n "$${missing}" ]; then \
			echo "$${RELEASE} is missing from the following files" ; \
			echo ; \
			echo "$${missing}" ; \
			exit 1 ; \
		fi
	@if [ -f "patchreview-${RELEASE}.zip" ]; then \
		echo "patchreview-${RELEASE}.zip already exists" ; \
		exit 1; \
	else \
		zip -r patchreview-${RELEASE}.zip autoload plugin doc ; \
	fi
