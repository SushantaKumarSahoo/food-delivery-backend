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
    const apiKey = process.env.GEMINI_API_KEY;
    
    // If we have an API key, try using Gemini
    if (apiKey && apiKey !== 'dummy') {
      try {
        const model = this.genAI.getGenerativeModel({ 
          model: 'gemini-3.6-flash',
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
        console.error('AI Intent parsing failed, falling back to local NLP:', error);
      }
    }

    // Local NLP Fallback Implementation
    const intent: any = {
      searchQuery: query,
      foodType: 'all',
    };
    
    const lowerQ = query.toLowerCase();
    
    // Detect Food Type
    if (lowerQ.includes('non veg') || lowerQ.includes('non-veg') || lowerQ.includes('chicken') || lowerQ.includes('mutton') || lowerQ.includes('meat') || lowerQ.includes('fish')) {
      intent.foodType = 'non-veg';
    } else if (lowerQ.includes('veg') || lowerQ.includes('vegetarian') || lowerQ.includes('paneer') || lowerQ.includes('vegan')) {
      intent.foodType = 'veg';
    }

    // Detect Max Price (e.g., "under 200", "less than 150", "below 300")
    const maxPriceMatch = lowerQ.match(/(?:under|less than|below)\s*(?:rs|rupees|₹)?\s*(\d+)/);
    if (maxPriceMatch) {
      intent.maxPrice = parseInt(maxPriceMatch[1], 10);
    }

    // Clean query
    let cleanQuery = lowerQ
      .replace(/(?:under|less than|below)\s*(?:rs|rupees|₹)?\s*\d+/gi, '')
      .replace(/non[\s-]?veg|veg(etarian)?|chicken|mutton|meat|fish|paneer/gi, '')
      .replace(/cheap(est)?|best|top|healthy|spicy/gi, '')
      .trim()
      .replace(/\s+/g, ' '); // remove extra spaces
      
    if (cleanQuery.length > 2) {
      intent.searchQuery = cleanQuery;
    }

    return intent;
  }
}
