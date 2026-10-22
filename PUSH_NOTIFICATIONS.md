# Miner service progress push notifications

The app and database now create one progress notification for the service owner and each participating miner when service stages or milling batch milestones change. Supabase sends each new notification row to the `service-progress-push` Edge Function, which delivers it through Firebase Cloud Messaging (FCM).

## Firebase app setup

Android push is configured for Firebase project `egres-43a8a` and application ID `com.example.egres` using `android/app/google-services.json` and `lib/firebase_options.dart`. iOS is not configured yet.

1. The Android package ID must remain `com.example.egres` to match the Firebase app registered in `google-services.json`.
2. Build and install the configured Android app. When a miner opens the app, it asks for push permission and registers that device's Firebase Installation ID (FID) in Supabase. Pushes received while the app is open appear as an in-app banner; pushes received in the background are displayed by the phone OS.
3. Create a Firebase service account with permission to send Firebase Cloud Messaging messages. Keep its private key on the server; never add it to the Flutter app or source control.

To enable iOS later, register its bundle ID in Firebase, add `GoogleService-Info.plist`, configure Push Notifications and Background Modes in the iOS Runner target, and upload an APNs authentication key in Firebase.

## Supabase setup

1. Apply `database/miner_service_push_notifications.sql` to the Supabase project. It enables row level security for device registrations and notification records.
2. Deploy `supabase/functions/service-progress-push` with `verify_jwt = false` (configured in `supabase/config.toml`). Set these Edge Function secrets:
   - `FCM_PROJECT_ID`: Firebase project ID.
   - `FCM_CLIENT_EMAIL`: Firebase service account email.
   - `FCM_PRIVATE_KEY`: service account private key, preserving newlines or using `\n` escapes.
   - `PUSH_WEBHOOK_SECRET`: a long random secret shared with the webhook.
3. In the Supabase SQL Editor, store the same webhook secret in Vault:
   ```sql
   select vault.create_secret(
     '<the same PUSH_WEBHOOK_SECRET value>',
     'service_progress_push_webhook_secret'
   );
   ```
   Then run `database/service_progress_push_webhook.sql` after replacing `YOUR_PROJECT_REF` with the Supabase project ref. This creates the `pg_net` trigger that sends notification rows to the Edge Function. If the Vault secret is missing or webhook queuing fails, the trigger skips push delivery and does not block service progress updates.

The webhook is the delivery link between database progress changes and phone notifications. Until Firebase credentials and this webhook are configured, the database can record progress notifications, but it cannot deliver push messages to phones.
