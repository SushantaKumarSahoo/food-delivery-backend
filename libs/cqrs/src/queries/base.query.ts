import { IQuery } from '@nestjs/cqrs';

export abstract class BaseQuery implements IQuery {
  constructor() {}
}
