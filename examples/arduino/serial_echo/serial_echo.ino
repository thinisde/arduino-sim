void setup() {
  Serial.begin(9600);
  Serial.println("serial echo ready");
}

void loop() {
  while (Serial.available() > 0) {
    int c = Serial.read();
    Serial.write((char)c);
  }
}
