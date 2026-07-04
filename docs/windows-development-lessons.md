# macOS 开发复盘与 Windows 版本指导

## 核心结论

FreeThumb 最重要的工程经验是：**空闲休眠、物理合盖、显示器关闭和锁屏是四条不同链路**。Windows 版本必须分别设计、检测和验收，不能用一个“防休眠”开关概括全部行为。

## 遇到的问题与解决方案

| 问题 | macOS 解决方案 | Windows 开发指导 |
| --- | --- | --- |
| 普通防休眠 API 无法覆盖物理合盖 | 普通 IOKit assertion 只处理 idle sleep；合盖模式单独使用受控的 `pmset disablesleep` | 首选 `PowerCreateRequest` + `PowerSetRequest(PowerRequestSystemRequired)` 处理 idle sleep。但微软明确说明用户主动合盖、按电源键或选择睡眠会终止普通 power request，因此不要默认承诺合盖继续运行。 |
| 全局电源设置可能在崩溃后残留 | 修改前记录原值，正常停止时恢复；独立 watchdog 在主进程崩溃后恢复 | Power Request 必须成对调用 `PowerSetRequest` / `PowerClearRequest`，最后 `CloseHandle`。如果将来允许修改合盖电源计划，必须先保存原值，并使用独立恢复进程；不要静默永久修改用户电源计划。 |
| “关屏”和“锁屏”被错误地当成同一件事 | 放弃会触发锁屏策略的 `displaysleepnow`；合盖仅调整内屏背光；保护会话可跨越用户正常锁屏 | Windows 应让 power request 跨越用户正常锁屏，不需要在应用内重复提供锁屏按钮。 |
| 不同机器的睡眠模型差异很大 | 在真实 MacBook 上检查 `powerd`、`SleepDisabled` 和合盖日志 | 启动时检测 S3 / Modern Standby 能力，并明确展示支持等级。Modern Standby 会暂停普通桌面应用；DC 模式下 system/execution power request 还有额外限制。 |
| 状态只靠颜色难以判断 | 绿拇指、黄三角、红八角使用不同符号和无障碍标签 | Windows 托盘图标也要同时改变颜色、形状和 Tooltip/无障碍文本，不能只换颜色。 |
| 传感器每秒刷新容易重复告警 | 将触发判断、独立条件 cooldown 和投递渠道拆开；投递失败不停止保护 | 复用相同分层：纯策略层生成事件，渠道适配器负责 Windows Toast、邮件或 Webhook。Webhook 密钥存 Windows Credential Manager/DPAPI，不写普通配置文件。 |
| 权限提示或网络请求可能卡住主流程 | 通知授权异步进行；远程投递失败只显示错误 | 启动防休眠必须先完成，不应等待 Toast、网络或第三方客户端；所有投递设置超时并异步执行。 |
| 仅靠单元测试无法证明电源链路 | 同时检查策略测试、系统日志、强制退出、真实合盖和恢复状态 | 测试矩阵至少覆盖：S3/Modern Standby、AC/DC、盖子开/关、锁屏、正常退出、强制退出、定时结束及重启恢复。 |

## 推荐的 Windows MVP 顺序

1. 系统托盘 UI、定时会话和明确的状态图标。
2. 使用带原因文本的 Power Request 阻止 idle sleep；停止时清理 request 和 handle。
3. 读取 AC/电池、低电量和系统电源事件，复用现有告警语义。
4. 显示当前睡眠模型和合盖能力诊断；首版不自动修改合盖策略。
5. 完成真实硬件矩阵后，再决定是否提供用户确认后的合盖策略向导。

## 架构建议

当前 macOS 版本已经是稳定的 Swift 原生实现，不建议为了跨平台立即重写。Windows MVP 可以使用 C#/.NET 调用 Win32 API，先共享以下内容而不是共享源码：

- 状态机和告警事件定义；
- 配置字段及默认值；
- Webhook JSON 格式；
- 测试向量和验收矩阵。

等 Windows MVP 证明行为稳定后，再评估是否将纯策略层迁移到 Rust 等跨平台核心。过早统一 UI 和系统层会掩盖两个平台完全不同的电源语义。

## 官方参考

- [SetThreadExecutionState](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-setthreadexecutionstate)
- [PowerCreateRequest](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-powercreaterequest)
- [PowerSetRequest](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-powersetrequest)
- [Modern Standby](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/modern-standby)
- [Desktop apps in Modern Standby](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/integrating-apps-with-modern-standby)
