# KV Secret Expiry Alert

Power Automate (legacy package) that scans **Azure Key Vault** secrets daily and posts a **Microsoft Teams** alert when `validityEndTime` is within warning thresholds — without reading secret values.

## What the flow does

1. Runs every day at **09:00** (`SE Asia Standard Time`)
2. Calls Key Vault **List secrets**
3. For each **enabled** secret that has `validityEndTime`:
   - Computes days remaining
   - If `<= 30` days, appends to an alert list with severity:
     - `WARNING` — ≤ 30 days
     - `URGENT` — ≤ 14 days
     - `CRITICAL` — ≤ 7 days
     - `CRITICAL - EXPIRED` — ≤ 0 days
4. If the list is non-empty, posts one HTML summary message to a Teams channel

```text
Recurrence (daily)
  → Initialize AlertItems / thresholds
  → List secrets (Key Vault)
  → For each secret with expiry
      → daysRemaining = (expires - now)
      → if daysRemaining <= 30 → append severity + name + expiry
  → if any alerts → Post message to Teams
```

## Repo layout

```text
kv-secret-expiry-alert/
├── package/                          # Source for the legacy zip
│   ├── manifest.json
│   └── Microsoft.Flow/
│       └── flows/
│           ├── manifest.json
│           └── a1b2c3d4-.../
│               ├── definition.json   # Flow logic
│               ├── apisMap.json
│               └── connectionsMap.json
├── templates/
│   └── teams-message.html            # Reference HTML for Teams message
├── dist/                             # Built zip (gitignored)
├── build-package.ps1
└── README.md
```

## Build the import zip

From PowerShell:

```powershell
cd E:\code-project\kv-secret-expiry-alert
.\build-package.ps1
```

Output: `dist\KV-Secret-Expiry-Alert.zip`

The zip root must contain `manifest.json` and `Microsoft.Flow/` (no wrapping folder). The build script enforces this.

---

## Path A — Import Package (Legacy)

> Hand-crafted legacy packages sometimes fail import. If Path A fails, use **Path B**.

1. Open [https://make.powerautomate.com](https://make.powerautomate.com)
2. Select the correct environment
3. **My flows** → **Import** → **Import Package (Legacy)**
4. Upload `dist\KV-Secret-Expiry-Alert.zip`
5. For the flow row: **Create as new**
6. Under Related resources, configure connections:
   - **Azure Key Vault** — select or create a connection that can **list** secrets in your vault
   - **Microsoft Teams** — select or create a connection that can post to your team/channel
7. Click **Import**
8. After import, open the flow and set placeholders (see below), then turn the flow **On**

### Placeholders to edit after import

In `Post_message_Teams` (or via the designer):

| Placeholder | Where | Example |
|-------------|--------|---------|
| `PLACEHOLDER_TEAM_ID` | Teams action → Team | Team / Group ID (GUID) |
| `PLACEHOLDER_CHANNEL_ID` | Teams action → Channel | Channel ID (e.g. `19:...@thread.tacv2`) |

Optional edits:

| Setting | Default | Notes |
|---------|---------|--------|
| Recurrence time | 09:00 | Trigger → Recurrence |
| Time zone | `SE Asia Standard Time` | Trigger → Recurrence |
| `WarningDays` | 30 | Initialize variable |
| `UrgentDays` | 14 | Initialize variable |
| `CriticalDays` | 7 | Initialize variable |

### Key Vault connection tips

- Prefer a connection / identity with **Key Vault Secrets User** (or equivalent list permission).
- This flow uses **List secrets** and reads **metadata only** (`name`, `isEnabled`, `validityEndTime`). It does **not** call Get secret value.
- Ensure every production secret has the native **Expires** attribute set in Key Vault (maps to connector field `validityEndTime`).

### How to find Team / Channel IDs

1. In Teams, open the channel → **…** → **Get link to channel**
2. Or create a temporary flow with “Post message in a chat or channel”, pick Team/Channel in the UI, then peek code / run history to copy IDs
3. Paste IDs into the Teams action after import

---

## Path B — Manual rebuild (recommended fallback)

If legacy import fails (“Something went wrong” / invalid package), rebuild in the designer using this repo as the spec.

1. **Create** → **Scheduled cloud flow**
   - Name: `KV-Secret-Expiry-Alert`
   - Repeat every **1 Day** at **09:00** (timezone SE Asia Standard Time)
2. Add actions in order (names can match `definition.json`):

| # | Action | Details |
|---|--------|---------|
| 1 | Initialize variable | `AlertItems` = Array `[]` |
| 2 | Initialize variable | `WarningDays` = Integer `30` |
| 3 | Initialize variable | `UrgentDays` = Integer `14` |
| 4 | Initialize variable | `CriticalDays` = Integer `7` |
| 5 | Azure Key Vault → **List secrets** | Connect to your vault |
| 6 | **Apply to each** | Input: `body/value` from List secrets |
| 7 | Condition (inside loop) | `validityEndTime` is not empty **AND** `isEnabled` equals `true` |
| 8 | Compose (yes branch) | Days remaining — see expression below |
| 9 | Condition | Days remaining ≤ `WarningDays` |
| 10 | Compose | Severity — see expression below |
| 11 | Append to array variable | Append object to `AlertItems` |
| 12 | After loop: Condition | `length(AlertItems) > 0` |
| 13 | Compose + **Post message in a chat or channel** | HTML summary; pick Team/Channel in UI |

### Days remaining expression

```text
div(
  sub(
    ticks(items('Apply_to_each')?['validityEndTime']),
    ticks(utcNow())
  ),
  864000000000
)
```

### Severity expression

```text
if(
  lessOrEquals(outputs('Compose_DaysRemaining'), 0),
  'CRITICAL - EXPIRED',
  if(
    lessOrEquals(outputs('Compose_DaysRemaining'), variables('CriticalDays')),
    'CRITICAL',
    if(
      lessOrEquals(outputs('Compose_DaysRemaining'), variables('UrgentDays')),
      'URGENT',
      'WARNING'
    )
  )
)
```

### Append object shape

```json
{
  "severity": "<Compose_Severity>",
  "secret": "<secret name>",
  "daysRemaining": "<Compose_DaysRemaining>",
  "validityEndTime": "<validityEndTime>"
}
```

See also [`templates/teams-message.html`](templates/teams-message.html) for a richer HTML layout you can paste into the Teams message body.

Full machine-readable definition:  
[`package/Microsoft.Flow/flows/a1b2c3d4-e5f6-7890-abcd-ef1234567890/definition.json`](package/Microsoft.Flow/flows/a1b2c3d4-e5f6-7890-abcd-ef1234567890/definition.json)

---

## Test plan

1. In Key Vault, create secret `test-expiry-alert`
2. Set **Expires** to ~2 days from now
3. Run the flow **manually**
4. Expect a Teams message with severity **CRITICAL** (≤ 7 days)
5. Change Expires to ~40 days → re-run → **no** Teams message
6. Set Expires to yesterday → re-run → **CRITICAL - EXPIRED**
7. Confirm the message shows **secret name + expiry only** (never the secret value)

## Security notes

- Do **not** post secret values to Teams
- Grant the flow identity the least privilege needed to **list** secret metadata
- Keep runbooks / owner contacts outside the secret value (use Key Vault tags such as `owner`, `system` if you extend the flow later)

## License

Internal use — adjust as needed for your organization.
