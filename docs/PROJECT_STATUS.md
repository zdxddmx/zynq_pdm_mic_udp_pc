# 项目状态

更新日期：2026-09-09
适用仓库：`zynq_pdm_mic_udp_pc`

## 一、已实现（代码可复核）

- PDM 数字麦克风信号链：PDM 时钟生成（50 MHz 分频约 2.083 MHz）、采样相位可配；
- 3 级积分 + 3 级梳状 CIC 抽取滤波器（64×），带 `CIC_SHIFT` 增益调整与 `sat16` 饱和截位，输出 16-bit PCM；
- 顶层参数化配置：板卡/PC 的 MAC/IP、`USE_FAKE_AUDIO` 伪音源、`AUTO_STREAM` 自动推流、`MIC_OUTPUT_DENSITY` 密度诊断；
- UDP 单字节启停协议（`0x01`/`0x00`）、`start_transfer_ctrl` 启停控制、`async_fifo` 跨时钟域缓冲；
- 1200 字节/包（600 采样点）UDP 组帧发送，千兆 RGMII 物理层适配；
- 心跳 LED（`H15`）与麦克风边沿检测 LED（`L15`）；
- Python 上位机 `pc/udp_wave_viewer.py`（纯标准库，CLI 参数化）；
- ModelSim 仿真 testbench `sim/tb/tb_udp.v`。

## 二、证据缺口（对外宣称前需补充）

| 缺口 | 建议补充方式 |
|---|---|
| 实机运行证据 | 板卡实物照片、运行视频或截图，放入 `docs/images/` |
| 波形正确性证据 | PC 上位机波形截图、示波器量测 PDM 时钟（`W19`）截图 |
| 构建证据 | Vivado 综合/实现通过日志，可放入 `docs/evidence/` |
| 当前固件实测记录 | 伪音源模式与真实麦克风模式的对比记录 |

当前状态应表述为"代码与仿真已完成，硬件实测证据待补充"，不对外宣称"全部实测通过"。

## 三、规划中（未实现，勿写为成果）

- 16 路 PDM MEMS 圆环阵列并行采集与通道同步方案落地；
- CIC / FIR / FFT 定点处理链；
- 频域延迟叠加（Delay-and-Sum）波束形成；
- 二维声压热力图生成与摄像头视频 Alpha 融合；
- 多路麦克风时钟同步与等长走线的 PCB 验证。

## 四、第三方代码声明

- `rtl/udp/`、`rtl/arp/`、`rtl/eth_top.v`、`rtl/gmii_to_rgmii/` 等以太网相关模块基于**正点原子（原子哥）教学平台**代码，文件头保留原版权声明；
- 自研部分：`rtl/pdm_mic_pcm.v`（PDM 解码 + CIC）、`rtl/ad_udp_pc.v`（顶层集成）、`rtl/fake_audio_gen.v`、`rtl/start_transfer_ctrl.v`、`rtl/ad1030_10bit_to_16bit.v`、`pc/` 上位机、仿真与全部文档；
- 面试/汇报中不应将第三方以太网协议栈表述为完全自研。

## 五、下一步建议

1. 补充"证据缺口"表格中的实机照片与波形截图；
2. 在 Vivado 2020.2 上做一次干净全量构建，保存日志；
3. 开展 16 路阵列方案：先做 2 路 PDM 同步采集验证时钟方案，再扩展到 16 路；
4. 波束形成先在 PC 端用离线数据验证算法，再移入 PL 定点实现。
