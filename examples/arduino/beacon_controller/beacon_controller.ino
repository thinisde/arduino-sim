#include <Arduino.h>
#include <avr/interrupt.h>

/*
  Beacon Controller Test Sketch

  Purpose:
  - D2 button toggles ARMED/DISARMED using external interrupt INT0.
  - D13 heartbeat/status LED changes pattern based on state.
  - A0 potentiometer controls PWM brightness on D9.
  - D8 buzzer chirps when armed.
  - D4 is sampled as a generic digital sensor input.
  - Timer1 compare interrupt creates a 1ms software tick.
  - Serial prints periodic status.

  Pins:
  - D2  = button input, active LOW, uses attachInterrupt()
  - D4  = digital sensor input with pullup
  - D8  = buzzer output
  - D9  = PWM brightness output
  - D13 = onboard LED
  - A0  = analog input
*/

const uint8_t PIN_BUTTON = 2;
const uint8_t PIN_SENSOR = 4;
const uint8_t PIN_BUZZER = 8;
const uint8_t PIN_PWM = 9;
const uint8_t PIN_LED = 13;
const uint8_t PIN_ANALOG = A0;

enum SystemState : uint8_t {
  DISARMED = 0,
  ARMED = 1,
  ALARM = 2,
};

volatile bool buttonInterruptSeen = false;
volatile uint32_t buttonInterruptMicros = 0;
volatile uint32_t timer1Millis = 0;

SystemState state = DISARMED;

uint32_t lastButtonHandledMs = 0;
uint32_t lastHeartbeatMs = 0;
uint32_t lastAnalogSampleMs = 0;
uint32_t lastSerialReportMs = 0;
uint32_t lastBuzzerMs = 0;

bool ledLevel = false;
bool buzzerLevel = false;

uint16_t analogValue = 0;
uint8_t pwmValue = 0;
uint32_t stateChanges = 0;

ISR(TIMER1_COMPA_vect) {
  timer1Millis++;
}

void configureTimer1For1msTick() {
  noInterrupts();

  TCCR1A = 0;
  TCCR1B = 0;
  TCNT1 = 0;

  // 16 MHz / 64 prescaler = 250 kHz.
  // 250 counts = 1 ms, so OCR1A = 249.
  OCR1A = 249;

  // CTC mode.
  TCCR1B |= (1 << WGM12);

  // Prescaler 64.
  TCCR1B |= (1 << CS11) | (1 << CS10);

  // Enable Timer1 compare A interrupt.
  TIMSK1 |= (1 << OCIE1A);

  interrupts();
}

void onButtonInterrupt() {
  buttonInterruptMicros = micros();
  buttonInterruptSeen = true;
}

const char *stateName(SystemState s) {
  switch (s) {
    case DISARMED:
      return "DISARMED";
    case ARMED:
      return "ARMED";
    case ALARM:
      return "ALARM";
    default:
      return "UNKNOWN";
  }
}

void setState(SystemState next) {
  if (state == next) {
    return;
  }

  state = next;
  stateChanges++;

  if (state == DISARMED) {
    digitalWrite(PIN_BUZZER, LOW);
    buzzerLevel = false;
  }

  Serial.print(F("state="));
  Serial.print(stateName(state));
  Serial.print(F(" changes="));
  Serial.println(stateChanges);
}

void handleButton() {
  if (!buttonInterruptSeen) {
    return;
  }

  noInterrupts();
  bool seen = buttonInterruptSeen;
  uint32_t irqMicros = buttonInterruptMicros;
  buttonInterruptSeen = false;
  interrupts();

  if (!seen) {
    return;
  }

  uint32_t nowMs = millis();

  // Debounce: ignore button events closer than 50 ms.
  if (nowMs - lastButtonHandledMs < 50) {
    return;
  }

  lastButtonHandledMs = nowMs;

  // Verify the input is still active LOW after the interrupt.
  if (digitalRead(PIN_BUTTON) == LOW) {
    if (state == DISARMED) {
      setState(ARMED);
    } else {
      setState(DISARMED);
    }

    Serial.print(F("button_us="));
    Serial.println(irqMicros);
  }
}

void sampleInputs() {
  uint32_t now = millis();

  if (now - lastAnalogSampleMs < 20) {
    return;
  }

  lastAnalogSampleMs = now;

  analogValue = analogRead(PIN_ANALOG);
  pwmValue = map(analogValue, 0, 1023, 0, 255);

  analogWrite(PIN_PWM, pwmValue);

  bool sensorActive = digitalRead(PIN_SENSOR) == LOW;

  if (state == ARMED && sensorActive) {
    setState(ALARM);
  }
}

void updateHeartbeat() {
  uint32_t now = millis();

  uint16_t interval;

  switch (state) {
    case DISARMED:
      interval = 700;
      break;
    case ARMED:
      interval = 250;
      break;
    case ALARM:
      interval = 80;
      break;
    default:
      interval = 500;
      break;
  }

  if (now - lastHeartbeatMs >= interval) {
    lastHeartbeatMs = now;

    ledLevel = !ledLevel;
    digitalWrite(PIN_LED, ledLevel ? HIGH : LOW);
  }
}

void updateBuzzer() {
  uint32_t now = millis();

  if (state != ALARM) {
    if (buzzerLevel) {
      buzzerLevel = false;
      digitalWrite(PIN_BUZZER, LOW);
    }
    return;
  }

  if (now - lastBuzzerMs >= 40) {
    lastBuzzerMs = now;

    buzzerLevel = !buzzerLevel;
    digitalWrite(PIN_BUZZER, buzzerLevel ? HIGH : LOW);

    // Small timing-sensitive pulse to exercise delayMicroseconds().
    delayMicroseconds(25);
  }
}

void reportStatus() {
  uint32_t now = millis();

  if (now - lastSerialReportMs < 1000) {
    return;
  }

  lastSerialReportMs = now;

  noInterrupts();
  uint32_t timerTickSnapshot = timer1Millis;
  interrupts();

  Serial.print(F("ms="));
  Serial.print(now);

  Serial.print(F(" timer1_ms="));
  Serial.print(timerTickSnapshot);

  Serial.print(F(" us="));
  Serial.print(micros());

  Serial.print(F(" state="));
  Serial.print(stateName(state));

  Serial.print(F(" analog="));
  Serial.print(analogValue);

  Serial.print(F(" pwm="));
  Serial.print(pwmValue);

  Serial.print(F(" button="));
  Serial.print(digitalRead(PIN_BUTTON));

  Serial.print(F(" sensor="));
  Serial.println(digitalRead(PIN_SENSOR));
}

void setup() {
  Serial.begin(9600);

  pinMode(PIN_LED, OUTPUT);
  pinMode(PIN_PWM, OUTPUT);
  pinMode(PIN_BUZZER, OUTPUT);

  pinMode(PIN_BUTTON, INPUT_PULLUP);
  pinMode(PIN_SENSOR, INPUT_PULLUP);

  digitalWrite(PIN_LED, LOW);
  digitalWrite(PIN_BUZZER, LOW);
  analogWrite(PIN_PWM, 0);

  configureTimer1For1msTick();

  attachInterrupt(digitalPinToInterrupt(PIN_BUTTON), onButtonInterrupt, FALLING);

  Serial.println(F("beacon controller boot"));
  Serial.println(F("press D2 to arm/disarm; pull D4 low to trigger alarm"));
}

void loop() {
  handleButton();
  sampleInputs();
  updateHeartbeat();
  updateBuzzer();
  reportStatus();

  // Small cooperative pause. Still uses Arduino timing code.
  delay(1);
}
