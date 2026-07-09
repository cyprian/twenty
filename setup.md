# Eyepic CRM Deployment Plan

Target:

- App: Eyepic CRM, based on `cyprian/twenty`
- Server: Hetzner `167.233.225.220`
- Domain: `crm.eyepic.io`
- Runtime path: `/opt/twenty-runtime`
- Repo path on server: `/opt/apps/twenty`
- Deploy branch: `production`

## Requirements

- DNS `A` record for `crm.eyepic.io` points to `167.233.225.220`.
- The local SSH key can connect as `root@167.233.225.220`.
- Docker Engine, Docker Compose plugin, and Caddy are installed on the server.
- Runtime secrets live only on the server in `/opt/twenty-runtime/.env`.

## Architecture

- Caddy terminates HTTPS for `crm.eyepic.io`.
- Caddy reverse proxies to Twenty on `127.0.0.1:3000`.
- Twenty runs with Docker Compose:
  - `server`: custom image built from this repository.
  - `worker`: same custom image.
  - `db`: Postgres 16.
  - `redis`: Redis 7.
- The custom image is tagged as:
  - `eyepic/twenty:<git-short-sha>`
  - `eyepic/twenty:production`

## Bootstrap Plan

1. Confirm SSH access to the server.
2. Install Docker Engine and Docker Compose plugin.
3. Install and enable Caddy.
4. Create `/opt/apps` and `/opt/twenty-runtime`.
5. Clone `https://github.com/cyprian/twenty.git` into `/opt/apps/twenty`.
6. Check out the `production` branch.
7. Generate Twenty runtime secrets on the server.
8. Write `/opt/twenty-runtime/.env`.
9. Install `/opt/deploy-twenty.sh`.
10. Install the Caddy site config for `crm.eyepic.io`.
11. Run the first deployment.

## Deploy Plan

1. Push local `main` to `origin/production`.
2. SSH into `root@167.233.225.220`.
3. Fetch and reset `/opt/apps/twenty` to `origin/production`.
4. Copy `self-hosting/eyepic/docker-compose.yml` into `/opt/twenty-runtime`.
5. Build the custom Twenty Docker image from the checked-out commit.
6. Back up Postgres if the database container already exists.
7. Start or update the Docker Compose stack.
8. Wait for `http://127.0.0.1:3000/healthz`.
9. Verify `https://crm.eyepic.io/healthz`.

## Operating Commands

Deploy from local machine:

```sh
./deploy.sh
```

Inspect server containers:

```sh
ssh root@167.233.225.220 'cd /opt/twenty-runtime && docker compose ps'
```

Inspect server logs:

```sh
ssh root@167.233.225.220 'cd /opt/twenty-runtime && docker compose logs --tail=200 server worker'
```

Check health:

```sh
curl -fsS https://crm.eyepic.io/healthz
```

## Initial State

- Workspace: `Eyepic CRM`
- Workspace URL: `https://crm.eyepic.io/`
- Initial user: `cyprian@eyepic.io`
- SMTP: deferred; current email driver logs email output.

## Verification Checklist

- `crm.eyepic.io` serves through Caddy with HTTPS.
- `/healthz` returns `{"status":"ok"}`.
- `server`, `worker`, `db`, and `redis` containers are running.
- Postgres and Redis containers are healthy.
- Twenty workspace activation status is `ACTIVE`.
- Initial user can sign in and sees the `Eyepic CRM` workspace.
