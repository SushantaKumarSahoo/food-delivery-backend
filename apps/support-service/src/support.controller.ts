import {
  Controller,
  Get,
  Post,
  Patch,
  Body,
  Param,
  Query,
  UseGuards,
} from '@nestjs/common';
import { SupportService } from './support.service';
import { JwtAuthGuard, CurrentUser } from '@quickbite/common';

@UseGuards(JwtAuthGuard)
@Controller('support')
export class SupportController {
  constructor(private readonly supportService: SupportService) {}

  // ─── Tickets (Customer) ────────────────────────────────────────────────────

  @Post('tickets')
  createTicket(
    @CurrentUser() user: any,
    @Body() body: {
      subject: string;
      description: string;
      category?: string;
      orderId?: string;
      priority?: string;
    },
  ) {
    return this.supportService.createTicket(user.userId, body);
  }

  @Get('tickets')
  getUserTickets(@CurrentUser() user: any, @Query('status') status?: string) {
    return this.supportService.getUserTickets(user.userId, status);
  }

  @Get('tickets/all')
  getAllTickets(
    @Query('status') status?: string,
    @Query('priority') priority?: string,
  ) {
    return this.supportService.getAllTickets(status, priority);
  }

  @Get('tickets/:id')
  getTicket(@Param('id') id: string, @CurrentUser() user: any) {
    return this.supportService.getTicket(id, user.userId);
  }

  // ─── Status (Admin/Agent) ──────────────────────────────────────────────────

  @Patch('tickets/:id/status')
  updateTicketStatus(
    @Param('id') id: string,
    @Body() body: { status: string; resolution?: string },
  ) {
    return this.supportService.updateTicketStatus(id, body.status, body.resolution);
  }

  // ─── Messages ──────────────────────────────────────────────────────────────

  @Post('tickets/:id/messages')
  addMessage(
    @Param('id') ticketId: string,
    @CurrentUser() user: any,
    @Body() body: { message: string; senderType?: 'customer' | 'agent' | 'system'; attachmentUrl?: string },
  ) {
    return this.supportService.addMessage(ticketId, user.userId, body);
  }

  @Get('tickets/:id/messages')
  getMessages(@Param('id') ticketId: string) {
    return this.supportService.getTicketMessages(ticketId);
  }

  // ─── FAQs ──────────────────────────────────────────────────────────────────

  @Get('faqs')
  getFaqs(@Query('category') category?: string) {
    return this.supportService.getFaqs(category);
  }
}
