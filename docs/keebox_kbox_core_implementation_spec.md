# Keebox — KBox Core Implementation Specification

**Status:** Approved design handoff for Codex  
**Scope:** Implement the shared abstract `KBox` model and the two core content entities, `KNoteBox` and `KCredentialBox`, across the existing Django backend and Flutter mobile app.  
**Out of scope:** Redesigning authentication; backup, restoration, synchronization, their models, their APIs, and their background jobs.

> **Instruction for Codex:** Implement the content system described here using the existing project conventions. The authentication system is already fully implemented and tested: **do not rebuild or modify it** except for strictly necessary, reviewed integration with the existing authenticated user/KBKey access. Do not introduce backup/synchronization designs or extra fields/collections not agreed here. The current backend SQLite records are synthetic and need not be migrated. The chosen backend database is MongoDB through the **official MongoDB Django Backend**; use the package/version compatible with the project's installed Django version.

---

## 1. Current project context

- Flutter application: primary, offline-first interface and local store for KBoxes.
- Backend: Django + Django Ninja, using Django ORM.
- Existing Django apps:
  - `core` — shared backend components.
  - `authentication` — complete and tested; owns the User, KBKey provision, and login flows.
  - `knoteboxes` — KNoteBox management.
  - `kcredentialboxes` — KCredentialBox management.
- Database target: MongoDB via **official `django-mongodb-backend`**, with Django ORM models. The existing development SQLite data is disposable test data.
- Keep `knoteboxes` and `kcredentialboxes` as separate apps and **separate actual MongoDB collections**.
- A shared `KBox` is an **abstract Django model only**. There is **no third `kboxes` collection**.
- The already-established user's **KBKey** directly encrypts/decrypts KBox content using AES-256-GCM. Do not introduce password-derived encryption keys or a new key hierarchy.

### Implementation boundary

The Flutter application knows the **decrypted content formats** and performs content validation/encryption. The backend receives opaque encrypted `payload` bytes, a separate `nonce`, and the explicitly approved unencrypted metadata. Do not put credential secrets or note bodies into MongoDB as plaintext columns.

---

## 2. Confirmed decisions — do not reopen

1. The abstract base class is named **`KBox`**.
2. Concrete models are **`KNoteBox`** and **`KCredentialBox`**, each in its existing Django app and its own collection.
3. Shared base fields are exactly: `id`, `user`, `payload`, `nonce`, `created_at`, `updated_at`.
4. The encrypted backend field is named **`payload`**, **not** `encrypted_payload`.
5. `nonce` is a **separate base-model field**, **not** a nested JSON-envelope property.
6. Do **not** introduce an `encryption_version` field.
7. Use **AES-256-GCM** with a fresh, unique 12-byte nonce for **every new encryption with the same KBKey**. Retain that nonce for decrypting the resulting ciphertext. Reading or reuploading existing ciphertext does not generate a new nonce.
8. AES-GCM's authentication tag is kept with the encrypted payload bytes (the specific cryptography library's ciphertext-plus-tag representation).
9. `KNoteBox.title` is optional (store `""` when left blank). Its note content is mandatory, plain text, and encrypted.
10. `KNoteBox.is_favorite` and `KNoteBox.tags` are **external, unencrypted, queryable fields**, reserved for future UI use. Defaults: `false` and `[]`.
11. `KCredentialBox.title` and `KCredentialBox.type` are **external, unencrypted, searchable metadata**.
12. For credentials, `payload` is **encrypted serialized JSON** whose structure depends on the fixed credential type. `note` lives **inside** this encrypted JSON, not as a model column.
13. Exactly **11** credential types are approved; see §6. Fixed identifiers should not be translated or renamed by the UI.
14. Predefined credential types support optional additional custom fields; the `custom` type requires custom fields.
15. **Validate credential content in Flutter before encryption.** The backend validates external metadata, ownership, and encrypted payload/nonce constraints; it must not need to decrypt credential JSON to validate its contents.
16. For unused **text fields**, write an empty string `""`. Arrays use `[]`; booleans retain their boolean types. Required content fields cannot be empty.
17. Do **not** add shared fields beyond those already agreed for credential payloads: `note` and `custom_fields`.
18. `general_code` uses the external KCredentialBox `title` to identify the code: do **not** add `service` or `name` to its encrypted payload.
19. The Wi-Fi credential requires **both `ssid` and `password`**; `security` is optional. Open/passwordless Wi-Fi profiles are not in scope.
20. There is **no requirement to add AES-GCM AAD for external metadata**. `id`, `title`, `type`, and other approved external fields remain plaintext in MongoDB. Do not add an AAD-based scheme without a later explicit design decision.

---

## 3. Abstract Django model: `KBox`

It exists only to share fields and behavior between the two concrete entities. Configure `Meta.abstract = True`; no collection named `KBox`/`kboxes` is to be created.

| Field | Django field | Required | Meaning |
|---|---|---|---|
| `id` | `UUIDField(primary_key=True)` | Yes | Stable KBox ID, shared across device and backend. Can be generated on-device before first local save. |
| `user` | `ForeignKey(settings.AUTH_USER_MODEL, on_delete=CASCADE)` | Yes | Owning authenticated Keebox account. |
| `payload` | `BinaryField` | Yes | AES-GCM encrypted note text or credential JSON (including auth tag). |
| `nonce` | `BinaryField` | Yes | Nonce corresponding to `payload`; 12 bytes in the agreed format. |
| `created_at` | `DateTimeField` | Yes | Original record creation time. |
| `updated_at` | `DateTimeField` | Yes | Most recent content/metadata modification time. |

**Timestamp rule:** A record created while offline retains its original creation time when later sent to the backend. Do not blindly replace client-origin `created_at`/`updated_at` with server ingestion times via `auto_now_add`/`auto_now`. Store timezone-aware UTC timestamps, and define server-side checks for validity and chronological consistency.

**Ownership rule:** In authenticated APIs, resolve `user` from the authenticated request context, never from an arbitrary user ID supplied by a client. Every read/update/delete must be scoped to that user.

**Encryption rule:** Do not use one fixed nonce across different encryptions. When a payload is changed and re-encrypted, generate a new nonce. If only external metadata changes and the payload bytes are unchanged, preserve the existing ciphertext and nonce.

**Scope of inherited fields:** No `revision`, `server_sequence`, `is_deleted`, `deleted_at`, `encryption_version`, or other speculative fields. Those were not approved for this model and must not be introduced in this implementation.

### Illustrative Django model

```python
# core/models.py
import uuid
from django.conf import settings
from django.db import models


class KBox(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    payload = models.BinaryField()
    nonce = models.BinaryField()
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()

    class Meta:
        abstract = True
```

This snippet represents the approved field set; adapt details to the existing project and the official MongoDB backend. For client-created UUIDs, the API must accept the original UUID rather than silently replacing it.

---

## 4. Concrete model: `KNoteBox`

**Django app:** `knoteboxes`  
**MongoDB collection:** `knote_boxes`  
**Inheritance:** `KNoteBox(KBox)`

| Additional field | Django field | Required? | Default | Visibility |
|---|---|---|---|---|
| `title` | `CharField(max_length=255, blank=True, default="")` | No | `""` | Plaintext searchable metadata |
| `is_favorite` | `BooleanField(default=False)` | No | `false` | Plaintext/filterable metadata |
| `tags` | `JSONField(default=list, blank=True)` | No | `[]` | Plaintext/filterable list of strings |

All six shared KBox fields are inherited.

### KNote content

- Note body is **plain text**. No rich text, Markdown editor requirement, images, or attachments in this phase.
- The **body/content is required and cannot be empty**.
- The note body is encrypted and stored in `KBox.payload`; **there is no separate plaintext `content` database field**.
- Keep the note content representation simple: Flutter encrypts the UTF-8 bytes of the note text. It does not need a JSON wrapper for a plain text KNote.
- `title`, `is_favorite`, and `tags` are not part of the encrypted body.
- `tags` is a JSON array of strings, e.g. `["work", "ideas"]`; no separate Tag model or tag collection. Validate that it is an array containing strings. Empty means `[]`.
- `is_favorite` and `tags` remain available in the data model even if the mobile UI does not expose them initially.

Example of **conceptual** MongoDB record (`payload` and `nonce` are binary, not the shown strings):

```json
{
  "id": "<note-uuid>",
  "user_id": "<user-uuid>",
  "title": "",
  "is_favorite": false,
  "tags": ["work", "ideas"],
  "payload": "<encrypted UTF-8 note text + GCM tag>",
  "nonce": "<12-byte nonce>",
  "created_at": "<UTC datetime>",
  "updated_at": "<UTC datetime>"
}
```

### Illustrative Django model

```python
# knoteboxes/models.py
from django.db import models
from core.models import KBox


class KNoteBox(KBox):
    title = models.CharField(max_length=255, blank=True, default="")
    is_favorite = models.BooleanField(default=False)
    tags = models.JSONField(default=list, blank=True)

    class Meta:
        db_table = "knote_boxes"
```

---

## 5. Concrete model: `KCredentialBox`

**Django app:** `kcredentialboxes`  
**MongoDB collection:** `kcredential_boxes`  
**Inheritance:** `KCredentialBox(KBox)`

| Additional field | Django field | Required? | Visibility |
|---|---|---|---|
| `title` | `CharField(max_length=255)` | Yes, nonempty | Plaintext searchable metadata |
| `type` | `CharField` with fixed `TextChoices` | Yes | Plaintext filterable metadata |

All six shared fields are inherited. **Do not create a separate `note` model field.**

### Decrypted content shape

- The decrypted content is a **JSON object** with type-specific fields.
- The two common payload fields are exactly `note` and `custom_fields`.
- `note`: optional string; use `""` when empty.
- `custom_fields`: optional array for predefined types (default `[]`), mandatory nonempty array for `custom` type.
- Do not repeat external `title` or `type` inside the encrypted content.
- Serializing content to JSON occurs **before** AES-256-GCM encryption. The Django/MongoDB `payload` remains `BinaryField`, not a `JSONField` containing plaintext data.

### Illustrative Django model and fixed type identifiers

```python
# kcredentialboxes/models.py
from django.db import models
from core.models import KBox


class CredentialType(models.TextChoices):
    LOGIN = "login", "Login / Authentication"
    API_KEY = "api_key", "API Keys"
    SSH_KEY = "ssh_key", "SSH Keys"
    DATABASE = "database", "Database Credentials"
    WIFI = "wifi", "Wi-Fi Credentials"
    RECOVERY_CODES = "recovery_codes", "Recovery Codes"
    SECURITY_QUESTION = "security_question", "Security Questions"
    LICENSE_KEY = "license_key", "Software License"
    ENCRYPTION_KEY = "encryption_key", "Encryption Keys"
    GENERAL_CODE = "general_code", "General Codes"
    CUSTOM = "custom", "Custom Credentials"


class KCredentialBox(KBox):
    title = models.CharField(max_length=255)
    type = models.CharField(max_length=50, choices=CredentialType.choices)

    class Meta:
        db_table = "kcredential_boxes"
```

The `TextChoices` values are persisted identifiers; user-facing descriptions may be localized without modifying them.

---

## 6. Exactly 11 credential types — encrypted JSON schemas

Fields listed as optional are represented as an empty string `""` when they are unused **and textual**. Array-valued properties use `[]`; boolean fields use booleans when set. For values with other concrete types (e.g. integer ports), retain that type when supplied; do not convert populated numbers to strings. Required values cannot be blank. All payloads also contain the shared `note` and `custom_fields` properties.

### 6.1 `login` — Login / Authentication

| Field | Type | Requirement |
|---|---|---|
| `username` | string | Optional |
| `email` | string | Optional |
| `password` | string | **Required, nonempty** |
| `website` | string | Optional |

Example:

```json
{
  "username": "nelson_dev",
  "email": "nelson@example.com",
  "password": "example-secret",
  "website": "https://github.com",
  "note": "My personal account",
  "custom_fields": []
}
```

Validation: password present/nonempty; email format valid when entered; website is a valid HTTP(S) URL when entered. Username and email need not both be set.

### 6.2 `api_key` — API Keys

| Field | Type | Requirement |
|---|---|---|
| `key` | string | **Required, nonempty** |
| `service` | string | Optional |
| `environment` | string | Optional |
| `base_url` | string | Optional |
| `expires_at` | ISO 8601 string | Optional |

```json
{
  "key": "sk-example-secret",
  "service": "Example API",
  "environment": "development",
  "base_url": "https://api.example.com",
  "expires_at": "",
  "note": "Development key",
  "custom_fields": []
}
```

Validate nonempty key; HTTP(S) URL and ISO 8601 timestamp only if those values are supplied. This category can also store similar API-access tokens; no separate `access_token` category.

### 6.3 `ssh_key` — SSH Keys

| Field | Type | Requirement |
|---|---|---|
| `private_key` | string (multiline) | Conditional |
| `public_key` | string | Conditional |
| `passphrase` | string | Optional |
| `host` | string | Optional |
| `username` | string | Optional |
| `port` | integer when entered | Optional |

```json
{
  "private_key": "-----BEGIN OPENSSH PRIVATE KEY-----\n...\n-----END OPENSSH PRIVATE KEY-----",
  "public_key": "ssh-ed25519 AAAA... user@device",
  "passphrase": "",
  "host": "server.example.com",
  "username": "root",
  "port": 22,
  "note": "Development server",
  "custom_fields": []
}
```

At least **one** of `private_key` or `public_key` must be nonempty. Optional port, when entered, is an integer from 1 to 65535. Preserve original multiline key formatting; do not trim or transform secret key material.

### 6.4 `database` — Database Credentials

| Field | Type | Requirement |
|---|---|---|
| `engine` | string | Optional |
| `host` | string | Optional |
| `port` | integer when entered | Optional |
| `database` | string | Optional |
| `username` | string | Optional |
| `password` | string | Conditional |
| `connection_uri` | string | Conditional |
| `ssl` | boolean when entered | Optional |

```json
{
  "engine": "postgresql",
  "host": "db.example.com",
  "port": 5432,
  "database": "project_db",
  "username": "admin",
  "password": "example-secret",
  "connection_uri": "",
  "ssl": true,
  "note": "Primary database",
  "custom_fields": []
}
```

At least **one** of `password` or `connection_uri` must be nonempty, as already specified. Optional port is 1–65535. Do not limit `engine` to a hardcoded exhaustive enum. Some other connection methods may later require different credential details; do not redesign that now.

### 6.5 `wifi` — Wi-Fi Credentials

| Field | Type | Requirement |
|---|---|---|
| `ssid` | string | **Required, nonempty** |
| `password` | string | **Required, nonempty** |
| `security` | string | Optional |
| `username` | string | Optional |
| `hidden` | boolean | Optional |

```json
{
  "ssid": "HomeNetwork",
  "password": "example-wifi-password",
  "security": "",
  "username": "",
  "hidden": false,
  "note": "Home Wi-Fi",
  "custom_fields": []
}
```

Validate **both SSID and password**. Security mode is **not required**. Passwordless/open networks are **not** included in this flow.

### 6.6 `recovery_codes` — Recovery Codes

| Field | Type | Requirement |
|---|---|---|
| `service` | string | Optional |
| `codes` | array of strings | **Required, at least one nonempty code** |
| `website` | string | Optional |

```json
{
  "service": "GitHub",
  "codes": ["12345-67890", "23456-78901"],
  "website": "https://github.com",
  "note": "Unused recovery codes",
  "custom_fields": []
}
```

Preserve recovery codes **exactly** as strings, including leading zeros and punctuation. Validate optional website as HTTP(S) URL.

### 6.7 `security_question` — Security Questions

| Field | Type | Requirement |
|---|---|---|
| `question` | string | **Required, nonempty** |
| `answer` | string | **Required, nonempty** |

```json
{
  "question": "What was the name of your first school?",
  "answer": "Example Primary School",
  "note": "Account recovery",
  "custom_fields": []
}
```

Both the question and answer are **inside encrypted JSON**; the external title can identify the corresponding service/account.

### 6.8 `license_key` — Software License

| Field | Type | Requirement |
|---|---|---|
| `product` | string | Optional |
| `license_key` | string | **Required, nonempty** |
| `registered_email` | string | Optional |
| `vendor` | string | Optional |
| `expires_at` | ISO 8601 string | Optional |

```json
{
  "product": "Example Software Pro",
  "license_key": "XXXX-YYYY-ZZZZ-1234",
  "registered_email": "nelson@example.com",
  "vendor": "Example Software",
  "expires_at": "",
  "note": "Annual license",
  "custom_fields": []
}
```

Validate license key nonempty; optional email and expiry formats when supplied. Do not impose a universal license-key pattern.

### 6.9 `encryption_key` — Encryption Keys

| Field | Type | Requirement |
|---|---|---|
| `key` | string | **Required, nonempty** |
| `algorithm` | string | Optional |
| `format` | string | Optional |
| `purpose` | string | Optional |

```json
{
  "key": "example-encoded-key-material",
  "algorithm": "AES-256",
  "format": "base64",
  "purpose": "File encryption",
  "note": "Personal project key",
  "custom_fields": []
}
```

Store key values exactly as entered. Do not restrict algorithms to a fixed list or modify the user's key material.

### 6.10 `general_code` — General Codes

| Field | Type | Requirement |
|---|---|---|
| `code` | string | **Required, nonempty** |

```json
{
  "code": "AC-1234-5678",
  "note": "Office entrance code",
  "custom_fields": []
}
```

**Do not put `service` or `name` in this payload.** The parent KCredentialBox's external **`title`** already identifies the code.

### 6.11 `custom` — Custom Credentials

| Field | Type | Requirement |
|---|---|---|
| `custom_fields` | array of field objects | **Required, nonempty** |
| `note` | string | Optional (`""` when unused) |

```json
{
  "custom_fields": [
    {
      "id": "891fd1b4-499e-4ed9-bace-6e20b6ad58ee",
      "label": "Client ID",
      "value": "client-12345",
      "is_secret": false
    },
    {
      "id": "db0f3d4d-dfc1-4e22-bdc8-b332c45261af",
      "label": "Client Secret",
      "value": "example-secret",
      "is_secret": true
    }
  ],
  "note": "Private integration"
}
```

No predefined type-specific fields apply. Custom fields are defined by the user.

---

## 7. Standard custom-field format

Every predefined credential type may include `custom_fields: []` or user-defined entries. For `custom`, at least one entry is required.

```json
{
  "id": "<unique UUID string within this credential>",
  "label": "Security Answer",
  "value": "Example answer",
  "is_secret": true
}
```

| Property | Type | Rule |
|---|---|---|
| `id` | UUID string | Required and unique within one KCredentialBox |
| `label` | string | Required, nonempty |
| `value` | string | String value; may be `""` when unused |
| `is_secret` | boolean | Required flag for masking in the UI |

- `is_secret` only controls **visual masking in Flutter**; all custom field values are inside the encrypted payload regardless of this flag.
- Users may add, edit, remove, and reorder custom fields.
- Do not introduce a separate MongoDB collection/model for custom fields.
- Do not add extra shared credential JSON properties.

---

## 8. Validation and serialization requirements

### Flutter-side (before encryption)

- Choose the schema based on the fixed external `type` identifier.
- Validate the already-approved required fields and conditional requirements in §6.
- Required text fields must be nonempty. Optional unused text fields serialize as `""`.
- Shared `note` serializes as `""` if unused; shared `custom_fields` as `[]` if unused.
- Arrays and booleans keep their JSON types. Numeric fields remain numeric when set; if a type-specific optional numeric field is unset, handle absence simply and consistently without inventing new common fields.
- Validate format only when relevant (e.g., supplied email, HTTP(S) website URL, ISO date, port range).
- Preserve the exact content of passwords, keys, codes, secret answers, and other secrets: do **not** auto-trim, normalize case, mask in storage, or rewrite user-entered values.
- Construct the JSON payload, serialize UTF-8, encrypt once with the user's existing KBKey and a **fresh** nonce, then store/transmit ciphertext + tag as `payload` and the nonce separately.
- Decrypt locally for display/editing; do not log plaintext credential payloads.

### Backend-side (without decryption)

- Validate authenticated ownership and immutable IDs/user association.
- Validate external `title` (KCredentialBox required, KNoteBox optional), fixed credential `type`, KNote tags as string array, KNote favorite as boolean.
- Validate `payload` is present and binary and `nonce` is present and exactly 12 bytes.
- Enforce reasonable size bounds using existing project conventions (no specific limits were agreed, so **do not invent product limits** without review).
- Do **not** attempt to inspect the encrypted credential JSON or plaintext note content in MongoDB.
- Do not expose another user's KBox by ID or cross-user queries.
- Avoid logging payloads/nonces or plaintext secrets.

### Encryption details

- AES-256-GCM with the existing per-user KBKey (unchanged key architecture).
- Generate a cryptographically random 96-bit/12-byte nonce **per encryption operation** under the KBKey; avoid nonce reuse.
- Preserve the GCM tag in the returned ciphertext representation.
- Decrypt using **the stored nonce and ciphertext**. A new nonce is not needed for reads.
- External searchable metadata is intentionally plaintext. **Do not introduce AAD binding or an alternate envelope** without explicit approval.

---

## 9. Querying, indexes and separation

- KNoteBox records reside exclusively in **`knote_boxes`**; KCredentialBox records exclusively in **`kcredential_boxes`**.
- `KBox` is abstract and does not create its own collection.
- All queries must be scoped by authenticated `user`.
- Support searching KNotes and KCredentials by external `title`, and filtering credentials by fixed external `type`.
- Support the model's external `is_favorite` and `tags` fields for KNotes, even if the initial UI does not use them.
- Choose compatible indexes for user-scoped queries and external metadata with the official MongoDB Django Backend. Do not invent full-text indexes or complex search behavior without a concrete requirement.
- Only the encrypted payload contents are nonsearchable server-side; any search within note bodies or credential secrets must occur locally after decrypting, if implemented.

---

## 10. Suggested implementation sequence for Codex

1. **Inspect the existing project** and note the installed Django and MongoDB backend versions, app layout, naming conventions, API approach, and current Flutter/local-storage architecture. Do not modify authentication's completed workflows.
2. **Configure/verify MongoDB via the official MongoDB Django Backend** for the current Django version. Existing SQLite content is synthetic and may be discarded; apply a clean compatible schema rather than migrating test records. Keep the existing authentication models and business rules intact.
3. **Implement abstract `core.models.KBox`** with precisely the six shared fields.
4. **Implement concrete Django models** in `knoteboxes` and `kcredentialboxes`, their named collections, fixed `CredentialType`, and straightforward indexes/constraints.
5. **Implement or integrate Flutter content data structures and validation** for plain-text KNotes and all 11 fixed credential JSON formats. Optional text values become `""`, and empty field lists `[]`.
6. **Use the existing KBKey access** to encrypt/decrypt KNote text and serialized KCredential JSON using AES-256-GCM and unique nonces. Never store decrypted bodies/secrets in MongoDB.
7. **Implement core KBox create/read/update/delete operations** according to the project's existing patterns and local-first behavior. Keep the work strictly within the content feature, without introducing cloud backup scheduling or synchronization protocols.
8. **Test** models, schema validation, crypto round trips, metadata search, ownership isolation, and behavior on a real Flutter device where practical.

### API routes

The exact endpoint names, request schemas, and response schemas have **not** been separately approved. Follow the repository's existing Django Ninja routing conventions instead of asserting arbitrary new routes as previously agreed decisions. The API must handle authenticated CRUD for each concrete KBox type and preserve the agreed encrypted/plaintext separation.

### Local SQLite schema

The exact Flutter SQLite table definitions have **not** been approved here. Preserve the already agreed local-first role and equivalent fields/content behavior, but do not present speculative SQL table names or future backup metadata as finalized decisions.

---

## 11. Acceptance criteria

- [ ] The Django `KBox` base is abstract; MongoDB has **no** generic `kboxes` collection.
- [ ] MongoDB contains separate `knote_boxes` and `kcredential_boxes` collections.
- [ ] Both models inherit `id`, `user`, `payload`, `nonce`, `created_at`, `updated_at`; no `encryption_version`.
- [ ] `KNoteBox.title` can be `""`, but a KNote with empty content is rejected by Flutter validation.
- [ ] `KNoteBox.is_favorite` defaults to `false`; `tags` defaults to `[]` and contains strings.
- [ ] `KCredentialBox.title` is required and searchable; `type` is one of the 11 immutable identifiers.
- [ ] `KCredentialBox` has **no external `note`** field. `note` exists only inside encrypted credential JSON.
- [ ] All 11 type-specific schemas and their previously agreed required/optional rules pass Flutter validation tests.
- [ ] Every predefined credential type supports optional `custom_fields`; `custom` requires a nonempty list.
- [ ] Wi-Fi requires nonempty `ssid` and nonempty `password` while leaving `security` optional.
- [ ] `security_question` requires question + answer.
- [ ] `general_code` requires code; its only name is the external `title`.
- [ ] Unused optional text values serialize as `""`; empty arrays serialize as `[]`.
- [ ] KNote content is UTF-8 plain text before encryption; credential content is JSON before encryption.
- [ ] Only ciphertext (`payload`) plus the corresponding nonce is stored remotely for content; secrets and note bodies are not stored in plaintext.
- [ ] Every re-encryption produces a fresh nonce; decryption uses the stored nonce; GCM integrity failures reject tampered ciphertext.
- [ ] KBox CRUD and metadata queries enforce authenticated ownership.
- [ ] The completed authentication workflows remain unchanged and their existing tests still pass against the chosen backend.
- [ ] **No** backup, restoration, sync app, sync collections, outbox, conflict resolution, or backup background worker is introduced by this task.

---

## 12. Deliberate exclusions / not-yet-agreed details

Do **not** expand the implementation into any of the following on the assumption they were approved:

- Authentication redesign, OTP flows, PIN flows, registration changes, or KBKey format changes.
- Backup or restoration architecture, backup snapshots, schedules, incremental backup mechanics, or related backend apps.
- Two-way synchronization, change-feed collections, idempotency-operation collections, revision counters, tombstones, or device conflict policies.
- Extra KBox base fields such as `encryption_version`, `schema_version`, `server_sequence`, or `is_deleted`.
- New KCredential types beyond the eleven listed in §6.
- Separate credential `note` database column, or duplicate `name`/`service` field in `general_code`.
- Note rich text, note attachments, folders, separate tag collections, or credential-use automation.
- New encryption schemes, AAD binding, password-derived keys, or a new recovery mechanism.

**End of scope.** This document is the handoff for the **KBox core and its two content entities only**.
