.PHONY: help b build run dmg test clean-build

help:
	@echo "Notinhas commands:"
	@echo "  make b      Interactive Debug/Release build + launch"
	@echo "  make build  Same as make b"
	@echo "  make dmg    Build Release app, ad-hoc sign, and create local DMG"
	@echo "  make test   Run the default XCTest suite"
	@echo "  make clean-build"

b build run:
	@./scripts/build_and_run.sh

dmg:
	@./scripts/dry-run-release.sh

test:
	@./scripts/run-tests.sh

clean-build:
	@rm -rf .build/xcode-derived-data build
	@echo "Removed .build/xcode-derived-data and build"
