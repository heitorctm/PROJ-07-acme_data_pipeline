import os

import requests

from ingestion.connections import GRAPH_BASE, get_graph_token
from ingestion.sharepoint import _encode_share_url

# The Graph API requires every chunk (except the last) to be a multiple of 320 KiB (327680 bytes).
# 10 MiB = 32 * 320 KiB. Files < 10 MiB go up in a single PUT; the loop is a safety
# net in case the HTML grows beyond that.
UPLOAD_CHUNK_SIZE = 32 * 320 * 1024  # 10,485,760 bytes


def _resolve_destination_folder(folder_share_url: str, token: str) -> tuple[str, str]:
    """Resolve a FOLDER sharing URL -> (drive_id, folder_id) via /shares/{id}/driveItem."""
    share_id = _encode_share_url(folder_share_url)
    resp = requests.get(
        f"{GRAPH_BASE}/shares/{share_id}/driveItem",
        headers={"Authorization": f"Bearer {token}"},
        timeout=30,
    )
    if resp.status_code != 200:
        raise RuntimeError(
            f"Failed to resolve destination folder (HTTP {resp.status_code}): {resp.text[:500]}"
        )
    item = resp.json()
    return item["parentReference"]["driveId"], item["id"]


def publish_file(folder_share_url: str, local_path: str, destination_name: str) -> dict:
    """Publish ``local_path`` to the SharePoint folder ``folder_share_url``, with name
    ``destination_name``, via Microsoft Graph (app-only, requires the Files.ReadWrite.All permission).

    Overwrites if it already exists (``conflictBehavior=replace``) → the link stays stable and
    SharePoint keeps the version history. Returns the final driveItem (with ``webUrl``)
    on success; raises an exception on any error.
    """
    if not os.path.isfile(local_path):
        raise FileNotFoundError(f"Local file not found: {local_path}")
    total_size = os.path.getsize(local_path)
    if total_size == 0:
        raise RuntimeError(f"Local file is empty (0 bytes): {local_path}")

    token = get_graph_token()
    drive_id, folder_id = _resolve_destination_folder(folder_share_url, token)

    # 1) Create the upload session (path relative to the folder item: {folderId}:/{name}:).
    session = requests.post(
        f"{GRAPH_BASE}/drives/{drive_id}/items/{folder_id}:/{destination_name}:/createUploadSession",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        json={"item": {"@microsoft.graph.conflictBehavior": "replace"}},
        timeout=30,
    )
    if session.status_code not in (200, 201):
        raise RuntimeError(
            f"Failed to create upload session (HTTP {session.status_code}): {session.text[:500]}"
        )
    upload_url = session.json()["uploadUrl"]

    # 2) Upload in chunks. The uploadUrl is already pre-authenticated → do NOT send Authorization.
    result = None
    with open(local_path, "rb") as f:
        start = 0
        while start < total_size:
            chunk = f.read(UPLOAD_CHUNK_SIZE)
            end = start + len(chunk) - 1  # last byte of this chunk (inclusive, 0-based)
            put = requests.put(
                upload_url,
                headers={
                    "Content-Length": str(len(chunk)),
                    "Content-Range": f"bytes {start}-{end}/{total_size}",
                },
                data=chunk,
                timeout=300,
            )
            if put.status_code in (200, 201):
                result = put.json()  # last chunk accepted → final driveItem
            elif put.status_code == 202:
                pass  # intermediate chunk accepted; move on to the next one
            else:
                raise RuntimeError(
                    f"PUT failed for chunk {start}-{end}/{total_size} "
                    f"(HTTP {put.status_code}): {put.text[:500]}"
                )
            start = end + 1

    if result is None:
        raise RuntimeError(
            f"Upload finished without 200/201 — Graph did not confirm completion ({total_size} bytes)."
        )
    return result
