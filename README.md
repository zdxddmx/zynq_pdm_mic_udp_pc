# 基于 ZYNQ 的 PDM 麦克风阵列 UDP 音频流系统

> 在 Xilinx Zynq-7020 FPGA 上实现 PDM 数字麦克风采集 → CIC 抽取滤波 → 千兆以太网 UDP 实时音频流传输，配套 Python 上位机接收并显示波形。

## 技术栈

| 分类 | 技术 | 说明 |
|---|---|---|
| **FPGA 芯片** | Xilinx Zynq-7020（`xc7z020clg400-2`） | 本项目仅使用 PL 逻辑，未启用 PS |
| **开发语言** | Verilog HDL | 全部 RTL 手写，无 HLS |
| **开发工具** | Vivado 2020.2 | 综合 / 实现 / 烧录 |
| **仿真工具** | ModelSim | UDP 收发链路功能仿真（`sim/tb/tb_udp.v`） |
| **FPGA IP 核** | `async_fifo_2048x8b`、`clk_wiz_0` | 异步 FIFO 数据缓冲 + 时钟向导 |
| **网络协议** | 以太网 MAC（RGMII）/ ARP / UDP / IPv4 | 轻量协议栈全手写，无软核 CPU |
| **数字信号处理** | PDM 解调 + CIC 抽取滤波器 | 64 倍抽取，含可调移位增益 |
| **上位机** | Python 3（纯标准库：`argparse`/`socket`） | UDP 接收 + 波形显示 |
| **约束文件** | XDC（LVCMOS33） | 麦克风 IO：`W19`/`Y17`；LED：`H15`/`L15` |

## 系统架构

```
PDM 麦克风 ──mic_clk/mic_data──> pdm_mic_pcm ──PCM16──> ad_udp_pc(TOP)
   (W19/Y17)     2.083 MHz       (CIC 64x 抽取)            │
                                                           │
                    ┌──────────────────────────────────────┤
                    │                                      │
              async_fifo_2048x8b                     eth_top (MAC)
                    │                                      │
              udp_tx (组包/发 UDP)                    gmii_to_rgmii
                    └─────────────┬────────────────────────┘
                                  │
                          千兆以太网 PHY (RGMII)
                                  │
                           PC 上位机 udp_wave_viewer.py
```

- **发送链路**：`udp_tx` 按 1200 字节/包组包（600 个 PCM16 采样点），经 `eth_top` 完成 MAC 封装、`arp` 模块完成 ARP 解析、`gmii_to_rgmii` 驱动 PHY。
- **接收链路**：`udp_rx`/`arp_rx` 解析上位机下发的开始（`0x01`）/停止（`0x00`）命令，`start_transfer_ctrl` 控制采集启停。
- **调试辅助**：`fake_audio_gen` 内部三角波源、`ad1030_10bit_to_16bit` 外部 10-bit ADC 通路、`MIC_OUTPUT_DENSITY` PDM 密度诊断模式。

## 关键参数

| 参数 | 值 |
|---|---|
| 板卡 IP | `192.168.1.10`（PC：`192.168.1.102`） |
| UDP 端口 | `1234` |
| 本地 MAC | `48'h0123456789ab` |
| PDM 时钟 | 2.083 MHz（50 MHz / 24） |
| CIC 抽取比 | 64 |
| PCM 采样率 | ≈ 32.55 kHz |
| PCM 格式 | 16-bit 有符号小端 |
| 包格式 | 1200 字节 / 包（600 采样点） |
| 启动/停止命令 | UDP 单字节 `0x01` / `0x00` |
| 编译选项 | `USE_FAKE_AUDIO`、`AUTO_STREAM`、`MIC_SAMPLE_ON_HIGH`、`MIC_OUTPUT_DENSITY` |

## 目录结构

```
├── rtl/                      # Verilog 源码
│   ├── ad_udp_pc.v           # 顶层模块
│   ├── eth_top.v / eth_ctrl.v# 以太网 MAC 控制
│   ├── pdm_mic_pcm.v         # PDM 解码 + CIC 滤波
│   ├── fake_audio_gen.v      # 内部测试波形源
│   ├── ad1030_10bit_to_16bit.v # 10-bit ADC 数据扩展
│   ├── img_data_pkt.v        # 图像数据打包（预留）
│   ├── start_transfer_ctrl.v # 启停控制
│   ├── arp/                  # ARP 协议（rx/tx + CRC32）
│   ├── gmii_to_rgmii/        # GMII↔RGMII 转换
│   └── udp/                  # UDP 协议（rx/tx）
├── prj/                      # Vivado 工程（仅 .xpr + srcs，生成目录已忽略）
├── sim/tb/                   # ModelSim 仿真 testbench
├── pc/udp_wave_viewer.py     # Python 上位机
├── doc/ad_eth_pc.vsdx        # 系统架构图（Visio）
└── README.md
```

## 项目现状与诚实边界

本仓库当前是**单路 PDM 麦克风采集传输链路**的工程实现，不是 16 路阵列声源定位系统的整机交付。如实区分如下：

| 状态 | 内容 |
|---|---|
| ✅ 已实现（代码可复核） | PDM 解码 + 3 级 CIC 64 倍抽取（32.55 kHz / 16-bit PCM）；UDP/ARP/RGMII 千兆以太网传输链路集成；自研 Python 上位机波形显示；参数化调试体系（伪音源 / 密度诊断 / 增益调节）；ModelSim 仿真 TB |
| ⚠️ 缺实测证据 | 仓库暂无实机运行照片、示波器截图或视频；请补充硬件验证证据后再对外宣称"实测通过" |
| 📋 规划中（未实现） | 16 路 PDM MEMS 圆环阵列并行采集、FFT / 波束形成、声压热力图、摄像头 Alpha 融合、多麦克风时钟同步 |
| 📌 第三方代码声明 | `rtl/udp/`、`rtl/arp/`、`rtl/eth_top.v` 等以太网模块基于**正点原子教学平台**代码（文件头保留版权声明）；自研部分为 `pdm_mic_pcm.v`（PDM/CIC 信号链）、顶层集成、上位机、仿真与文档 |

> 面试/汇报口径：已完成的成果以"单路 PDM→CIC→UDP 全链路 + 上位机"为界；16 路阵列与波束形成属于毕设后续规划，不对外描述为已完成。详细状态见 [`docs/PROJECT_STATUS.md`](docs/PROJECT_STATUS.md)。

## 快速上手

### 构建 FPGA 工程

1. Vivado 2020.2 打开 `prj/ad_udp_pc.xpr`
2. Generate Bitstream（IP 会自动重新生成）
3. 烧录 bit 流

### 运行上位机

```powershell
cd pc
python .\udp_wave_viewer.py --board-ip 192.168.1.10 --listen-port 1234 --sample-rate 32550
```

### 故障排查

- 上位机显示 `packets=0`：先把 `USE_FAKE_AUDIO` 置 1 验证以太网通路，再切回麦克风；
- `USE_FAKE_AUDIO=1` 正常但真麦克风无波形：置 `MIC_OUTPUT_DENSITY=1` 观察 PDM 密度——平线说明 `mic_data` 引脚悬空/焊错/麦克风未供电；
- 波形削顶或过小：调整 `rtl/ad_udp_pc.v` 中 `CIC_SHIFT`；
- 时钟异常：量测 `W19` 应为 2.083 MHz；LED0（`H15`）心跳表示 PLL 正常。

## 安全说明

- 板卡/PC IP 为实验室调试网段配置，部署时按需修改 `rtl/ad_udp_pc.v`、`rtl/eth_top.v` 中的参数。
