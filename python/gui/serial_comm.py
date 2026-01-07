import serial

class SerialHandler:
    def __init__(self):
        self.ser = None

    def connect(self, port, baudrate=115200):
        try:
            if self.ser and self.ser.is_open:
                self.ser.close()
            self.ser = serial.Serial(port, baudrate, timeout=1)
            return True
        except:
            return False

    def send_start_trigger(self):
        if self.ser and self.ser.is_open:
            self.ser.write(b'\xAA')
            self.ser.close() # 다른 툴에서 포트를 쓸 수 있도록 전송 후 닫음
            return True
        return False