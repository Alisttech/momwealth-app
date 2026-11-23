# Test signing key (NOT for the Play Store)

Signs the test APKs built by GitHub Actions so each new test build installs over the previous one.
It is only for testing. For Google Play, create a separate upload key, keep it out of the repo
and add it as the ANDROID_KEYSTORE_B64 / ANDROID_KEYSTORE_PASSWORD repository secrets.

- Keystore: momwealth-test.jks, alias: momwealth, store and key password: uaMC2Jlttw7COtExW4uZyCdx
