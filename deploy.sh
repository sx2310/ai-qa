#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR=/opt/ai-qa
SERVICE=ai-qa
PORT=8000
BRANCH=main
LOG=/var/log/ai-qa-deploy.log

log() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }
fail() { log "ERROR: $*"; exit 1; }

cd "$APP_DIR" || fail "目录不存在: $APP_DIR"

log "1/6 拉取代码"
git fetch origin "$BRANCH"
git reset --hard "origin/$BRANCH"

log "2/6 安装依赖"
[ -x "$APP_DIR/venv/bin/python" ] || python3 -m venv "$APP_DIR/venv"
"$APP_DIR/venv/bin/pip" install -q --upgrade pip
"$APP_DIR/venv/bin/pip" install -q -r requirements.txt

log "3/6 修正属主"
chown -R aiqa:aiqa "$APP_DIR"

log "4/6 停止旧服务"
systemctl stop "$SERVICE" || true

log "5/6 启动服务"
systemctl start "$SERVICE"

log "6/6 端口检测 + 健康检查"
for i in $(seq 1 15); do
  if ss -lntp | grep -q "127.0.0.1:$PORT"; then
    if curl -fsS "http://127.0.0.1:$PORT/health" >/dev/null; then
      log "部署成功：端口 $PORT 已监听，/health 返回 200"
      exit 0
    fi
  fi
  sleep 1
done

log "部署失败，输出诊断信息"
systemctl status "$SERVICE" --no-pager -l || true
journalctl -u "$SERVICE" -n 50 --no-pager || true
exit 1
