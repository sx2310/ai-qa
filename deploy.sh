#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR=/opt/ai-qa
SERVICE=ai-qa
PORT=8000
BRANCH=main
LOG=/var/log/ai-qa-deploy.log
BACKUP_DIR=/opt/ai-qa-releases
KEEP=5

log() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }
fail() { log "ERROR: $*"; exit 1; }

cd "$APP_DIR" || fail "目录不存在: $APP_DIR"

log "0/7 备份当前版本"
mkdir -p "$BACKUP_DIR"
CUR_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
SNAPSHOT="$BACKUP_DIR/$(date '+%Y%m%d%H%M%S')_${CUR_COMMIT}"
# 只备份代码目录，排除 venv 和 .git，避免备份过大
rsync -a --delete --exclude 'venv' --exclude '.git' --exclude '__pycache__' "$APP_DIR/" "$SNAPSHOT/" 2>/dev/null \
  || cp -a "$APP_DIR" "$SNAPSHOT" 2>/dev/null \
  || fail "备份失败"
# 记录当前 commit，供 rollback 使用
echo "$CUR_COMMIT" > "$SNAPSHOT/COMMIT"
log "快照已保存: $SNAPSHOT (commit $CUR_COMMIT)"
# 清理旧快照，只保留最近 KEEP 份
ls -1dt "$BACKUP_DIR"/*/ 2>/dev/null | tail -n +$((KEEP+1)) | xargs -r rm -rf

log "1/7 拉取代码"
git fetch origin "$BRANCH"
git reset --hard "origin/$BRANCH"

log "2/7 安装依赖"
[ -x "$APP_DIR/venv/bin/python" ] || python3 -m venv "$APP_DIR/venv"
"$APP_DIR/venv/bin/pip" install -q --upgrade pip
"$APP_DIR/venv/bin/pip" install -q -r requirements.txt

log "3/7 修正属主"
chown -R aiqa:aiqa "$APP_DIR"

log "4/7 停止旧服务"
systemctl stop "$SERVICE" || true

log "5/7 启动服务"
systemctl start "$SERVICE"

log "6/7 端口检测 + 健康检查"
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
