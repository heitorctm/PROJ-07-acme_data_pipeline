# acme-airflow — Airflow image with ODBC 18 + dbt + extractors
#
# Strategy: Airflow lives in the image's default env; dbt and the extractors
# go into ISOLATED venvs (/opt/venvs/*) so they don't conflict with Airflow's
# dependencies. The DAGs invoke the binary from the correct venv (BashOperator).
#
# Built on Python 3.12 because the project's dbt requires >=3.12.
FROM apache/airflow:3.1.7-python3.12

# ---------------------------------------------------------------------------
# 1) System dependencies (root): Microsoft ODBC Driver 18 + unixODBC
#    The Airflow base image already ships with Microsoft's apt repository
#    configured, so we install the driver directly. Re-adding the repo (via
#    packages-microsoft-prod.deb) causes a "Signed-By" conflict on the same source.
# ---------------------------------------------------------------------------
USER root
RUN apt-get update \
    && ACCEPT_EULA=Y apt-get install -y --no-install-recommends msodbcsql18 unixodbc-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 2) Isolated venvs for dbt and the extractors
#    Created as root under /opt/venvs; the airflow user only needs read/execute.
# ---------------------------------------------------------------------------
COPY requirements-dbt.txt requirements-extract.txt /tmp/

# edr (Elementary) runs a `dbt deps` for its INTERNAL dbt project at runtime,
# creating `dbt_packages` inside the venv. Since the container runs non-root (group 0),
# the chmod below grants group write on that folder — otherwise `edr report` breaks
# with a PermissionError on 'dbt_packages' (elementary_report DAG).
RUN python -m venv /opt/venvs/dbt \
    && /opt/venvs/dbt/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/venvs/dbt/bin/pip install --no-cache-dir -r /tmp/requirements-dbt.txt \
    && chmod -R g+rwX /opt/venvs/dbt/lib/python*/site-packages/elementary/monitor

RUN python -m venv /opt/venvs/extract \
    && /opt/venvs/extract/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/venvs/extract/bin/pip install --no-cache-dir -r /tmp/requirements-extract.txt

# Switch back to the airflow user (never run Airflow as root)
USER airflow
