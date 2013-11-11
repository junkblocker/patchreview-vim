.PHONY: all
.DEFAULT: all

all:
	vim -U NONE -u test/test.vim
	@echo "Done."
