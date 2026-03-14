# RoCE Emulator Enablement Plan

> 目标：让 HSB Emulator 在没有实体 Hololink/VB1940 硬件的情况下，也能完整跑通 RoCE 控制面 + 数据面，使 `vb1940_player.py` 与 Holoviz GUI 在 DGX Spark 平台进入 STREAMING。

## 阶段 0 · 资料梳理（进行中）

- **文档速读**：提炼 `docs/user_guide/(dataplane|emulation|architecture).md` 中和 RoCE 相关的协议、寄存器、状态机，输出结构化笔记。
- **代码脉络**：绘制下列模块的调用关系与数据流：
  - `src/hololink/emulation/*`（LinuxDataPlane、LinuxTransmitter、vb1940_emulator 等）
  - `src/hololink/operators/roce_receiver/*` 与 Python binding
  - `python/hololink/sensors/vb1940/vb1940.py`（SYSTEM_FSM 交互）
- **产物**：`notes/roce-study.md`（后续创建），用于记录协议摘抄、寄存器表、状态机图。该笔记会成为阶段 1/2 的参考。

## 阶段 1 · 最小可用 PoC（UDP → ibverbs Shim）

**分支**：`feature/roce-emulator/poc1-udp-ibverbs`

1. **RoCE 数据面桥接**
   - 监听 emulator 通过 `LinuxDataPlane` 发出的“RoCEv2 over UDP”包。
   - 在宿主侧实现一个 shim，将这些 UDP payload 解析成 RDMA Write / Write Imm 语义，喂给 `RoceReceiverOp` 期望的 CQ。
   - 默认用 Python/C++ mock `ibv_context`, `ibv_qp`, `ibv_cq` 等结构，保证 `Enumerator.find_channel()` 能发现 192.168.0.2。

2. **I2C / 控制面透传**
   - RoCE 路径的 `camera.configure()` 会频繁写 `SYSTEM_UP_REG / BOOT_REG / SW_STBY_REG`。
   - 需要把这些写操作透传至现有 emulator 的 I2C 接口，触发 `vb1940_emulator.cpp` 内的状态机回调，让 FSM 从 0x4 正常走到 SW_STBY / STREAMING。

3. **验证**
   - `vb1940_player.py --hololink 192.168.0.2 --ibv-name rocep1s0f1 --ibv-port 1` 能跑完初始化并在 Holoviz 看到画面。
   - pytest `test_vb1940_player --vb1940 --hsb --headless --frame-limit 60 --hw-loopback ...` 不再报 “Device with 192.168.0.2 not found”。

## 阶段 2 · Native RoCE 控制面（可选 / 高难度）

**分支**：`feature/roce-emulator/poc2-native-verbs`

- 在 emulator 所在 network namespace 内直接实现真正的 ibverbs target，或复用 CX-7 双口形成硬件 loopback。
- 任务：
  - 复刻 HSB IP 的 RNIC 行为（QP 初始化、doorbell、CQE 生成、I2C over RoCE 通道）。
  - 让 `RoceReceiverOp` 直接和 namespace 内的 RNIC 握手，无需 shim。
- 价值：为将来自研 FPGA 相机提供最贴近实机的仿真环境，也方便向 NVIDIA 提交 upstream patch。

## 协作与分支策略

- `main`：保持与 `upstream/main` 同步，不直接提交实验代码。
- `feature/roce-emulator/*`：RoCE 相关的所有工作都在子分支展开，完成功能后提 PR 合并回你自己的 `main`，再视情况 upstream。
- **AI 协作点**：
  - 文档速读 & 摘要
  - 调用图 / 依赖图生成
  - Shim/Mock 框架的初稿（C++/Python）
  - 测试脚本与日志分析

---

后续每个阶段的产物（笔记、PoC、测试日志）都会追加到 `docs/` 或 `notes/` 目录，便于回溯。
