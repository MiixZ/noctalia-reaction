# Development helpers for the plugins in this repository.
#
#   make link       symlink both plugins into the shell's plugin directory
#                   (edits in the working tree apply after a plugin reload)
#   make install    copy both plugins into the shell's plugin directory
#   make uninstall  remove them from the shell's plugin directory
#   make list       show the plugins and the install target

PREFIX  ?= $(HOME)/.local/share/noctalia/plugins
PLUGINS := reaction game-clip

.PHONY: all list link install uninstall

all: list

list:
	@echo "plugins: $(PLUGINS)"
	@echo "target:  $(PREFIX)"

# Development: symlinks, so the shell reads the working tree directly.
link:
	@mkdir -p $(PREFIX)
	@for plugin in $(PLUGINS); do \
		ln -sfn $(CURDIR)/$$plugin $(PREFIX)/$$plugin; \
		echo "$(PREFIX)/$$plugin -> $(CURDIR)/$$plugin"; \
	done

# Install: real copies. The rm first also replaces a development symlink so
# rsync never writes back into the repository.
install:
	@mkdir -p $(PREFIX)
	@for plugin in $(PLUGINS); do \
		rm -rf $(PREFIX)/$$plugin; \
		rsync -a --exclude='.git' $(CURDIR)/$$plugin/ $(PREFIX)/$$plugin/; \
		echo "installed $(PREFIX)/$$plugin"; \
	done

uninstall:
	@for plugin in $(PLUGINS); do \
		rm -rf $(PREFIX)/$$plugin; \
		echo "removed $(PREFIX)/$$plugin"; \
	done
