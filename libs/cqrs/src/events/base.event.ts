import { IEvent } from '@nestjs/cqrs';

export abstract class BaseEvent implements IEvent {
  public readonly timestamp: Date = new Date();
  
  constructor(public readonly streamId: string) {}
}
