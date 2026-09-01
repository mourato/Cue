.PHONY: help b build run dmg test build-video test-video format-check format-fix lint lint-changed lint-fix agent-check validate guidance-check clean-build

help:
	@echo "Notinhas commands:"
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

agent-check:
	@./scripts/agent-check.sh

validate: agent-check

guidance-check:
	@./scripts/guidance-check.sh

clean-build:
	@rm -rf .build/xcode-derived-data build
	@echo "Removed .build/xcode-derived-data and build"
