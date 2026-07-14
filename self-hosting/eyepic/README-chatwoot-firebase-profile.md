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
