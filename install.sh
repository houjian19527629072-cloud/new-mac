#!/bin/zsh
# 新 Mac 批量安装。软件清单的格式是 名称|类型|目标。
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

N=${#ITEMS[@]}
print '\n=== 请选择要安装的软件 ==='
for i in {1..$N}; do
  print -r -- "  ${i}) ${ITEMS[$i]%%|*}"
done
print '\n输入编号，例如 4 8 10，空格、逗号和顿号均可。'
print '全选请输入「全部」或 a。直接回车或输入 q 退出。'
if [[ -n $PICK ]]; then
  ans=$PICK
elif { true </dev/tty; } 2>/dev/null; then
  read -r 'ans?你的选择: ' </dev/tty || exit 2
else
  print -u2 '需要在终端选择编号。非交互运行请设置 PICK，例如 PICK="4 8 10"。'
  exit 2
fi

setopt extended_glob
ans=${${ans##[[:space:]]##}%%[[:space:]]##}
chosen=()
case ${ans:l} in
  q|"") print '已退出，未选择任何软件。'; exit 0 ;;
  a|all|qb|qw|全部|全选) chosen=({1..$N}) ;;
  *)
    ans=${ans//[,，、[:space:]]/ }
    for t in ${(s: :)ans}; do
      number=${t##0#}
      if [[ $number == <-> && ${#number} -le ${#N} ]] && (( number >= 1 && number <= N )); then
        chosen+=("$number")
      else
        print -u2 -r -- "⚠️ 忽略无效编号: $t"
      fi
    done
    chosen=(${(u)chosen})
    ;;
esac
if (( ! ${#chosen[@]} )); then
  print -u2 '没有选中任何软件。'
  exit 2
fi

brew_items=() open_items=()
print "\n即将处理 ${#chosen[@]} 项："
for i in $chosen; do
  entry=${ITEMS[$i]}
  name=${entry%%|*} rest=${entry#*|}
  print -r -- "  - $name"
  if [[ ${rest%%|*} == brew ]]; then
    brew_items+=("$name|${rest#*|}")
  else
    open_items+=("$name|${rest#*|}")
  fi
done

if [[ -n $DRY_RUN ]]; then
  for entry in $brew_items; do print -r -- "[试运行] brew install --cask ${entry#*|}"; done
  for entry in $open_items; do print -r -- "[试运行] open ${entry#*|}"; done
  exit 0
fi
if [[ $(uname -s) != Darwin ]]; then
  print -u2 '此安装脚本仅支持 macOS。'
  exit 1
fi

find_brew() {
  whence -p brew || {
    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
      if [[ -x $candidate ]]; then
        print -r -- "$candidate"
        return 0
      fi
    done
    return 1
  }
}

run_brew() {
  HOMEBREW_CURLRC=${HOMEBREW_CURLRC:-$run_dir/curlrc} "$brew_bin" "$@"
}

# 从 Homebrew 读取当前版本的下载地址和校验值。只缓存完整且通过校验的安装包。
cache_workbuddy() {
  local cask=$1 metadata url checksum destination headers part archive result total first last size bytes actual
  metadata=$(run_brew info --cask --json=v2 "$cask") || return 1
  url=$(plutil -extract casks.0.url raw -o - - <<< "$metadata") || return 1
  checksum=$(plutil -extract casks.0.sha256 raw -o - - <<< "$metadata") || return 1
  [[ $url == https://* && $checksum == [[:xdigit:]]## && ${#checksum} -eq 64 ]] || return 1
  destination=$(run_brew --cache --cask "$cask") || return 1
  [[ $destination == /* ]] || return 1

  headers=$run_dir/headers part=$run_dir/part archive=$run_dir/"$cask.dmg"
  local -a download_options=(-fsSL --connect-timeout 15 --max-time 45 --retry 2 --retry-max-time 100)
  result=$(curl "${download_options[@]}" --range 0-0 --max-filesize 1 -D "$headers" -o "$part" -w '%{http_code}' "$url") || return 1
  [[ $result == 206 ]] || return 1
  total=$(awk 'tolower($1) == "content-range:" && $2 == "bytes" && $3 ~ /^0-0\// { split($3, parts, "/"); sub(/[^0-9]+$/, "", parts[2]); print parts[2] }' "$headers") || return 1
  [[ $total == <-> && ${#total} -le 10 ]] && (( total > 0 )) || return 1
  : > "$archive" || return 1
  for (( first=0; first<total; first=last+1 )); do
    (( last = first + 16777216 - 1 ))
    (( last < total )) || (( last = total - 1 ))
    (( size = last - first + 1 ))
    result=$(curl "${download_options[@]}" --range "$first-$last" --max-filesize "$size" -o "$part" -w '%{http_code}' "$url") || return 1
    bytes=$(stat -f %z "$part") || return 1
    [[ $result == 206 && $bytes == $size ]] || return 1
    cat "$part" >> "$archive" || return 1
    print -r -- "  下载进度 $(( 100 * (last + 1) / total ))%"
  done
  actual=$(shasum -a 256 "$archive") || return 1
  if [[ ${actual%% *} != ${checksum:l} ]]; then
    print -u2 'WorkBuddy 安装包校验失败。'
    return 1
  fi
  mkdir -p "${destination:h}" || return 1
  cache_staging=$(mktemp "${destination:h}/.new-mac.XXXXXXXX") || return 1
  if ! cp "$archive" "$cache_staging" || ! mv -f "$cache_staging" "$destination"; then
    rm -f -- "$cache_staging"
    return 1
  fi
  cache_staging=''
}

run_failed=0
cache_staging=''
if (( ${#brew_items[@]} )); then
  brew_on_path=$(whence -p brew)
  if ! brew_bin=$(find_brew); then
    print '\n=== 安装 Homebrew，按提示输入管理员密码并确认 ==='
    if ! { true </dev/tty; } 2>/dev/null; then
      print -u2 '首次安装 Homebrew 需要在终端确认。'
      exit 1
    fi
    bootstrap=$(curl -fsSL --connect-timeout 15 --max-time 60 https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh) || exit 1
    [[ -n $bootstrap ]] && /bin/bash -c "$bootstrap" </dev/tty || exit 1
    brew_bin=$(find_brew) || { print -u2 'Homebrew 没有安装成功。'; exit 1; }
  fi
  if [[ -z $brew_on_path ]] && ! grep -Fq "$brew_bin shellenv" ~/.zprofile 2>/dev/null; then
    print -r -- 'eval "$('"${(q)brew_bin}"' shellenv)"' >> ~/.zprofile || exit 1
  fi
  run_dir=$(mktemp -d "${TMPDIR:-/tmp}/new-mac.XXXXXXXX") || exit 1
  trap '[[ -z $cache_staging ]] || rm -f -- "$cache_staging"; rm -rf -- "$run_dir"' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  print -l 'connect-timeout = 15' 'speed-time = 35' 'speed-limit = 1024' 'max-time = 900' > "$run_dir/curlrc" || exit 1
  if ! run_brew update; then
    print -u2 '⚠️ Homebrew 更新失败，将继续尝试安装。'
    run_failed=1
  fi
fi

installed=() updated=() existing=() failed=() manual=()
for entry in $brew_items; do
  name=${entry%%|*} cask=${entry#*|}
  print "\n=== $name ($cask) ==="
  before=$(run_brew list --cask --versions "$cask" 2>/dev/null) || before=''
  action=install
  [[ -n $before ]] && action=upgrade

  if [[ $cask == workbuddy-cn || $cask == workbuddy-ai ]]; then
    if [[ $action == install ]] && ! HOMEBREW_CURL_RETRIES=0 run_brew fetch --cask "$cask"; then
      print '常规下载失败，尝试分段下载 WorkBuddy。'
      if ! cache_workbuddy "$cask"; then failed+=("$name"); continue; fi
    fi
    if ! HOMEBREW_CURL_RETRIES=0 run_brew "$action" --cask "$cask"; then
      if [[ $action == install ]]; then failed+=("$name"); continue; fi
      print '常规更新失败，尝试分段下载 WorkBuddy。'
      if ! cache_workbuddy "$cask" || ! run_brew upgrade --cask "$cask"; then failed+=("$name"); continue; fi
    fi
  elif ! run_brew "$action" --cask "$cask"; then
    failed+=("$name")
    continue
  fi

  after=$(run_brew list --cask --versions "$cask" 2>/dev/null) || after=''
  if [[ -z $after ]]; then failed+=("$name")
  elif [[ -z $before ]]; then installed+=("$name")
  elif [[ $before == $after ]]; then existing+=("$name")
  else updated+=("$name")
  fi
done
for entry in $open_items; do
  name=${entry%%|*} url=${entry#*|}
  print "\n=== $name ==="
  if ! open "$url"; then failed+=("$name（未能打开网页）"); fi
  manual+=("$name -> $url")
done

print '\n================ 结果 ================'
(( ${#installed[@]} )) && print -r -- "✅ 已安装: ${(j:、:)installed}"
(( ${#updated[@]} )) && print -r -- "✅ 已更新: ${(j:、:)updated}"
(( ${#existing[@]} )) && print -r -- "ℹ️ 版本未变: ${(j:、:)existing}"
(( ${#failed[@]} )) && print -u2 -r -- "❌ 失败: ${(j:、:)failed}"
if (( ${#manual[@]} )); then
  print '👉 请手动下载安装：'
  for entry in $manual; do print -r -- "   $entry"; done
fi
if (( run_failed || ${#failed[@]} )); then exit 1; fi
exit 0
