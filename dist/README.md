# ResQMesh APK Distribution

| File | Purpose |
|---|---|
| `resqmesh-release.apk` | Recommended hackathon build (release, AOT, ~61 MB) |
| `resqmesh-debug.apk` | Debug build for logcat/field diagnostics |
| `SHA256SUMS.txt` | Integrity checksums |

## Install

```powershell
adb install -r resqmesh-release.apk
```

Or copy `resqmesh-release.apk` to each phone and allow installation from the file manager.
Android may ask to allow installs from an unknown source.

## Important

- This release APK is signed with the **debug keystore** for hackathon convenience. Replace it
  with a private release keystore before any public distribution.
- Android 7.0+ (minSdk 24) and Google Play services are required for Nearby Connections.
- Grant location + Bluetooth/Nearby Wi-Fi permissions for real peer discovery.
- Set the **same mesh network key** on all phones.
- Real three-phone radio validation was not possible in the build environment. See
  `../docs/FIELD_TEST_3_DEVICE.md` and do not claim a hardware test that wasn't run.
- Keep the app in the foreground; this build has no foreground relay service.
- This is not an official emergency service and provides no delivery or safety guarantee.

## Verify

```powershell
Get-FileHash resqmesh-release.apk -Algorithm SHA256
```

Compare with `SHA256SUMS.txt`.
## iOS

There is no IPA in this folder. The iOS target is included in `C:\Bisu\ResQMesh\ios`;
building it requires macOS with Xcode. See `docs/IOS_BUILD.md`. iOS MultipeerConnectivity
does not interoperate with Android Nearby Connections.