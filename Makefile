.PHONY: hillside-mac hillside-linux kyria shell clean help

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

hillside-mac: ## Build hillside Mac firmware
	cd local-build && docker compose run --rm -e KEYBOARD=hillside-mac builder

hillside-linux: ## Build hillside Linux firmware
	cd local-build && docker compose run --rm -e KEYBOARD=hillside-linux builder

kyria: ## Build kyria firmware
	cd local-build && docker compose run --rm -e KEYBOARD=kyria builder

shell: ## Open interactive shell in the build container
	cd local-build && docker compose run --rm --entrypoint bash builder

clean: ## Remove all built firmware files
	rm -rf firmwares/*
