.PHONY: setup get hooks l10n gen watch format analyze test check feature rename branding icons splash placeholder-branding run-dev run-staging run-prod apk-prod aab-prod ipa-prod clean firebase-dev firebase-staging firebase-prod crashlytics-symbols-prod

# First thing after cloning.
setup: get hooks l10n

get:
	flutter pub get

# Git hooks live in .githooks (pre-commit: format + analyze, pre-push: tests).
hooks:
	git config core.hooksPath .githooks
	chmod +x .githooks/*

l10n:
	flutter gen-l10n

format:
	dart format lib test tool

analyze:
	flutter analyze

test:
	flutter test

# Run before every commit / in CI
check:
	dart format --output=none --set-exit-if-changed lib test tool
	flutter analyze
	flutter test

# Every flavor = native flavor/scheme (app id, name, icon) + env/<flavor>.json (Dart config).
# Always pass both; bootstrap asserts they match in debug builds.
run-dev:
	flutter run --flavor dev --dart-define-from-file=env/dev.json

run-staging:
	flutter run --flavor staging --dart-define-from-file=env/staging.json

run-prod:
	flutter run --release --flavor prod --dart-define-from-file=env/prod.json

RELEASE_FLAGS = --release --obfuscate --split-debug-info=build/symbols --flavor prod --dart-define-from-file=env/prod.json

apk-prod:
	flutter build apk $(RELEASE_FLAGS)

aab-prod:
	flutter build appbundle $(RELEASE_FLAGS)

ipa-prod:
	flutter build ipa $(RELEASE_FLAGS)

# Code generation (json_serializable). Generated *.g.dart files are committed.
# --force-jit: AOT builder compilation fails on this toolchain ("does not support build hooks").
gen:
	dart run build_runner build --delete-conflicting-outputs --force-jit

watch:
	dart run build_runner watch --delete-conflicting-outputs --force-jit

clean:
	flutter clean && flutter pub get

# ---- Feature scaffold ----
# make feature name=orders [entity=order]
# Creates lib/features/<name>, tests, and wires endpoint/route/DI/l10n title.
feature:
ifndef name
	$(error Usage: make feature name=<snake_case> [entity=<snake_case_singular>])
endif
	dart run tool/scaffold_feature.dart $(name) $(if $(entity),--entity $(entity))
	$(MAKE) gen l10n

# ---- New project from the template ----
# make rename name="Acme Shop" android_id=com.acme.shop [ios_id=com.acme.shop] [package=acme_shop]
# Rewrites Dart package, Android applicationId/namespace/Kotlin package, iOS bundle id
# and the per-flavor display names, then refreshes pub + l10n. Add dry=1 to preview.
rename:
ifndef name
	$(error Usage: make rename name="App Name" android_id=com.company.app [ios_id=...] [package=...] [dry=1])
endif
ifndef android_id
	$(error Usage: make rename name="App Name" android_id=com.company.app [ios_id=...] [package=...] [dry=1])
endif
	dart run tool/rename_app.dart --name "$(name)" --android-id $(android_id) \
		$(if $(ios_id),--ios-id $(ios_id)) $(if $(package),--package $(package)) $(if $(dry),--dry-run)
ifndef dry
	flutter pub get
	$(MAKE) l10n
endif

# Icons + native splash for every flavor, from assets/branding/<flavor>/.
# Config: flutter_launcher_icons-<flavor>.yaml, flutter_native_splash-<flavor>.yaml.
branding: icons splash

icons:
	dart run flutter_launcher_icons
	# flutter_launcher_icons 0.14 also rewrites this unrelated Xcode setting; put it back.
	sed -i '' -E 's/(ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = )AppIcon-[a-z]+;/\1YES;/' ios/Runner.xcodeproj/project.pbxproj

splash:
	dart run flutter_native_splash:create --flavors dev,staging,prod

# Regenerates the placeholder artwork (colored ring per flavor). Replace with real assets instead.
placeholder-branding:
	dart run tool/placeholder_branding.dart

# ---- Firebase (push notifications) ----
# One Firebase project per flavor. Set the ids below (or pass FIREBASE_PROJECT_DEV=... on the command line),
# then run the target; it (re)generates lib/core/firebase/firebase_options_<flavor>.dart.
# Needs: dart pub global activate flutterfire_cli && firebase login
FIREBASE_PROJECT_DEV ?= your-dev-project-id
FIREBASE_PROJECT_STAGING ?= your-staging-project-id
FIREBASE_PROJECT_PROD ?= your-prod-project-id
# App ids must match android/app/build.gradle.kts productFlavors and ios/Flutter/Flavors/*.xcconfig.
# $(1) project id, $(2) flavor, $(3) android package, $(4) ios bundle id
define flutterfire_configure
	flutterfire configure --yes --platforms=android,ios \
		--project=$(1) \
		--out=lib/core/firebase/firebase_options_$(2).dart \
		--android-package-name=$(3) \
		--ios-bundle-id=$(4)
endef

firebase-dev:
	$(call flutterfire_configure,$(FIREBASE_PROJECT_DEV),dev,com.codebase.codebase_flutter.dev,com.codebase.codebaseFlutter.dev)

firebase-staging:
	$(call flutterfire_configure,$(FIREBASE_PROJECT_STAGING),staging,com.codebase.codebase_flutter.staging,com.codebase.codebaseFlutter.staging)

firebase-prod:
	$(call flutterfire_configure,$(FIREBASE_PROJECT_PROD),prod,com.codebase.codebase_flutter,com.codebase.codebaseFlutter)

# Upload Dart symbols so Crashlytics can symbolicate obfuscated release stack traces.
# Run after apk-prod / aab-prod / ipa-prod. App ids are in lib/core/firebase/firebase_options_prod.dart.
crashlytics-symbols-prod:
	firebase crashlytics:symbols:upload --app=$(FIREBASE_ANDROID_APP_ID_PROD) build/symbols
	firebase crashlytics:symbols:upload --app=$(FIREBASE_IOS_APP_ID_PROD) build/symbols
