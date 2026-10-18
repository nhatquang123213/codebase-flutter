.PHONY: get l10n gen watch format analyze test check run-dev run-staging run-prod apk-prod aab-prod ipa-prod clean firebase-dev firebase-staging firebase-prod

get:
	flutter pub get

l10n:
	flutter gen-l10n

format:
	dart format lib test

analyze:
	flutter analyze

test:
	flutter test

# Run before every commit / in CI
check:
	dart format --output=none --set-exit-if-changed lib test
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
