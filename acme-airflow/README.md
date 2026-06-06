# acme-airflow

Acme Data Warehouse orchestration. A single Airflow instance (production) runs in Docker
on an Ubuntu server and orchestrates the **dbt transformation layer** — it builds `staging → int →
mart` (+ tests) in the `SAP_MIRROR` SQL Server, which feeds Power BI.

> **Portfolio note.** This is a real production project, **anonymized** and translated to English for
> publication. "Acme" is a fictitious stand-in for the real company; credentials and infrastructure
> identifiers were removed (secrets live in Airflow Connections/Variables encrypted with the Fernet
> key, never committed). The engineering — data-aware scheduling (Airflow Assets), the single-slot
> dbt pool, the self-skipping cadence windows, the isolated venvs — is that of the original project.
> The dbt warehouse, SAP ingestion and SharePoint connector are sibling folders in this monorepo
> (`acme-dw-dbt`, `acme-sap-ingestion`, `acme-sharepoint-connector`).

Current scope at a glance:

- The **dbt transformation runs across 6 DAGs split by domain/cadence** (see [DAGs](#dags)) — there
  is no longer a single scheduled monolithic build.
- **SAP ingestion has moved out of Airflow**: it became **SQL Server Agent jobs** (HANA → SQL Server
  linked server, in the same data center). Airflow **no longer talks to HANA**.
- **SharePoint extraction** (Graph → SQL Server) became the `extract_sharepoint` DAG
  (daily at 04:30 BRT) — the server already has HTTPS egress to Graph (confirmed 2026-06-02). All
  that's left is **Elementary publishing** (`edr report` → SharePoint), which depends on **write**
  permission on Graph.

Architecture decisions: **LocalExecutor**; **dbt via BashOperator** (no Cosmos — Elementary
covers per-model detail); **dbt and extractors in isolated venvs** in the image; **credentials in
Airflow Connections** (encrypted by Fernet); **facts orchestrated by Airflow Assets**
(data-aware), starting from a "common" DAG that acts as the pacemaker.

---

## Current state

| Workstream | Where it runs | Status |
|---|---|---|
| SAP ingestion (`raw_sap`) | **SQL Server Agent** jobs (linked server) — outside Airflow | ✅ **in production** (jobs active; `raw_sap` fresh as of today) |
| SharePoint extraction (`raw_sharepoint`) | `extract_sharepoint` DAG (Graph; daily at 04:30 BRT) | ✅ **automated** (egress confirmed 2026-06-02; previously a one-off load on 2026-05-14) |
| **dbt transformation** (`stg → int → mart`) | **6 domain DAGs in this repo** | ✅ **in production** |
| Elementary observability | The `elementary_report` DAG generates the HTML on the server; publishing it to SharePoint requires **write** permission on Graph (the extraction app is read-only) | 🟡 generation works; publishing still to do |

> The dbt layer reads `raw_sap` / `raw_sharepoint` and writes `stg_*`, `int_*`, `mart_*`, `elementary`.
> Today `raw_sap` (SQL Agent jobs) and `raw_sharepoint` (the `extract_sharepoint` DAG) are
> refreshed automatically; dbt reads from there on the cadence of the transformation DAGs.

---

## Image architecture

| Environment | Path | Contents |
|---|---|---|
| Airflow | image default env | apache/airflow 3.1.7 (Python 3.12) |
| dbt | `/opt/venvs/dbt` | dbt-core 1.11.9, dbt-sqlserver 1.9.0, elementary 0.23.4 |
| extractors | `/opt/venvs/extract` | hdbcli, pyodbc, pandas, etc. |

Repo code is volume-mounted at `/opt/acme/{dbt,extract-sap,extract-sharepoint}`.

> The `extract` venv runs the **SharePoint** extractor (Graph) — the `extract_sharepoint` DAG. The
> `hdbcli` (HANA client) is still in the image, but **SAP ingestion no longer goes through Airflow**
> (it migrated to SQL Server Agent jobs); the `extract-sap` mount is legacy.

---

## Server prerequisites

- Docker + compose plugin (already installed)
- ODBC Driver 18 ships **inside the image** (no need to install it on the host)
- The 3 code repos cloned (see below)

---

## Setup and deploy (first time)

### 1. Clone the code repos on the server

```bash
sudo mkdir -p /opt/acme && sudo chown $USER:$USER /opt/acme
cd /opt/acme
git clone https://github.com/your-org/acme-dw-dbt.git                dbt
git clone https://github.com/your-org/acme-sap-ingestion.git         extract-sap
git clone https://github.com/your-org/acme-sharepoint-connector.git  extract-sharepoint
```

> Private repos: set up a deploy key/token first. Confirm the URLs.
>
> **`acme-dw-dbt` and `acme-sharepoint-connector` are required** — the transformation runs on dbt, and the
> `extract_sharepoint` DAG (production, daily at 04:30) runs the extractor mounted at
> `/opt/acme/extract-sharepoint`. **`extract-sap` is legacy** — SAP ingestion became SQL Server
> Agent jobs; it's cloned only so the default mount resolves, no DAG runs it.

### 2. Clone this repo and configure the .env

```bash
cd /opt/acme
git clone https://github.com/your-org/acme-airflow.git airflow
cd airflow
cp .env.example .env
# Fill in ONLY the Airflow block + the ACME_*_PATH.
# Business credentials do NOT go in the .env — they are Airflow Connections (step 6).
id -u                                                                       # -> AIRFLOW_UID
python3 -c "import base64,os; print(base64.urlsafe_b64encode(os.urandom(32)).decode())"  # -> AIRFLOW_FERNET_KEY
python3 -c "import secrets; print(secrets.token_hex(32))"                   # -> AIRFLOW_JWT_SECRET
```

> ⚠️ **`AIRFLOW_UID` is critical.** Use the exact value from `id -u` (e.g., `1001`), not the default `50000`.
> With the wrong UID the container can't **write** to the mounted repos (which belong to your
> user) and **dbt fails silently** (exit 2, no log) when it tries to create `logs/`/`target/`. Airflow
> comes up regardless (it writes to `/opt/airflow`, which is group-0 writable), which masks the problem.

### 3. Build the image

```bash
docker compose build
```

### 4. Bring up the stack

```bash
docker compose up -d
docker compose ps          # all healthy?
```

UI: `http://SERVER_IP:8080` (user/password from `.env`).

### 5. Validate the foundation (no credentials)

```bash
# dbt: the packages already ship PINNED in acme-dw-dbt (vendored — the server is private, no
# internet). Do NOT run `dbt deps` here: it fails without internet and is unnecessary. Just confirm
# the container can see the packages through the volume:
docker compose run --rm airflow-scheduler \
  bash -lc "ls /opt/acme/dbt/dbt_packages"   # should list: dbt_utils  elementary

# extractors: do the imports load?
docker compose run --rm airflow-scheduler \
  /opt/venvs/extract/bin/python -c "import hdbcli, pyodbc, pandas, requests; print('extract venv OK')"
```

### 6. Credentials (Airflow Connections)

Business credentials live in **Airflow Connections** — in the metadata database,
encrypted by `AIRFLOW_FERNET_KEY`. Create them via the UI (**Admin → Connections**, avoids
shell history) or via the CLI. The dbt SQL Server:

> ⚠️ **The PROD host/port are the database's INTERNAL address** (as seen from inside the server/DC),
> which differs from what you use locally over VPN (that's usually a gateway + SQL client alias
> that only resolves on your machine). Find the real IP by querying the database itself —
> `SELECT CONNECTIONPROPERTY('local_net_address'), CONNECTIONPROPERTY('local_tcp_port');` — and
> validate the route from the server with `timeout 5 bash -c '</dev/tcp/<ip>/<port>'` before registering it.

```bash
docker compose run --rm airflow-scheduler \
  airflow connections add 'acme_sqlserver_prod' \
    --conn-type generic --conn-host '<internal_ip>' --conn-port <internal_port> \
    --conn-login '<user>' --conn-password '<password>' \
    --conn-schema '<database>' --conn-extra '{"dbt_schema":"SAP_MIRROR"}'
```

Graph (SharePoint) uses the `graph_sharepoint` Connection (see [SharePoint extraction](#sharepoint-extraction-extract_sharepoint)).
**Not HANA** — SAP ingestion became SQL Server Agent jobs, outside Airflow.

### 7. Validate the dbt connection

The SQL Server connection is validated by the **first dbt task** (e.g., `build_common` in
`dbt_common`), which reads the `acme_sqlserver_prod` Connection and injects the `DBT_PROD_*` env vars.
For a one-off test before that, you can run `dbt debug` injecting the vars inline
(transient, not persisted anywhere):

```bash
docker compose run --rm -e CONNECTION_CHECK_MAX_COUNT=0 \
  -e DBT_PROD_HOST='<internal_ip>' -e DBT_PROD_PORT=<internal_port> -e DBT_PROD_DATABASE='<db>' \
  -e DBT_PROD_SCHEMA='SAP_MIRROR' -e DBT_PROD_USER='<user>' -e DBT_PROD_PASSWORD='<password>' \
  airflow-scheduler \
  bash -lc "/opt/venvs/dbt/bin/dbt debug --project-dir /opt/acme/dbt --profiles-dir /opt/acme/dbt --target prod"
```

**All checks passed** confirms that the image + ODBC + SQL Server are good.

---

## DAGs

The DAGs live in `dags/` (mounted at `/opt/airflow/dags`).

### dbt transformation — DAGs by domain/cadence

Day-to-day work runs in **DAGs split by refresh group** (one dbt model = one owner, no duplicate
rebuilds), all calling dbt from the isolated venv (`/opt/venvs/dbt/bin/dbt`) via `BashOperator`, in
the **`dbt` pool** (1 slot — serializes the builds on the small server):

| DAG | Builds | Cadence | Triggered by |
|---|---|---|---|
| `dbt_common` | `int_common` base + dimensions (`tag:common tag:dimension`) | hourly, 7–22 BRT | cron; **emits the assets** |
| `dbt_sales` | `+fact_sales` (no common/dim/staging) | hourly, after common | `common_ready` asset |
| `dbt_inventory` | `+fact_inventory` | every 3h, 7–22 | `inventory_window` asset |
| `dbt_goals` | `+fact_goals` | Mon 10:00, Thu 07:00 | `goals_window` asset |
| `dbt_daily_movement` | `+fact_daily_inventory_movement` | daily 05:00 | cron |
| `dbt_purchases_finance` | `+fact_purchases +fact_accounts_receivable` | daily 06:00 | cron |
| `dbt_build` | the whole project (full build) | **manual** (contingency/backfill) | — |
| `elementary_report` | `edr report` → Elementary HTML in `edr_target/` | daily 22:30 BRT | cron |

`dbt_common` is the pacemaker: when it finishes, it emits `common_ready` (always → triggers sales)
and, only within the right windows, `inventory_window`/`goals_window` (tasks that self-skip outside
the schedule — a skipped task doesn't emit the asset, so the fact doesn't trigger). Each fact runs on
its own cadence, always **after** common, with no race and without rebuilding the base. Detailed
design in `PLANO-DAGS-POR-DOMINIO.md`; helpers in `dbt_lib.py` (in `.airflowignore`).

- **Credentials**: read at runtime from the `acme_sqlserver_prod` Connection (Fernet) via
  `{{ conn.acme_sqlserver_prod.* }}`, injected as `DBT_PROD_*`. The secret never lives in the code
  or in the serialized DAG; the secrets masker hides it in the logs.
- **Elementary**: the `on-run-end` hook runs on every build (schema `elementary`).
- **`dbt` pool**: created automatically by `airflow-init` (`airflow pools set dbt 1`). Without it the
  tasks get stuck in `scheduled` (see Troubleshooting).

**Prerequisite (one-time) — create the Connection** (the database's internal host/port):
```bash
docker compose run --rm airflow-scheduler \
  airflow connections add 'acme_sqlserver_prod' \
    --conn-type generic --conn-host '10.86.24.138' --conn-port 1433 \
    --conn-login '<user>' --conn-password '<password>' \
    --conn-schema '<database>' --conn-extra '{"dbt_schema":"SAP_MIRROR"}'
```
(or via the **Admin → Connections** UI, which avoids shell history.)

**Validate the pool and unpause:**
```bash
docker compose run --rm airflow-scheduler airflow pools list   # should list 'dbt' with 1 slot
```
Unpause the DAGs (UI or `airflow dags unpause <id>`). `dbt_common` then runs on its own every
hour (7–22) and triggers the facts via the assets. For an immediate bootstrap/test, trigger
`dbt_common` manually; for a full reprocess, trigger `dbt_build` (full build).

### SharePoint extraction (`extract_sharepoint`)

An **extraction**-category DAG (not transformation): it runs the `acme-sharepoint-connector` extractor
in the `extract` venv and materializes 3 spreadsheets (`wholesale_goals`, `retail_goals`,
`store_mapping`) into `raw_sharepoint`, via Microsoft Graph.

| Item | Value |
|---|---|
| Cadence | daily **04:30 BRT** (before the 07:00 `common` and the goals windows) |
| Runs | `python main.py` in `/opt/acme/extract-sharepoint` (`extract` venv) |
| Pool | none — it runs before any dbt build, so it doesn't contend for the `dbt` slot |
| Design | **decoupled** (like SAP): keeps `raw_sharepoint` fresh; dbt reads on its own cadence, with no asset/chaining |

**Credentials** (runtime, Fernet): besides `acme_sqlserver_prod` (reused), it needs the
`graph_sharepoint` Connection (Graph app registration, client-credentials flow):

| Field | Value |
|---|---|
| Connection Id | `graph_sharepoint` |
| Connection Type | Generic |
| Login | the app's `client_id` |
| Password | the app's `client_secret` |
| Extra | `{"tenant_id": "<tenant>"}` |

Create it via the **Admin → Connections** UI (keeps the secret out of shell history). The server
already has HTTPS egress to Graph (confirmed 2026-06-02, no proxy). Unpause the DAG and trigger it
once manually to validate; check freshness in `raw_sharepoint` (the `_ingestao_em` column).

---

## Operations

```bash
docker compose up -d                 # bring up / apply changes
docker compose down                  # stop (keeps volumes)
docker compose logs -f airflow-scheduler
docker compose build && docker compose up -d   # after changing Dockerfile/requirements
```

Server reboot: everything comes back on its own (`restart: unless-stopped` + Docker on boot).

---

## Updating code in production (redeploy)

The repo code is **volume-mounted** (`/opt/acme/{dbt,extract-sharepoint,airflow}`), not
copied into the image. That's why most changes reach production with a simple `git pull` in the
right directory — **no image rebuild**. A rebuild (`docker compose build`) is only needed when the
environment itself changes (`Dockerfile`/`requirements-*.txt`).

| What changed | Action on the server | Rebuild? |
|---|---|---|
| dbt model (`.sql`), `schema.yml`, macro, README/docs | `cd /opt/acme/dbt && git pull` — the next dbt task re-parses and reads the new version | no |
| dbt `packages.yml` / `package-lock.yml` | `cd /opt/acme/dbt && git pull` — the `dbt_packages/` ships **vendored in the commit**; do **not** run `dbt deps` on the server (it's private, no internet) | no |
| DAG or helper (`dags/*.py`) | `cd /opt/acme/airflow && git pull` — the dag-processor reloads on its own within seconds | no |
| SharePoint extractor | `cd /opt/acme/extract-sharepoint && git pull` | no |
| `Dockerfile` / `requirements-dbt.txt` / `requirements-extract.txt` | `cd /opt/acme/airflow && git pull && docker compose build && docker compose up -d` | **yes** |
| `docker-compose.yml` / `.env` | `cd /opt/acme/airflow && git pull && docker compose up -d` | no (recreates the stack) |

> **SAP ingestion is not here.** It doesn't go through Airflow — it's SQL Server Agent jobs (the
> `acme-sap-ingestion` repo). Changes there are applied on SQL Server (see that repo's runbook), not via
> `git pull` on the Airflow server. The `extract-sap` mount is legacy.

> **A deliberate trade-off.** A mounted volume trades reproducibility for deploy speed:
> a model deploy becomes a `git pull`, but the code version is **not stamped into the image**
> (rollback is by `git checkout`, not by swapping an image tag). Appropriate for the current stage (one
> server, small team, dbt evolving quickly). As the pipeline becomes more critical, the path forward
> is to copy dbt into the image with a per-commit tag (CI) — same logic as "easy access for the
> team" below: works today, with a planned "later".

---

## Web UI access

The Airflow UI runs on **port 8080 of the server**, which is private — **do not expose that port**.
Access is via an **SSH tunnel**, reusing the SSH port you already use (which is **not 22** —
confirm it in your client, e.g. WinSCP). On **your PC**:

```powershell
ssh -p <ssh-port> -L 8080:localhost:8080 <user>@<ssh-host>
```

Keep the session open and open `http://localhost:8080` in your browser.
Login = `AIRFLOW_USER` / `AIRFLOW_PASSWORD` from the `.env`.

> **Easy access for the team (future evolution).** Instead of everyone opening a tunnel by hand, the
> plan is an **identity-aware proxy (zero-trust)** with corporate login (SSO) and a DNS name, **without
> opening a port** on the server (the agent makes an outbound connection). It's the recommended path
> when more team members need access.

---

## Troubleshooting

**`dbt` fails without printing anything (exit 2, and no `logs/dbt.log` is created)**
Write permission: the container's UID differs from the owner of the mounted files and it can't
create `logs/`/`target/`. Make sure **`AIRFLOW_UID=$(id -u)`** is in the `.env` and recreate
(`docker compose up -d`). Test:
`docker compose run --rm airflow-scheduler bash -lc 'id; touch /opt/acme/dbt/_t && echo OK && rm /opt/acme/dbt/_t'` → should print `OK`.

**`dbt debug` → `Login timeout expired (SQLDriverConnect)`**
This is **network, not credentials** (a wrong password would say `Login failed`). The server couldn't
reach the database. Common cause: wrong host/port — from inside the server use the database's
**internal address**, not the host/port you use locally over VPN. Find the real IP by running on
the database `SELECT CONNECTIONPROPERTY('local_net_address'), CONNECTIONPROPERTY('local_tcp_port');`
and test the route from the server: `timeout 5 bash -c '</dev/tcp/<ip>/<port>'`.

**`dbt deps` hangs or fails on the server**
The server is private, **no internet** — don't run `dbt deps` there. The packages ship **vendored**
(versioned in acme-dw-dbt). Confirm with `ls /opt/acme/dbt/dbt_packages`. To update
versions, run `dbt deps` **locally** and commit the result.

**The UI at `localhost:8080` won't open ("connection refused")**
The SSH tunnel isn't active: confirm the `ssh -L ...` session is still open and that you used the
**correct SSH port** (not 22). See "Web UI access".

**Task fails right at the start with `Invalid auth token: Signature verification failed` (in the scheduler log)**
The task never even runs the command; the Audit Log shows "state mismatch / task-state-changed-externally"
(state `queued` → `failed`). In Airflow 3.x the task authenticates to the Execution API with a **signed JWT**,
and the secret (`AIRFLOW__API_AUTH__JWT_SECRET`) must be **identical across all components**. If
`AIRFLOW_JWT_SECRET` isn't in the `.env`, each service comes up with its own value and validation fails.
Set `AIRFLOW_JWT_SECRET` in the `.env` and **recreate** the stack (`docker compose up -d`).

**Permission denied creating `/opt/airflow/logs/...` (dag-processor/scheduler in a crash loop)**
The `./logs` volume was created by root (`airflow-init` runs as `0:0`) and the component, which runs as
`AIRFLOW_UID`, can't write to it. Set the right owner on the host: `sudo chown -R "$(id -u):0" logs` and
restart the component. Symptom in the dag-processor: `PermissionError: [Errno 13] ... '/opt/airflow/logs/dag_processor'`.
(`airflow-init` already does this `chown` automatically on every `up`; this is a manual fallback.)

**dbt tasks stuck in `scheduled` (the run stays "running" but the task never goes `queued`/`running`)**
The **`dbt` pool** is missing. Every dbt task uses `pool="dbt"`; if it doesn't exist in the metadata, the
scheduler won't promote the tasks (a named pool does **not** fall back to `default_pool`) — a silent
failure, no red error. `airflow-init` creates the pool automatically (`airflow pools set dbt 1`); confirm with
`docker compose run --rm airflow-scheduler airflow pools list`. If it's missing, run that `pools set`.
