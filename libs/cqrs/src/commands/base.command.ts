import { ICommand } from '@nestjs/cqrs';

export abstract class BaseCommand implements ICommand {
  constructor() {}
}
