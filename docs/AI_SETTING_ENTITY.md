# AI Setting Entity Documentation

This document describes the `AiSetting` model and the `ai_settings` table introduced for storing integer-based AI configuration values.

## 1. What Is AiSetting?

`AiSetting` is a simple key-value style configuration record where:
- `label` is the setting key/name.
- `setting_value` is the integer value for that key.

Primary source files:
- `app/models/ai_setting.rb`
- `db/migrate/20260921082319_create_ai_settings.rb`

## 2. Database Schema

Table: `ai_settings`

Columns:
- `id` (bigint, primary key)
- `label` (string)
- `setting_value` (integer)
- `created_at` (datetime)
- `updated_at` (datetime)

Schema reference:
- `db/schema.rb`

## 3. Rails Model

Model class:
- `AiSetting < ApplicationRecord`

Current behavior:
- No custom validations.
- No custom associations.
- No scopes or callbacks.

## 4. Example Usage

Create a setting:

```ruby
AiSetting.create!(label: "max_retries", setting_value: 3)
```

Read a setting:

```ruby
AiSetting.find_by(label: "max_retries")
```

Update a setting:

```ruby
setting = AiSetting.find_by!(label: "max_retries")
setting.update!(setting_value: 5)
```

## 5. Suggested Hardening (Optional)

If this table is used as a global settings registry, consider:
- Validation: `label` presence.
- Validation: `setting_value` numericality and presence.
- Uniqueness: index and validation on `label`.

Example migration direction:
- Add a unique index on `label` when duplicate labels should be disallowed.

## 6. Notes

- Table and model follow Rails conventions (`AiSetting` -> `ai_settings`).
- This entity is intentionally minimal and can be extended with validations and domain methods as requirements evolve.
