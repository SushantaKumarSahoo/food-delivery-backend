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
    // Subscribe to all topics as a consumer
    Object.values(KAFKA_TOPICS).forEach((topic) => {
      this.kafkaClient.subscribeToResponseOf(topic);
    });
    await this.kafkaClient.connect();
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
      this.logger.error(`Failed to emit to topic ${topic}:`, error);
    }
  }
}
