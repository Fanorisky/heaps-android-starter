# Development APK identity

The `proof` build uses a dedicated development keystore, with the public certificate SHA-256 in `test-certificate-sha256.txt`. `debug` uses the normal ephemeral Android debug identity.

Create or reuse a private local test identity:

```sh
python3 scripts/setup-test-signing.py
```

The private files are ignored under `signing/`, with a second backup under the current user's `.local/share/heapsandroid-signing/`. Keep that backup private and recover it rather than replacing a lost identity. The script refuses incomplete/conflicting identities. No keys or passwords belong in Git.

Repository administrators can configure the approved dedicated CI test secrets:

```sh
python3 scripts/setup-test-signing.py --github-repo OWNER/REPO
```

Main/tag `proof` builds require all `HEAPS_ANDROID_TEST_*` signing inputs and verify the recorded public certificate. Pull-request builds do not read those secrets and publish explicitly ephemeral debug artifacts. These development credentials are separate from a production/store signing process.

The proof example uses `io.heaps.android.proof`, so it can be installed alongside the original `io.heaps.neondrift` example. Its stable proof identity supports updates without losing the proof application's preferences.
