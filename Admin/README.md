# Sentinel Admin

This folder is separate from the main Sentinel capture app.

## Structure

- `App/`
  - Flutter admin app for assigned case list, evidence review, and report review
- `Backend/`
  - Node/Express admin backend for fetching cases from MongoDB, decrypting evidence, and updating lifecycle status

## Admin App Features

- case list for cases assigned to an admin
- evidence review button
- report review button
- lifecycle update flow:
  - `submitted`
  - `underreview`
  - `investigating`
  - `resolved`
  - `closed`

## Backend Endpoints

- `GET /api/admin/cases?assignedTo=<adminId>`
- `GET /api/admin/cases/:incidentId/evidence`
- `PATCH /api/admin/cases/:incidentId/status`

## Notes

- evidence endpoint downloads encrypted media using the CID
- backend decrypts with the shared AES key
- frontend receives decrypted bytes for review
- for current Sentinel data, raw hash verification is only performed if a raw file hash field is available
- case metadata is expected in MongoDB, while encrypted evidence files remain on web3.storage / Storacha
