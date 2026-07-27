import { Injectable, InternalServerErrorException } from '@nestjs/common';
import { GoogleGenerativeAI } from '@google/generative-ai';

@Injectable()
export class AiService {
  private genAI: GoogleGenerativeAI;

  constructor() {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      console.warn('GEMINI_API_KEY is not set. AI features will fail.');
    }
    this.genAI = new GoogleGenerativeAI(apiKey || 'dummy');
  }

  async parseMenuImage(base64Image: string): Promise<any[]> {
    try {
      const model = this.genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });
      
      const prompt = `You are a menu parsing assistant. 
Extract the food items, descriptions, and prices from this menu image. 
Return ONLY a valid JSON array of objects. Do not include markdown blocks like \`\`\`json.
Each object should have:
- "name" (string): the name of the food item
- "description" (string): brief description (if none, make one up that sounds delicious)
- "price" (number): just the numerical value of the price
- "categoryId" (string): infer a simple category like 'starters', 'mains', 'drinks', or 'desserts'

Example output:
[
  { "name": "Truffle Fries", "description": "Crispy fries tossed in truffle oil and parmesan", "price": 250, "categoryId": "starters" }
]`;

      const result = await model.generateContent([
        prompt,
        {
          inlineData: {
            data: base64Image,
            mimeType: 'image/jpeg',
          },
        },
      ]);
      
      let text = result.response.text();
      // Clean up markdown if the LLM still returns it
      text = text.replace(/```json/g, '').replace(/```/g, '').trim();
      
      const items = JSON.parse(text);
      
      // Generate image URLs using Pollinations.ai (free, keyless AI image generator)
      return items.map((item: any) => {
        const encodedPrompt = encodeURIComponent(`Delicious professional food photography of ${item.name}, restaurant lighting, highly detailed`);
        return {
          ...item,
          imageUrl: `https://image.pollinations.ai/prompt/${encodedPrompt}?width=512&height=512&nologo=true`,
        };
      });

    } catch (error) {
      console.error('AI Parsing Error:', error);
      throw new InternalServerErrorException('Failed to parse menu image');
    }
  }

  async parseOrderRequest(prompt: string, products: any[]): Promise<any[]> {
    try {
      const model = this.genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });

      const menuContext = products
        .map((p) => `ID:${p.id} | Name:"${p.name}" | Price:₹${p.price}`)
        .join('\n');

      const systemPrompt = `You are an AI ordering assistant for a food delivery app.
Here is the available menu:
${menuContext}

The customer said: "${prompt}"

Match their request to the closest menu items available. 
Return ONLY a valid JSON array. Do not include markdown or code blocks.
Each object must have:
- "productId" (string): the ID from the menu above
- "quantity" (number): how many they want (default 1 if unspecified)
- "productName" (string): the name of the matched item

If nothing matches, return an empty array [].`;

      const result = await model.generateContent(systemPrompt);
      let text = result.response.text();
      text = text.replace(/```json/g, '').replace(/```/g, '').trim();
      return JSON.parse(text);
    } catch (error) {
      console.error('AI Order Parsing Error:', error);
      throw new InternalServerErrorException('Failed to parse order request');
    }
  }

  async evaluateRefundRisk(context: {
    order: any;
    issueType: string;
    description: string;
    refundHistory: any[];
    totalOrders: number;
  }): Promise<{ decision: 'approve' | 'partial' | 'deny'; reason: string; refundAmount: number }> {
    try {
      const model = this.genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });

      const totalDisputes = context.refundHistory.length;
      const disputeRate = context.totalOrders > 0 ? (totalDisputes / context.totalOrders) * 100 : 0;
      const recentDisputes = context.refundHistory.filter((r: any) => {
        const date = new Date(r.createdAt);
        const thirtyDaysAgo = new Date();
        thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
        return date > thirtyDaysAgo;
      }).length;

      const systemPrompt = `You are a fair and empathetic refund dispute AI for a food delivery platform called QuickBite.

Order Details:
- Order Number: ${context.order.orderNumber}
- Total Amount: ₹${context.order.totalAmount}
- Items: ${context.order.items?.map((i: any) => `${i.quantity}x ${i.productName}`).join(', ')}

Issue Reported by Customer:
- Issue Type: ${context.issueType}
- Description: "${context.description}"

Customer's Refund History:
- Total Orders Placed: ${context.totalOrders}
- Total Past Disputes: ${totalDisputes}
- Disputes in Last 30 Days: ${recentDisputes}
- Dispute Rate: ${disputeRate.toFixed(1)}%

Make a fair refund decision using these rules:
- dispute_rate < 5% AND recentDisputes <= 1 → approve full refund
- dispute_rate 5-20% OR recentDisputes 2-3 → partial refund (50%) with explanation
- dispute_rate > 20% OR recentDisputes > 3 → deny, flag account

Return ONLY valid JSON (no markdown):
{
  "decision": "approve" | "partial" | "deny",
  "reason": "<a short, empathetic explanation for the customer in 2 sentences>",
  "refundAmount": <number: full amount if approve, half if partial, 0 if deny>
}`;

      const result = await model.generateContent(systemPrompt);
      let text = result.response.text();
      text = text.replace(/```json/g, '').replace(/```/g, '').trim();
      return JSON.parse(text);
    } catch (error) {
      console.error('AI Refund Error:', error);
      throw new InternalServerErrorException('Failed to evaluate refund');
    }
  }
}
