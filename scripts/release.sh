#!/usr/bin/env bash
#
# Release script for l2d-widget
#
# 本地只负责: 版本号更新 + git commit + 打 tag + 推送
# 发布动作(npm publish + GitHub Release)由 CI 完成:
#   .github/workflows/release.yml 监听到 v* tag 后, 通过 OIDC trusted
#   publishing 自动发布到 npm 并创建 GitHub Release。
#
# 用法:
#   pnpm release            # 交互式选择版本类型 (patch/minor/major)
#   pnpm release patch      # 直接指定版本类型
#   pnpm release 1.2.3      # 直接指定完整版本号
#
set -euo pipefail

cd "$(dirname "$0")/.."

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { printf "${GREEN}%s${NC}\n" "$*"; }
warn()  { printf "${YELLOW}%s${NC}\n" "$*"; }
error() { printf "${RED}%s${NC}\n" "$*" >&2; }

# --- 前置检查 ----------------------------------------------------------

if [[ -n "$(git status --porcelain)" ]]; then
  error "工作区有未提交的改动，请先提交或 stash 后再发布。"
  exit 1
fi

if [[ "$(git branch --show-current)" != "main" ]]; then
  error "发布必须在 main 分支上进行（当前: $(git branch --show-current)）。"
  exit 1
fi

# --- 确定目标版本 ------------------------------------------------------

TYPE="${1:-}"
VERSION_NOW="$(node -p "require('./package.json').version")"

if [[ -z "$TYPE" ]]; then
  printf "当前版本: v%s\n\n" "$VERSION_NOW"
  printf "选择版本类型:\n"
  printf "  1) patch (修复, v%s -> v%s)\n" "$VERSION_NOW" "$(echo "$VERSION_NOW" | awk -F. '{print $1"."$2"."$3+1}')"
  printf "  2) minor (新功能, v%s -> v%s)\n" "$VERSION_NOW" "$(echo "$VERSION_NOW" | awk -F. '{print $1"."$2+1".0"}')"
  printf "  3) major (破坏性, v%s -> v%s)\n" "$VERSION_NOW" "$(echo "$VERSION_NOW" | awk -F. '{print $1+1".0.0"}')"
  printf "  4) 取消\n\n"
  read -rp "请选择 [1-4]: " CHOICE
  case "$CHOICE" in
    1) TYPE=patch ;;
    2) TYPE=minor ;;
    3) TYPE=major ;;
    *) error "已取消。"; exit 1 ;;
  esac
fi

# --- 发布前本地验证 ----------------------------------------------------

info "==> 运行 lint / typecheck / build 验证..."
pnpm lint
pnpm typecheck
pnpm build

# --- 更新版本 + commit + tag -------------------------------------------

info "==> 更新版本号并打 tag ($TYPE)..."
# npm version 自动完成: 改 package.json -> git commit -> 打 annotated tag
# commit message 与历史发布记录保持一致: "chore: release: vX.Y.Z"
npm version "$TYPE" -m "chore: release: v%s"

VERSION_NEW="$(node -p "require('./package.json').version")"
TAG="v${VERSION_NEW}"

info "==> 推送代码和 tag ($TAG)..."
git push origin main
git push origin "$TAG"

info ""
info "======================================================"
info " 发布流程已触发: v${VERSION_NEW}"
info "  GitHub Actions 将自动:"
info "    - lint / typecheck / build / 产物校验"
info "    - npm publish (OIDC trusted publishing, 自动 provenance)"
info "    - 创建 GitHub Release (changelogithub)"
info "  可在 Actions 页面查看进度:"
info "  https://github.com/$(git config --get remote.origin.url | sed -E 's#.*github\.com[:/]##; s#\.git$##')/actions"
info "======================================================"
