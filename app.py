import os
from datetime import datetime
from flask import Flask, request, jsonify

app = Flask(__name__)

KB = {
    "zenme_bushu": "链路是 Git push -> Jenkins -> deploy.sh -> systemd -> Nginx 反向代理。",
    "jiankang": "服务正常，/health 返回 200。",
    "nishishui": "我是部署在阿里云 Ubuntu 上的问答服务示例。",
}

def answer(q):
    if "部署" in q:
        return "链路是 Git push -> Jenkins -> deploy.sh -> systemd -> Nginx 反向代理。"
    if "健康" in q or "检查" in q:
        return "服务正常，/health 返回 200。"
    if "谁" in q:
        return "我是部署在阿里云 Ubuntu 上的问答服务示例。"
    return "已收到问题：" + q + "（当前为本地规则库回复）"

@app.get("/health")
def health():
    return jsonify(status="ok", version="v2.0", time=datetime.now().isoformat())

@app.post("/api/ask")
def api_ask():
    data = request.get_json(silent=True) or {}
    q = (data.get("question") or "").strip()
    if not q:
        return jsonify(error="question is required"), 400
    return jsonify(question=q, answer=answer(q))

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=8000, debug=False)
