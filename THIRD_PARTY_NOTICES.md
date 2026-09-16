# 第三方组件说明

本仓库包含以下第三方代码。它们的版权与许可归各自作者所有，**不适用**根目录 `LICENSE`（MIT）中的条款。

## 正点原子例程

位置：`rtl/arp/`、`rtl/udp/`、`rtl/gmii_to_rgmii/`、`rtl/eth_ctrl.v`、`rtl/eth_top.v`、`rtl/start_transfer_ctrl.v`

Copyright(C) 正点原子 2023-2033，版权声明为"版权所有，盗版必究"。

这些是正点原子随 Zynq 开发板提供的以太网例程，包括 ARP 协议栈、UDP 收发、GMII 转 RGMII 时序以及 CRC32 校验。版权归正点原子所有，本仓库仅作参考引用。根目录的 MIT 许可**不覆盖**这些文件，任何超出个人学习范围的再分发请自行联系原作者取得授权。

## 自研部分

`rtl/pdm_mic_pcm.v`（PDM 麦克风的 CIC 抽取滤波与 PCM 还原信号链）、`rtl/ad1030_10bit_to_16bit.v`、`rtl/fake_audio_gen.v`、`rtl/img_data_pkt.v` 的数据搬运改造，以及 `prj/` 下的 Vivado 工程约束与 `sim/` 测试平台为本工程编写。

## 已知问题

`rtl/img_data_pkt.v` 头部的部分中文注释存在双重编码损坏，成因是早期提交时已按错误编码保存。可恢复的行已修复，标有 `锟斤拷` 的位置为字节丢失，无法还原。

## 关于文件编码

仓库内部分 Verilog 源文件原本为 GBK 编码，现已统一转为 UTF-8（无 BOM），仅为显示考虑，未改动任何逻辑。
