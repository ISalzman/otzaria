import re
import uuid

import requests
from bs4 import BeautifulSoup


class NodeBBClient:
    """לקוח גנרי לפורומי NodeBB (כניסה, פרסום הודעה, יציאה)."""

    def __init__(self, base_url: str, username: str, password: str):
        self.base_url = base_url.rstrip("/")
        self.session = requests.Session()
        self.username = username
        self.password = password
        self.csrf_token: str | None = None
        self.headers = {
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:132.0) "
                "Gecko/20100101 Firefox/132.0"
            ),
            "Accept-Language": "he,he-IL;q=0.8,en-US;q=0.5,en;q=0.3",
        }

    @staticmethod
    def _extract_csrf_token(html: str) -> str | None:
        soup = BeautifulSoup(html, "html.parser")
        for script in soup.find_all("script"):
            text = str(script)
            if "csrf" not in text:
                continue
            match = re.search(r'"csrf_token":"([^"]+)"', text)
            if match:
                return match.group(1)
        return None

    def _fetch_csrf_token(self) -> None:
        page = self.session.get(f"{self.base_url}/login", headers=self.headers)
        self.csrf_token = self._extract_csrf_token(page.text)

    def login(self) -> None:
        self._fetch_csrf_token()
        if not self.csrf_token:
            raise ValueError("Failed to fetch CSRF token")

        data = {
            "username": self.username,
            "password": self.password,
            "_csrf": self.csrf_token,
            "noscript": "false",
            "remember": "on",
        }
        headers = self.headers.copy()
        headers.update({
            "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
            "x-csrf-token": self.csrf_token,
        })

        response = self.session.post(
            f"{self.base_url}/login", headers=headers, data=data
        )
        if response.status_code != 200:
            raise ValueError(f"Login failed with status code {response.status_code}")

    def send_post(self, content: str, topic_id: int, to_pid: int | None = None) -> dict:
        url = f"{self.base_url}/api/v3/topics/{topic_id}"
        headers = self.headers.copy()
        headers.update({
            "Content-Type": "application/json; charset=utf-8",
            "x-csrf-token": self.csrf_token,
        })
        data = {
            "uuid": str(uuid.uuid4()),
            "tid": topic_id,
            "handle": "",
            "content": content,
            "toPid": to_pid,
        }
        response = self.session.post(url, json=data, headers=headers)
        return response.json()

    def logout(self) -> None:
        headers = self.headers.copy()
        headers["x-csrf-token"] = self.csrf_token or ""
        self.session.post(f"{self.base_url}/logout", headers=headers)
