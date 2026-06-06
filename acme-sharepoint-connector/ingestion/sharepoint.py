import base64
import io

import requests

from ingestion.connections import GRAPH_BASE, get_graph_token


def _encode_share_url(url: str) -> str:
    clean_url = url.split("?")[0]
    b64 = base64.urlsafe_b64encode(clean_url.encode("utf-8")).decode("ascii").rstrip("=")
    return f"u!{b64}"


def download_file(share_url: str) -> io.BytesIO:
    share_id = _encode_share_url(share_url)
    token = get_graph_token()

    resp = requests.get(
        f"{GRAPH_BASE}/shares/{share_id}/driveItem/content",
        headers={"Authorization": f"Bearer {token}"},
        timeout=300,
    )
    if resp.status_code != 200:
        raise RuntimeError(
            f"Failed to download file from SharePoint (HTTP {resp.status_code}): {resp.text[:500]}"
        )

    return io.BytesIO(resp.content)
