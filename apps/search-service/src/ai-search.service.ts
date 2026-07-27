import { Injectable, InternalServerErrorException } from '@nestjs/common';
import { GoogleGenerativeAI, SchemaType } from '@google/generative-ai';

@Injectable()
export class AiSearchService {
  private genAI: GoogleGenerativeAI;

  constructor() {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      console.warn('GEMINI_API_KEY is not set. AI search will fail.');
    }
    this.genAI = new GoogleGenerativeAI(apiKey || 'dummy');
  }

  async parseSearchIntent(query: string) {
    try {
      const model = this.genAI.getGenerativeModel({ 
        model: 'gemini-1.5-flash',
        generationConfig: {
          responseMimeType: 'application/json',
          responseSchema: {
            type: SchemaType.OBJECT,
            properties: {
              searchQuery: {
                type: SchemaType.STRING,
                description: 'The core food item or restaurant being searched for (e.g. "biryani", "pizza", "burger")',
              },
              foodType: {
                type: SchemaType.STRING,
                description: 'Must be one of: "veg", "non-veg", or "all". Default to "all" if unspecified.',
              },
              minPrice: {
                type: SchemaType.NUMBER,
                description: 'Minimum price mentioned, if any.',
              },
              maxPrice: {
                type: SchemaType.NUMBER,
                description: 'Maximum price or "under X" mentioned, if any.',
              }
            },
            required: ['searchQuery', 'foodType']
          }
        }
      });
      
      const prompt = `Parse the following food delivery search query and extract the user's intent. Query: "${query}"`;
      const result = await model.generateContent(prompt);
      const text = result.response.text();
      return JSON.parse(text);
    } catch (error) {
      console.error('AI Intent parsing failed:', error);
      throw new InternalServerErrorException('Failed to parse search query');
    }
  }
}
