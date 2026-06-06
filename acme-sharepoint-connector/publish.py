import argparse
import sys
import traceback

from ingestion.connections import test_graph_connection
from ingestion.upload import publish_file


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Publishes a local file to a SharePoint folder via Microsoft Graph."
    )
    parser.add_argument("--file", required=True, help="Local path of the file to publish.")
    parser.add_argument(
        "--dest-url", required=True, help="Sharing URL of the destination FOLDER on SharePoint."
    )
    parser.add_argument(
        "--name", required=True, help="File name at the destination (e.g., elementary_report.html)."
    )
    args = parser.parse_args()

    try:
        print("Testing Microsoft Graph authentication...")
        test_graph_connection()
        print("Microsoft Graph authenticated successfully.")

        print(f"Publishing {args.file} -> {args.name} ...")
        item = publish_file(args.dest_url, args.file, args.name)
        print(f"Published successfully. webUrl: {item.get('webUrl', '(no webUrl)')}")

    except Exception as e:
        print("\nERROR PUBLISHING TO SHAREPOINT")
        print(str(e))
        print("\nTechnical details:")
        print(traceback.format_exc())
        sys.exit(1)


if __name__ == "__main__":
    main()
