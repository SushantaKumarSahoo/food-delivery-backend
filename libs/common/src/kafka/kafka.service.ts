import { Inject, Injectable, Logger } from '@nestjs/common';
import { ClientKafka } from '@nestjs/microservices';
import { KAFKA_TOPICS } from './kafka.topics';

@Injectable()
export class KafkaService {
  private readonly logger = new Logger(KafkaService.name);

  constructor(
    @Inject('KAFKA_CLIENT') private readonly kafkaClient: ClientKafka,
  ) {}

  async onModuleInit() {
    try {
      // Subscribe to all topics as a consumer (best-effort — topics may not exist yet)
      Object.values(KAFKA_TOPICS).forEach((topic) => {
        try {
          this.kafkaClient.subscribeToResponseOf(topic);
        } catch {
          // ignore individual topic errors
        }
      });
      await this.kafkaClient.connect();
      this.logger.log('Kafka connected successfully');
    } catch (error) {
      this.logger.warn(`Kafka not available — events will be skipped. Error: ${error?.message}`);
    }
  }

  async onModuleDestroy() {
    await this.kafkaClient.close();
  }

  async emit<T = any>(topic: string, payload: T): Promise<void> {
    try {
      this.kafkaClient.emit(topic, {
        key: (payload as any)?.id || Date.now().toString(),
        value: JSON.stringify(payload),
      });
      this.logger.log(`Emitted event to topic: ${topic}`);
    } catch (error) {
      this.logger.warn(`Kafka emit skipped (broker unavailable) for topic ${topic}: ${error?.message}`);
    }
  }
}
