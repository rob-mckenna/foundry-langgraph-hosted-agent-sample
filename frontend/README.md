# Claims Processing Assistant Frontend

This frontend is a self-contained static chat UI for the standalone claims API.

## How to use

1. Start the standalone backend on `http://localhost:8080`.
2. Open `frontend/index.html` directly in your browser, or serve the folder:

```bash
cd frontend
python3 -m http.server 8000
```

3. If you started a local server, open `http://localhost:8000`.

The page sends `POST` requests to `http://localhost:8080/chat` with:

```json
{"message":"...","thread_id":"..."}
```
