.PHONY: help b build run dmg test build-video test-video format-check format-fix lint lint-changed lint-fix agent-check validate validate-lane validate-lane-command guidance-check clean-build

help:
	@echo "Cue commands:"
	@echo "  make b      Interactive Debug/Release build + launch"
	@echo "  make build  Same as make b"
	@echo "  make dmg    Build Release app, ad-hoc sign, and create local DMG"
	@echo "  make test   Run the default XCTest suite"
	@echo "  make build-video  Build+verify with the Video module (also the make b default)"
	@echo "  make test-video   Run the optional Video XCTest suite"
	@echo "  make format-check Validate SwiftFormat"
	@echo "  make format-fix   Apply SwiftFormat"
	@echo "  make lint         Validate all owned Swift"
	@echo "  make lint-changed Validate changed Swift"
	@echo "  make lint-fix     Apply SwiftLint autocorrections"
	@echo "  make agent-check  Run format, lint, and strict planner"
	@echo "  make validate     Canonical changed-surface validation"
	@echo "  make validate-lane Run validate through the global baseline/artifact gate"
	@echo "  make guidance-check Validate guidance files"
	@echo "  make clean-build"

b build run:
	@./scripts/build_and_run.sh

dmg:
	@./scripts/dry-run-release.sh

test:
	@./scripts/run-tests.sh

build-video:
	@./scripts/build_and_run.sh --video-module --verify

test-video:
	@./scripts/run-tests.sh --video-module

format-check:
	@swiftformat Cue CueTests --lint

format-fix:
	@swiftformat Cue CueTests

lint:
	@swiftlint lint --config .swiftlint.yml Cue CueTests

lint-changed:
	@./scripts/lint-changed.sh

lint-fix:
	@swiftlint lint --fix --config .swiftlint.yml Cue CueTests

AGENT_CONFIG_HOME ?= $(HOME)/.agents
VALIDATE_LANE ?= $(AGENT_CONFIG_HOME)/scripts/validate-lane
VALIDATE_BASE ?= $(shell git merge-base origin/main HEAD 2>/dev/null || git rev-parse HEAD^)
VALIDATE_ARTIFACT_ROOTS := build/verification
VALIDATE_ARTIFACT_ARGS := $(foreach root,$(VALIDATE_ARTIFACT_ROOTS),--artifacts "$(CURDIR)/$(root)")

agent-check:
	@./scripts/agent-check.sh

validate: agent-check

validate-lane:
	@$(VALIDATE_LANE) --repo "$(CURDIR)" --base "$(VALIDATE_BASE)" $(VALIDATE_ARTIFACT_ARGS) -- $(MAKE) validate-lane-command

validate-lane-command:
	@set -eu; \
		build_existed=0; \
		if [ -e "$(CURDIR)/build" ] || [ -L "$(CURDIR)/build" ]; then build_existed=1; fi; \
		cleanup() { \
			if [ "$$build_existed" -eq 0 ]; then rm -rf "$(CURDIR)/build"; fi; \
		}; \
		trap cleanup EXIT; \
		$(MAKE) validate

guidance-check:
	@./scripts/guidance-check.sh

clean-build:
	@rm -rf .build/xcode-derived-data build
	@echo "Removed .build/xcode-derived-data and build"
