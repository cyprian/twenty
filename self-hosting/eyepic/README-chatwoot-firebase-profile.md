# Firebase Profile integration

This deployment builds a version-pinned Chatwoot overlay that adds the **Firebase Profile** inbox integration. An enabled inbox lets agents press **Check app profile** for a conversation contact and retrieves:

- the Firebase Auth user matching the contact email;
- `users_credits/{uid}`; and
- `subscriptions/{uid}`.

## Provisioning

1. Create a Firebase service account with read-only Firebase Auth and Cloud Firestore access.
2. On the production host, store its JSON at `/opt/chatwoot-runtime/firebase-service-account.json` with mode `600`.
3. Set `FIREBASE_PROFILE_ENABLED=true` in `/opt/chatwoot-runtime/.env` and run `/opt/apps/twenty/self-hosting/eyepic/bootstrap-chatwoot.sh`.
4. In Chatwoot, enable **Firebase Profile** for each required inbox under Settings → Integrations.

The service account is mounted only in the internal `firebase-profile` container. Chatwoot sends lookups to it over the Docker network, and the browser never receives Firebase credentials.

## Eye.photo Studio integration

The same Chatwoot overlay also adds the **Eye.photo** inbox integration. It shows the studios associated with the conversation contact's email in the **Eye.photo data** conversation-sidebar section. Each enabled inbox has its own Eye.photo admin API key.

### Provisioning

1. Create an Eye.photo **admin-scoped** API key owned by a super admin. The Studio lookup endpoint requires this scope.
2. Deploy the overlay normally; no additional container or environment variable is required. The server calls `https://eye.photo/api/admin/studios/lookup` directly.
3. In Chatwoot, open Settings → Integrations → **Eye.photo**, add the key, and select the inbox to which it applies.
4. Open a conversation from that inbox. The Eye.photo data section looks up the contact email and displays each matching studio's logo, plan, status, photo count, and users.

The bootstrap script configures Rails Active Record Encryption for the deployment, and the key is moved out of generic integration settings into Chatwoot's encrypted hook-token column. It is never returned to the dashboard or sent to the browser. To rotate a key, remove the existing Eye.photo inbox integration and create it again with the replacement key.
