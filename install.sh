#!/bin/zsh
# 新 Mac 一键安装：选编号 -> 自动装（都是最新版）
# 可以重复运行：已装的会更新，某个失败不影响其它。
# 注意：中国大陆网络要先把梯子开好，否则 Homebrew 和 GitHub 上的包下不动。

# ---------- 软件清单（想增删，改这里就行）----------
# 格式：名称 | 类型 | 目标
#   brew = 用 Homebrew 装（目标是包名）   open = 用浏览器打开下载页（Homebrew 里没有）
ITEMS=(
  "Google 反重力 Antigravity|brew|antigravity"
  "Codex 客户端（ChatGPT 桌面版）|brew|chatgpt"
  "Claude 桌面版（含 Code）|brew|claude"
  "Claude Code 命令行|brew|claude-code"
  "谷歌浏览器 Chrome|brew|google-chrome"
  "Grok Bot|brew|grok-bot"
  "Obsidian|brew|obsidian"
  "DeepSeek Harness|brew|deepseek-harness"
  "豆包电脑版|brew|doubao"
  "WorkBuddy（腾讯，国内版）|brew|workbuddy-cn"
  "WorkBuddy（国际版）|brew|workbuddy-ai"
  "Muse（Meta，手动下载页）|open|https://ai.meta.com/muse/download"
  "闪电说（手动下载页）|open|https://shandianshuo.cn/"
)

# ---------- 1. 菜单 ----------
N=${#ITEMS[@]}
print "\n=== 请选择要安装的软件 ==="
for i in {1..$N}; do
  print "  ${i}) ${ITEMS[$i]%%|*}"
done
print "\n【怎么选】输入一个编号，敲一个空格，再输入下一个编号，最后按回车。"
print "   例：只装 1 号      →  输入  1  回车"
print "   例：装 1、3、5 号  →  输入  1 3 5  回车"
print "   想【全部安装】：输入  全部  （或 QB / A，大小写都行）回车"
print "   想退出：输入  q  回车"
if [[ -n "$PICK" ]]; then ans="$PICK"; else read -r "ans?你的选择: " < /dev/tty; fi

chosen=()
setopt extended_glob
ans=${${ans##[[:space:]]##}%%[[:space:]]##}   # 去掉首尾空格
case "${ans:l}" in
  q) print "已退出"; exit 0 ;;
  "") print "没有输入任何内容，已退出。想全部安装请输入：全部"; exit 0 ;;
  a|all|qb|qw|全部|全选) chosen=({1..$N}) ;;
  *)
    for t in ${(s: :)${ans//,/ }}; do
      if [[ "$t" == <-> ]] && (( t >= 1 && t <= N )); then chosen+=($t)
      else print "⚠️ 忽略无效编号: $t"; fi
    done
    chosen=(${(u)chosen})   # 去重
    ;;
esac
[[ ${#chosen[@]} -eq 0 ]] && { print "没有选中任何软件，退出"; exit 0; }

brew_items=(); open_items=()
for i in $chosen; do
  name=${ITEMS[$i]%%|*}; rest=${ITEMS[$i]#*|}; kind=${rest%%|*}; target=${rest#*|}
  [[ $kind == brew ]] && brew_items+=("$name|$target") || open_items+=("$name|$target")
done
print "\n即将处理 ${#chosen[@]} 项："
for i in $chosen; do print "  - ${ITEMS[$i]%%|*}"; done

# ---------- 2. Homebrew（只在需要时装）----------
if [[ ${#brew_items[@]} -gt 0 && -z "$DRY_RUN" ]]; then
  if ! command -v brew >/dev/null 2>&1 && [[ ! -x /opt/homebrew/bin/brew ]]; then
    print "\n=== 安装 Homebrew（会要你输入开机密码，并可能弹出安装命令行工具的窗口）==="
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" < /dev/tty
  fi
  [[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
  command -v brew >/dev/null 2>&1 || { print "❌ Homebrew 没装上，请检查网络（梯子）后重跑"; exit 1; }
  grep -q 'brew shellenv' ~/.zprofile 2>/dev/null || print 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
  brew update
fi

# ---------- 3. 逐个安装 ----------
ok=(); fail=(); manual=()
for entry in $brew_items; do
  name=${entry%%|*}; cask=${entry#*|}
  print "\n=== $name ($cask) ==="
  if [[ -n "$DRY_RUN" ]]; then print "[试运行] brew install --cask $cask"; ok+=("$name"); continue; fi
  if brew list --cask "$cask" >/dev/null 2>&1; then
    brew upgrade --cask "$cask" && ok+=("$name(已有,已更新)") || fail+=("$name")
  else
    brew install --cask "$cask" && ok+=("$name") || fail+=("$name")
  fi
done
for entry in $open_items; do
  name=${entry%%|*}; url=${entry#*|}
  print "\n=== $name ==="
  if [[ -n "$DRY_RUN" ]]; then print "[试运行] open $url"; else open "$url"; fi
  manual+=("$name -> $url")
done

# ---------- 4. 结果 ----------
print "\n================ 结果 ================"
[[ ${#ok[@]} -gt 0 ]] && print "✅ 已装好: ${(j:、:)ok}"
[[ ${#fail[@]} -gt 0 ]] && print "❌ 失败: ${(j:、:)fail}   （把上面的报错发给 Claude 看原因）"
if [[ ${#manual[@]} -gt 0 ]]; then
  print "👉 需要手动下载（已为你打开网页）:"
  for m in $manual; do print "   $m"; done
fi
