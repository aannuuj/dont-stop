# Release And Notarization

This repo can build a local DMG with `make dmg`. A public macOS download should be signed with a Developer ID Application certificate and notarized by Apple so new users do not see the unverified-app warning.

## Local Test Build

```sh
make test
make dmg
```

This creates `dist/Don't Stop-<version>.dmg` using ad-hoc signing. It is useful for local testing, but it is not a public release build.

## Public Release Build

Prerequisites:

- Active Apple Developer Program membership.
- A Developer ID Application certificate installed in Keychain.
- A `notarytool` keychain profile created for your Apple developer account.

Run:

```sh
make test
make release-public \
  SIGN_IDENTITY="Developer ID Application: Example Name (TEAMID)" \
  NOTARY_PROFILE="dont-stop-notary"
```

The `release-public` target signs the app, packages the DMG, submits it for notarization, staples the ticket, validates the staple, and runs `spctl` assessment.

## Before Publishing

Verify the final DMG on a different Mac:

- Open the DMG.
- Drag `Don't Stop.app` into Applications.
- Launch the app with a normal double-click.
- Confirm there is no unverified-app warning.
- Confirm the menu bar panel opens and dismisses correctly.
- Confirm `dont-stop://toggle` works after installing the app.
- Confirm `dont-stop status` works after installing the CLI helper.

Only upload the stapled DMG after those checks pass.
