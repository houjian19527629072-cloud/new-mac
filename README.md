# new-mac

在 Mac 上按编号批量安装常用软件。清单共 13 项，11 项由 Homebrew 安装，Muse 和闪电说会打开官网下载页，需要手动安装。

## 用法

确认网络能访问 GitHub 和各软件的下载源，然后在 Mac 的终端粘贴这行命令：

```zsh
zsh -c 'script=$(curl -fsSL --connect-timeout 15 --max-time 60 https://raw.githubusercontent.com/houjian19527629072-cloud/new-mac/main/install.sh) && [[ -n $script ]] && zsh -c "$script"'
```

- 选装可以输入 `4 8 10`、`4,8,10` 或 `4、8、10`。这三个编号对应 Claude Code、DeepSeek Harness 和 WorkBuddy 国内版。
- 全选输入 `全部` 或 `a`。直接回车或输入 `q` 退出。
- 新 Mac 首次安装 Homebrew 时，按提示输入管理员密码并回车确认。Homebrew 可能需要先安装 Xcode 命令行工具。
- 重跑时，脚本会检查已选软件的版本。某项失败后会继续处理其他项，最后汇总结果并返回非零状态。WorkBuddy 常规下载失败时，脚本会尝试分段下载并校验安装包。

自动安装使用 Homebrew 当前提供的版本。软件是否支持当前系统或处理器取决于对应的 Homebrew 软件包，例如目前的 DeepSeek Harness 安装包要求 Apple Silicon。
