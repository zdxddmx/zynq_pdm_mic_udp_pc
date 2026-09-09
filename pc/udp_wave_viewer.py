import argparse
import socket
import sys
import time

try:
    import numpy as np
    import pyqtgraph as pg
    from pyqtgraph.Qt import QtCore, QtWidgets
except ImportError as exc:
    print("Missing dependency:", exc)
    print("Install with: python -m pip install numpy pyqtgraph PyQt5")
    sys.exit(1)


def parse_args():
    parser = argparse.ArgumentParser(description="Receive FPGA UDP PCM16 data and show waveform.")
    parser.add_argument("--listen-ip", default="0.0.0.0", help="local bind address")
    parser.add_argument("--listen-port", type=int, default=1234, help="local UDP port")
    parser.add_argument("--board-ip", default="192.168.1.10", help="FPGA board IP")
    parser.add_argument("--board-port", type=int, default=1234, help="FPGA UDP port")
    parser.add_argument("--sample-rate", type=int, default=48000, help="PCM sample rate")
    parser.add_argument("--window-samples", type=int, default=4096, help="display buffer length")
    parser.add_argument("--start-interval", type=float, default=1.0, help="seconds between repeated start commands")
    return parser.parse_args()


class UdpWaveViewer(QtWidgets.QMainWindow):
    def __init__(self, args):
        super().__init__()
        self.args = args
        self.socket_closed = False
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.sock.bind((args.listen_ip, args.listen_port))
        self.sock.setblocking(False)

        self.board_addr = (args.board_ip, args.board_port)
        self.buffer = np.zeros(args.window_samples, dtype=np.int16)
        self.packet_count = 0
        self.byte_count = 0
        self.last_stat_time = time.monotonic()
        self.last_packet_count = 0

        self.setWindowTitle("FPGA UDP PCM16 Waveform")
        self.resize(1000, 520)

        central = QtWidgets.QWidget()
        layout = QtWidgets.QVBoxLayout(central)
        self.setCentralWidget(central)

        toolbar = QtWidgets.QHBoxLayout()
        layout.addLayout(toolbar)

        self.start_button = QtWidgets.QPushButton("Start")
        self.stop_button = QtWidgets.QPushButton("Stop")
        self.status_label = QtWidgets.QLabel("Idle")
        toolbar.addWidget(self.start_button)
        toolbar.addWidget(self.stop_button)
        toolbar.addWidget(self.status_label, 1)

        self.plot = pg.PlotWidget()
        self.plot.setYRange(-32768, 32767)
        self.plot.setLabel("left", "PCM16")
        self.plot.setLabel("bottom", "Samples")
        self.curve = self.plot.plot(self.buffer, pen=pg.mkPen("#00a7b5", width=1))
        layout.addWidget(self.plot)

        self.start_button.clicked.connect(self.send_start)
        self.stop_button.clicked.connect(self.send_stop)

        self.timer = QtCore.QTimer(self)
        self.timer.timeout.connect(self.poll_socket)
        self.timer.start(10)

        self.stat_timer = QtCore.QTimer(self)
        self.stat_timer.timeout.connect(self.update_status)
        self.stat_timer.start(500)

        self.start_timer = QtCore.QTimer(self)
        self.start_timer.timeout.connect(self.send_start)
        if args.start_interval > 0:
            self.start_timer.start(int(args.start_interval * 1000))

        self.send_start()

    def send_start(self):
        if self.socket_closed:
            return
        try:
            self.sock.sendto(bytes([1]), self.board_addr)
        except OSError:
            self.socket_closed = True

    def send_stop(self):
        if self.socket_closed:
            return
        try:
            self.sock.sendto(bytes([0]), self.board_addr)
        except OSError:
            self.socket_closed = True

    def poll_socket(self):
        if self.socket_closed:
            return

        updated = False
        while True:
            try:
                data, _addr = self.sock.recvfrom(4096)
            except BlockingIOError:
                break
            except OSError:
                self.socket_closed = True
                break

            if len(data) < 2:
                continue
            if len(data) & 1:
                data = data[:-1]

            samples = np.frombuffer(data, dtype="<i2")
            if samples.size == 0:
                continue

            n = min(samples.size, self.buffer.size)
            self.buffer = np.roll(self.buffer, -n)
            self.buffer[-n:] = samples[-n:]
            self.packet_count += 1
            self.byte_count += len(data)
            updated = True

        if updated:
            self.curve.setData(self.buffer)

    def update_status(self):
        now = time.monotonic()
        dt = max(now - self.last_stat_time, 1e-6)
        pkt_rate = (self.packet_count - self.last_packet_count) / dt
        self.last_stat_time = now
        self.last_packet_count = self.packet_count
        self.status_label.setText(
            f"packets={self.packet_count}  rate={pkt_rate:.1f} pkt/s  "
            f"bytes={self.byte_count}  board={self.board_addr[0]}:{self.board_addr[1]}"
        )

    def closeEvent(self, event):
        self.timer.stop()
        self.stat_timer.stop()
        self.start_timer.stop()
        try:
            self.send_stop()
        finally:
            if not self.socket_closed:
                self.sock.close()
                self.socket_closed = True
        event.accept()


def main():
    args = parse_args()
    app = QtWidgets.QApplication(sys.argv)
    viewer = UdpWaveViewer(args)
    viewer.show()
    exec_app = getattr(app, "exec", None) or getattr(app, "exec_")
    sys.exit(exec_app())


if __name__ == "__main__":
    main()
