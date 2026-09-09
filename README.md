# 47_pdm_mic_udp_pc

UDP audio streaming project for the PDM microphone.

Current FPGA behavior:

- Top module: `ad_udp_pc`
- Board IP: `192.168.1.10`
- PC IP default in RTL: `192.168.1.102`
- UDP port: `1234`
- Start command: one UDP byte `0x01`
- Stop command: one UDP byte `0x00`
- Payload: raw little-endian signed PCM16
- Packet size: 1200 bytes, 600 samples
- PDM clock pin: `W19`, output `mic_clk`
- PDM data pin: `Y17`, input `mic_data`
- PDM clock: about 2.083 MHz from 50 MHz / 24
- Decimation: 64
- PCM sample rate: about 32.55 kHz
- Source select: `USE_FAKE_AUDIO = 0` uses the microphone, `USE_FAKE_AUDIO = 1` uses the internal triangle wave
- Auto stream: `AUTO_STREAM = 1` starts UDP streaming after reset without waiting for a start command
- PDM sample phase: `MIC_SAMPLE_ON_HIGH = 1` samples DATA during the high half of `mic_clk`; set to `0` to try the other half-cycle
- PDM density diagnostic: `MIC_OUTPUT_DENSITY = 1` streams raw PDM one-density per 64-bit block instead of CIC-filtered audio
- LED0 `H15`: heartbeat, toggles when the FPGA design and PLL are running
- LED1 `L15`: lights briefly when `mic_data` on `Y17` has any detected edge

Run the PC viewer:

```powershell
cd pc
python .\udp_wave_viewer.py --board-ip 192.168.1.10 --listen-port 1234 --sample-rate 32550
```

If the waveform is clipped or too small, adjust `CIC_SHIFT` in `rtl/ad_udp_pc.v` where `pdm_mic_pcm` is instantiated.

Quick diagnostic:

- If the PC viewer shows `packets=0`, set `USE_FAKE_AUDIO` to `1`, regenerate the bitstream, and test the Ethernet path again.
- With `AUTO_STREAM=1`, `packets=0` is not caused by the PC start command being missed.
- If `USE_FAKE_AUDIO=1` works but `USE_FAKE_AUDIO=0` does not show an audio waveform, set `MIC_OUTPUT_DENSITY=1` and regenerate the bitstream.
- In density mode, a working PDM input should move when you speak or tap near the microphone. A flat line near either extreme usually means `mic_data` is stuck high/low, floating, wrong pin, no microphone power, or a soldering problem.
- If density mode moves but CIC audio does not, try `MIC_SAMPLE_ON_HIGH=0`, then adjust `CIC_SHIFT`.
- Check `mic_clk` on `W19`, `mic_data` on `Y17`, microphone power, and IO voltage.

Hardware debug checklist:

1. LED0 toggles: FPGA design is alive. If not, check bitstream download, reset, and clock.
2. Measure `W19`: should be about 2.083 MHz. If not, the microphone clock is not reaching the pin.
3. LED1 lights or flickers: FPGA sees transitions on `Y17`. If LED1 never lights while LED0 is alive, `mic_data` is stuck, floating, on the wrong pin, unpowered, or not soldered.
4. In `MIC_OUTPUT_DENSITY=1`, the PC waveform should move if `Y17` receives real PDM data.

Important hardware note:

- The XDC currently uses `LVCMOS33` for `mic_clk` and `mic_data`.
- Confirm the microphone supply and IO voltage before powering it from the FPGA board.
