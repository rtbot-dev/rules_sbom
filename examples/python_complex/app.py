import httpx


def fetch_status(url: str) -> int:
    response = httpx.get(url, timeout=5.0)
    return response.status_code


if __name__ == "__main__":
    print(fetch_status("https://example.com"))
