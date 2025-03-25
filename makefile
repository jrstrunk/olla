# List all subdirectories
SUBDIRS := $(wildcard */)

.PHONY: all
all:
	@echo "Available commands: run, dev, test, update, format, clean, build, add <package>, remove <package>"

.PHONY: run
run:
	@(cd client \
  && gleam run -m lustre/dev build component o11a/ui/line_discussion --minify --outdir="../server/priv/static" \
	&& gleam run -m lustre/dev build component o11a/ui/discussion_preview --minify --outdir="../server/priv/static" \
	&& npx vite build \
	&& cd ../server \
	add && gleam run dev)

.PHONY: clean-skeleton
clean-skeleton:
	@(cd server/priv/audits && find . -type f -name "*skeleton.html" -delete)

.PHONY: count-lines
count-lines:
	@(cd server/priv/audits && find . -type f -exec wc -l {} \; | sort -n)

.PHONY: clear-git-submodules
clear-git-submodules:
	@(cd server/priv/audits && find . -name ".git" -type d -exec rm -rf {} +)

.PHONY: test
test:
	@for dir in $(SUBDIRS); do \
		(cd $$dir && gleam test); \
	done

.PHONY: clean
clean:
	@for dir in $(SUBDIRS); do \
		(cd $$dir && gleam clean); \
	done

.PHONY: update
update:
	@for dir in $(SUBDIRS); do \
		(cd $$dir && gleam update); \
	done

.PHONY: format
format:
	@for dir in $(SUBDIRS); do \
		(cd $$dir && gleam format); \
	done

.PHONY: build
build:
	@for dir in $(SUBDIRS); do \
		(cd $$dir && gleam build); \
	done

.PHONY: add
add:
	@for dir in $(SUBDIRS); do \
		(cd $$dir && gleam add $(word 2,$(MAKECMDGOALS))); \
	done 

.PHONY: remove
remove:
	@for dir in $(SUBDIRS); do \
		(cd $$dir && gleam remove $(word 2,$(MAKECMDGOALS))); \
	done

# This stops make from complaining that a package name is not a target after
# running `make add <package>` or `make remove <package>`
%:
	@: