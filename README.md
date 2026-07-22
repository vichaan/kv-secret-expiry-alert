# KV Secret Expiry Alert

A small Power Automate flow that checks Azure Key Vault every day and sends a Microsoft Teams message before secrets expire — so tokens and keys don’t fail silently.

It only looks at expiry dates (metadata). It never reads or posts secret values.

## Features

- Daily scan of Key Vault secrets
- Alerts at **30 / 14 / 7** days before expiry (and when already expired)
- One summary message in Teams instead of spam
- Safe by design: names and dates only

## How to use

1. Clone this repo
2. In PowerShell, run:

   ```powershell
   .\build-package.ps1
   ```

   This creates `dist/KV-Secret-Expiry-Alert.zip`

3. Open [Power Automate](https://make.powerautomate.com) → **My flows** → **Import** → **Import Package (Legacy)**
4. Upload the zip, connect **Azure Key Vault** and **Microsoft Teams**, then import
5. Open the flow, pick your Team/Channel, turn it **On**

## After import

- Make sure secrets in Key Vault have an **Expires** date set
- The Key Vault connection only needs permission to **list** secrets (not read values)
- Optional: change the daily run time or warning thresholds in the flow

## Quick test

Create a test secret that expires in about 2 days, run the flow manually, and confirm a Teams alert appears. A secret with 40+ days left should not alert.

## Note

If the zip import fails, create a scheduled cloud flow in Power Automate and follow the logic under `package/` (list secrets → check expiry → post to Teams).
