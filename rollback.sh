#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR=/opt/ai-qa
SERVICE=ai-qa
PORT=8000
BACKUP_DIR=/opt/ai-qa-releases
LOG=/var/log/ai-qa-rollback.log

log() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }
fail() { log "ERROR: $*"; exit 1; }

# 用法说明
usage() {
  echo "用法:"
  echo "  sudo bash $0              # 回滚到最近一次部署前的版本"
  echo "  sudo bash $0 list         # 列出所有可用快照"
  echo "  sudo bash $0 <快照目录>    # 回滚到指定快照"
  exit 0
}

# 列出快照
if [ "${1:-}" = "list" ]; then
  echo "可用快照（越靠上越新）:"
  ls -1dt "$BACKUP_DIR"/*/ 2>/dev/null | while read -r d; do
    c=$(cat "$d/COMMIT" 2>/dev/null || echo "?")
    echo "  $d  (commit $c)"
  done
  exit 0
fi

[ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] && usage

# 确定目标快照
if [ -n "${1:-}" ]; then
  TARGET="$1"
  [ -d "$TARGET" ] || fail "快照不存在: $TARGET"
else
  TARGET=$(ls -1dt "$BACKUP_DIR"/*/ 2>/dev/null | head -n 1)
  [ -n "$TARGET" ] || fail "没有可用快照"
fi

log "开始回滚 -> $TARGET"
TARGET_COMMIT=$(cat "$TARGET/COMMIT" 2>/dev/null || echo "?")

log "1/4 停止服务"
systemctl stop "$SERVICE" || true

log "2/4 回退代码"
# 保留 venv（依赖环境不动），用快照覆盖代码
rsync -a --delete --exclude 'venv' --exclude '.git' "$TARGET/" "$APP_DIR/" 2>/dev/null \
  || cp -a "$TARGET/." "$APP_DIR/" 2>/dev/null \
  || fail "回退失败"

log "3/4 修正属主"
chown -R aiqa:aiqa "$APP_DIR"

log "4/4 启动服务 + 健康检查"
systemctl start "$SERVICE"
for i in $(seq 1 15); do
  if ss -lntp | grep -q "127.0.0.1:$PORT"; then
    if curl -fsS "http://127.0.0.1:$PORT/health" >/dev/null; then
      log "回滚成功 -> commit $TARGET_COMMIT，/health 返回 200"
      exit 0
    fi
  fi
  sleep 1
done

log "回滚后健康检查失败，输出诊断信息"
systemctl status "$SERVICE" --no-pager -l || true
journalctl -u "$SERVICE" -n 50 --no-pager || true
exit 1
