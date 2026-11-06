# new-mac

新 Mac 一键安装常用软件。运行后选编号，自动安装（都是最新版）。

## 用法

先把梯子开好（中国大陆网络），打开终端，粘贴这一行回车：

```bash
zsh -c "$(curl -fsSL https://raw.githubusercontent.com/houjian19527629072-cloud/new-mac/main/install.sh)"
```

然后按提示输入编号，编号之间用空格隔开，例如 `1 3 5`；回车或输入 `a` 是全部安装，`q` 退出。

软件清单在 `install.sh` 开头的 `ITEMS` 里，想增删直接改。
