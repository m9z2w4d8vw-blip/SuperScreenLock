#!/bin/bash
# Everything the GitHub Actions workflow runs lives here, so changing the
# build never means editing .github/workflows, which GitHub Desktop skips.
#
#   bash ci/build.sh build     check, compile, sign, package SuperScreenLock.ipa
#   bash ci/build.sh errors    turn compiler errors into annotations
#   bash ci/build.sh publish   attach the IPA to a GitHub release
set -eo pipefail

APP_NAME="SuperScreenLock"
EXTENSIONS="LimitMonitor ShieldLook ShieldButtons"
REPORT="ActivityReport"
PRODUCTS="build/Build/Products/Release-iphoneos"
APP="$PRODUCTS/$APP_NAME.app"
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1

check_layout() {
  local missing=0 path ext
  for path in project.yml report.yml Sources/App Sources/Shared Sources/SharedUI "Sources/$REPORT" Config Resources/Assets.xcassets; do
    if [ ! -e "$path" ]; then
      echo "::error::$path is missing from the top of the repo. Copy what's inside the zip into the repo root, not the folder around it."
      missing=1
    fi
  done
  for ext in $EXTENSIONS $REPORT $APP_NAME; do
    if [ ! -f "Config/$ext.entitlements" ]; then
      echo "::error::Config/$ext.entitlements is missing"
      missing=1
    fi
  done
  if [ "$missing" -ne 0 ]; then
    echo "Top level of the repo:"
    ls -la
    exit 1
  fi
}

show_toolchain() {
  sw_vers
  xcodebuild -version
  xcrun --sdk iphoneos --show-sdk-version
}

# xcb <project> <scheme> <log>
xcb() {
  xcodebuild \
    -project "$1" \
    -scheme "$2" \
    -configuration Release \
    -sdk iphoneos \
    -destination 'generic/platform=iOS' \
    -derivedDataPath build \
    -quiet \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    CURRENT_PROJECT_VERSION="${BUILD_NUMBER:-1}" \
    build 2>&1 | tee "$3"
}

build_app() {
  xcodegen generate
  xcodebuild -list -project "$APP_NAME.xcodeproj"
  if ! xcb "$APP_NAME.xcodeproj" "$APP_NAME" build.log; then
    if grep -qiE "is not installed|no simulator runtime|platform.*not.*installed" build.log; then
      echo "::warning::The iOS platform is missing on this runner. Downloading it and retrying."
      xcodebuild -downloadPlatform iOS
      xcb "$APP_NAME.xcodeproj" "$APP_NAME" build.log
    else
      exit 1
    fi
  fi
}

# The screen-time report is its own project. If it fails, the app still
# ships, just without the screen-time number.
build_report() {
  if xcodegen generate --spec report.yml && xcb "$REPORT.xcodeproj" "$REPORT" report.log; then
    echo "Built $REPORT"
  else
    echo "::warning::$REPORT didn't build, so this IPA has no screen-time number. Details are in report.log."
    if [ -f report.log ]; then
      grep -E "error:" report.log | sort -u | head -20 | while IFS= read -r line; do
        echo "::warning::$line"
      done || true
    fi
    rm -rf "$PRODUCTS/$REPORT.appex"
  fi
}

# sign <entitlements> <binary>: Screen Time only works if every binary
# carries Family Controls, so a missing entitlement fails the build.
sign() {
  ldid -S"$1" "$2"
  local ents
  ents="$(ldid -e "$2")"
  case "$ents" in
    *com.apple.developer.family-controls*) echo "Signed $2 with $1" ;;
    *) echo "::error::$2 is missing the Family Controls entitlement after signing"; exit 1 ;;
  esac
}

package() {
  if [ ! -d "$APP" ]; then
    echo "::error::The build finished but $APP is missing"
    find "$PRODUCTS" -maxdepth 1 -print || true
    exit 1
  fi

  local ext appex
  for ext in $EXTENSIONS; do
    appex="$APP/PlugIns/$ext.appex"
    if [ ! -f "$appex/$ext" ]; then
      echo "::error::$ext.appex wasn't embedded in the app"
      ls -la "$APP/PlugIns" || true
      exit 1
    fi
    echo "$ext extension point: $(plutil -extract NSExtension.NSExtensionPointIdentifier raw -o - "$appex/Info.plist")"
    sign "Config/$ext.entitlements" "$appex/$ext"
  done

  # ExtensionKit extensions belong in Extensions/, not PlugIns/.
  rm -rf "$APP/PlugIns/$REPORT.appex" "$APP/Extensions/$REPORT.appex"
  if [ -d "$PRODUCTS/$REPORT.appex" ]; then
    mkdir -p "$APP/Extensions"
    cp -R "$PRODUCTS/$REPORT.appex" "$APP/Extensions/"
    echo "$REPORT extension point: $(plutil -extract EXAppExtensionAttributes.EXExtensionPointIdentifier raw -o - "$APP/Extensions/$REPORT.appex/Info.plist")"
    sign "Config/$REPORT.entitlements" "$APP/Extensions/$REPORT.appex/$REPORT"
  fi

  sign "Config/$APP_NAME.entitlements" "$APP/$APP_NAME"

  rm -rf Payload "$APP_NAME.ipa"
  mkdir Payload
  cp -R "$APP" Payload/
  zip -qry "$APP_NAME.ipa" Payload
  ls -lh "$APP_NAME.ipa"
}

list_errors() {
  local log
  for log in build.log report.log; do
    [ -f "$log" ] || continue
    grep -E "error:" "$log" | sort -u | head -40 | while IFS= read -r line; do
      echo "::error::$line"
    done || true
  done
}

publish() {
  local tag="build-$BUILD_NUMBER" short_sha="${GITHUB_SHA::7}"
  {
    echo "$APP_NAME build $BUILD_NUMBER from commit $short_sha, signed with ldid for TrollStore."
    echo
    if [ -n "$COMMIT_MESSAGE" ]; then
      echo "$COMMIT_MESSAGE"
      echo
    fi
    echo "Install by opening $APP_NAME.ipa with TrollStore."
  } > release-notes.md
  if gh release view "$tag" >/dev/null 2>&1; then
    gh release upload "$tag" "$APP_NAME.ipa" --clobber
  else
    gh release create "$tag" "$APP_NAME.ipa" \
      --title "$APP_NAME build $BUILD_NUMBER" \
      --notes-file release-notes.md \
      --target "$GITHUB_SHA" \
      --latest
  fi
  {
    echo "### $APP_NAME build $BUILD_NUMBER"
    echo "https://github.com/$GITHUB_REPOSITORY/releases/tag/$tag"
  } >> "$GITHUB_STEP_SUMMARY"
}

case "${1:-}" in
  build)
    check_layout
    show_toolchain
    brew install xcodegen ldid
    build_app
    build_report
    package
    ;;
  errors) list_errors ;;
  publish) publish ;;
  *)
    echo "usage: bash ci/build.sh build|errors|publish"
    exit 2
    ;;
esac
