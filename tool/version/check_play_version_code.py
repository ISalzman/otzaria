#!/usr/bin/env python3
"""Fails the release if the pubspec versionCode is already taken on Google Play.

A version code can never be reused on Play, so an accidental upload permanently
burns that number - this stops the build before the AAB is signed and shipped.

Env: VERSION_CODE (from pubspec.yaml), PLAY_SERVICE_ACCOUNT_JSON (secret).
"""

import json
import os
import sys

import requests
from google.oauth2 import service_account
from google.auth.transport.requests import Request

PACKAGE_NAME = os.environ.get("PLAY_PACKAGE_NAME", "org.otzaria.otzaria")
API = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications"
SCOPE = "https://www.googleapis.com/auth/androidpublisher"


def fail(message):
    print(f"::error::{message}")
    sys.exit(1)


def main():
    raw_code = os.environ.get("VERSION_CODE", "").strip()
    if not raw_code.isdigit():
        fail(f"VERSION_CODE must be a number, got '{raw_code}'")
    version_code = int(raw_code)

    raw_credentials = os.environ.get("PLAY_SERVICE_ACCOUNT_JSON", "").strip()
    if not raw_credentials:
        fail("PLAY_SERVICE_ACCOUNT_JSON secret is missing")

    credentials = service_account.Credentials.from_service_account_info(
        json.loads(raw_credentials), scopes=[SCOPE]
    )
    credentials.refresh(Request())
    session = requests.Session()
    session.headers["Authorization"] = f"Bearer {credentials.token}"

    # Listing bundles requires an open edit; it is deleted again below so the
    # check never leaves a dangling draft edit on the Play Console.
    edit = session.post(f"{API}/{PACKAGE_NAME}/edits", timeout=60)
    edit.raise_for_status()
    edit_id = edit.json()["id"]
    try:
        taken = []
        for kind in ("bundles", "apks"):
            response = session.get(
                f"{API}/{PACKAGE_NAME}/edits/{edit_id}/{kind}", timeout=60
            )
            response.raise_for_status()
            taken += [a["versionCode"] for a in response.json().get(kind, [])]
    finally:
        session.delete(f"{API}/{PACKAGE_NAME}/edits/{edit_id}", timeout=60)

    highest = max(taken) if taken else 0
    print(f"pubspec versionCode: {version_code}")
    print(f"highest on Google Play: {highest}")

    if version_code in taken:
        fail(
            f"versionCode {version_code} was already uploaded to Google Play and "
            f"can never be reused. Bump the version (or the hotfix field in "
            f"tool/version/version.json) to get above {highest}."
        )
    if version_code <= highest:
        fail(
            f"versionCode {version_code} is not higher than {highest}, which is "
            f"already on Google Play. Bump the version before releasing."
        )

    print("versionCode is free - proceeding with the release.")


if __name__ == "__main__":
    main()
