import mqtt from "mqtt";

const BROKER_URL = process.env.MQTT_BROKER_URL || "mqtt://mosquitto:1883";
const INTERVAL_MS = Number(process.env.PUBLISH_INTERVAL_MS || 1000);

const DISTANCE_TOPIC = "sensor/distance";
const LIGHT_TOPIC = "sensor/light";

function randomDistanceValue() {
  if (Math.random() < 0.05) {
    // sensorfout: negatieve afstand of een onrealistisch grote echo
    return Math.random() < 0.5
      ? -Math.round(Math.random() * 100)
      : Math.round(400 + Math.random() * 4000);
  }
  return Math.round(Math.random() * 400); // geldig bereik: 0..400 cm
}

function randomLightValue() {
  if (Math.random() < 0.05) {
    return -Math.round(Math.random() * 100); // ongeldig: negatieve lichtsterkte bestaat niet
  }
  return Math.round(Math.random() * 1000); // geldig bereik: 0..1000 lux
}

function connect() {
  const client = mqtt.connect(BROKER_URL, {
    reconnectPeriod: 2000,
  });

  client.on("connect", () => {
    console.log(`[simulator] verbonden met broker op ${BROKER_URL}`);

    setInterval(() => {
      const distancePayload = {
        distance_cm: randomDistanceValue(),
        timestamp: new Date().toISOString(),
      };
      client.publish(DISTANCE_TOPIC, JSON.stringify(distancePayload));

      const lightPayload = {
        lux: randomLightValue(),
        timestamp: new Date().toISOString(),
      };
      client.publish(LIGHT_TOPIC, JSON.stringify(lightPayload));
    }, INTERVAL_MS);
  });

  client.on("error", (err) => {
    console.error("[simulator] MQTT-fout:", err.message);
  });

  client.on("reconnect", () => {
    console.log("[simulator] opnieuw verbinden met broker...");
  });
}

connect();
