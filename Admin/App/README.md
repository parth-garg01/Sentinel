# Sentinal App

Flutter client for Sentinel, a privacy-first emergency reporting system
disguised as a calculator.

## Current Upload Architecture

The mobile client:
- captures image evidence
- hashes it with SHA-256
- encrypts the bytes locally
- sends the encrypted file to a Sentinel backend

The backend:
- holds the Storacha agent key and UCAN delegation
- uploads the encrypted payload to Storacha/IPFS
- returns the CID to the mobile app

This is safer than embedding Storacha credentials directly in Flutter.

## Required Runtime Config

The upload service now expects a backend URL via `--dart-define`:

```bash
flutter run --dart-define=SENTINEL_BACKEND_URL=https://your-api.example.com
```

Optional API auth token:

```bash
flutter run --dart-define=SENTINEL_BACKEND_URL=https://your-api.example.com --dart-define=SENTINEL_API_TOKEN=your-token
```

## Important Files

- `lib/main.dart`: app entry point and Firebase init
- `lib/screens/calculator_screen.dart`: disguised calculator unlock UI
- `lib/screens/report_screen.dart`: image/video capture, hashing, encryption, local queue
- `lib/screens/history_screen.dart`: incident history, sync status, chain verification
- `lib/services/ipfs_service.dart`: backend-facing Storacha upload client
- `lib/services/encryption_service.dart`: AES encryption before upload
- `lib/services/hash_service.dart`: SHA-256 and chain hashing
- `lib/services/local_evidence_service.dart`: SQLite-backed local incident ledger
- `lib/services/evidence_sync_service.dart`: connectivity-aware upload retry service
- `lib/services/blockchain_service.dart`: simulated blockchain metadata
- `lib/services/firestore_service.dart`: metadata persistence

## Notes

- The Flutter app should not store Storacha private keys or delegation proofs.
- Evidence is uploaded only after local encryption.
- Evidence is saved locally first so offline capture is preserved.
- Firestore stores metadata; Storacha stores encrypted file content.
