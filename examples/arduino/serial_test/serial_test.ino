void setup() {
  pinMode(13, OUTPUT);
  digitalWrite(13, HIGH);

  Serial.begin(9600);
  Serial.println("hello");
}

void loop() {
}
