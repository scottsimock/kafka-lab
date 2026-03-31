import { KafkaJS } from '@confluentinc/kafka-javascript';

// Re-export types for convenience
export type KafkaConfig = KafkaJS.KafkaConfig;
export type SASLOptions = KafkaJS.SASLOptions;
export type Admin = KafkaJS.Admin;
export type Producer = KafkaJS.Producer;
export type Consumer = KafkaJS.Consumer;

// Singleton Kafka instance
let kafka: KafkaJS.Kafka | null = null;

// Get or create the singleton Kafka client
export function getKafkaClient(): KafkaJS.Kafka {
  if (!kafka) {
    const brokers = process.env.KAFKA_BOOTSTRAP_SERVERS;
    const username = process.env.KAFKA_USERNAME;
    const password = process.env.KAFKA_PASSWORD;
    const sslCa = process.env.KAFKA_SSL_CA;

    if (!brokers || !username || !password) {
      throw new Error('Missing required Kafka environment variables: KAFKA_BOOTSTRAP_SERVERS, KAFKA_USERNAME, KAFKA_PASSWORD');
    }

    const kafkaConfig: KafkaJS.KafkaConfig = {
      brokers: brokers.split(','),
      ssl: true,
      sasl: {
        mechanism: 'plain',
        username,
        password,
      },
    };

    // If custom CA is provided, configure it in the GlobalConfig
    const globalConfig = sslCa
      ? { 'ssl.ca.pem': sslCa }
      : {};

    kafka = new KafkaJS.Kafka({
      ...globalConfig,
      kafkaJS: kafkaConfig,
    });
  }

  return kafka;
}

// Get an admin client — caller must connect/disconnect
export function getAdmin(): KafkaJS.Admin {
  return getKafkaClient().admin();
}

// Get a producer — caller must connect/disconnect
export function getProducer(): KafkaJS.Producer {
  return getKafkaClient().producer();
}

// Get a consumer with the specified group ID — caller must connect/disconnect
export function getConsumer(groupId: string): KafkaJS.Consumer {
  return getKafkaClient().consumer({ kafkaJS: { groupId } });
}

// Graceful shutdown handler for SIGTERM
async function shutdown(): Promise<void> {
  if (kafka) {
    try {
      // The Kafka client doesn't expose a direct disconnect method
      // Cleanup is handled by individual admin/producer/consumer disconnect calls
      // Setting to null allows garbage collection
      kafka = null;
    } catch (error) {
      console.error('Error during Kafka shutdown:', error);
    }
  }
}

// Register shutdown handler (server-side only)
if (typeof process !== 'undefined' && process.on) {
  process.on('SIGTERM', () => {
    shutdown().catch((error) => {
      console.error('Error in SIGTERM handler:', error);
      process.exit(1);
    });
  });
}
