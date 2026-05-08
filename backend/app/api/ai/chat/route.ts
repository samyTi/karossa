import { NextRequest, NextResponse } from 'next/server';
import { GoogleGenerativeAI } from '@google/generative-ai';
import { verifySupabaseToken } from '@/lib/auth';
import { prisma } from '@/lib/prisma';

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY ?? '');

function buildSystemPrompt(showroomNom: string): string {
  return `Tu es KarossaAI, l'assistant intelligent du showroom automobile "${showroomNom}" (Algérie).
Tu aides les gérants et propriétaires à gérer leur flotte, analyser les performances et prendre de meilleures décisions.

RÈGLES ABSOLUES:
- Réponds TOUJOURS en français
- Sois concis, professionnel et pratique
- Les montants sont en Dinars Algériens (DA)
- Si on te demande des calculs financiers, montre le détail étape par étape
- N'invente jamais de données non fournies
- Pour les alertes mécaniques, recommande de consulter un mécanicien professionnel
- Tu peux analyser des données de véhicules, locations, ventes et réparations
`;
}

export async function POST(req: NextRequest) {
  try {
    // Auth
    const userId = await verifySupabaseToken(req);
    if (!userId) {
      return NextResponse.json({ error: 'Non autorisé' }, { status: 401 });
    }

    const body = await req.json();
    const { message, history = [], vehiculeContext, showroomContext } = body as {
      message:         string;
      history:         Array<{ role: string; content: string }>;
      vehiculeContext?: Record<string, unknown>;
      showroomContext?: Record<string, unknown>;
    };

    if (!message?.trim()) {
      return NextResponse.json({ error: 'Message vide' }, { status: 400 });
    }

    // Récupérer le nom du showroom
    const settings = await prisma.showroomSettings.findFirst().catch(() => null);
    const showroomNom = (settings?.nom) ?? 'Garage Auto';

    const model = genAI.getGenerativeModel({
      model: 'gemini-1.5-flash',
      systemInstruction: buildSystemPrompt(showroomNom),
    });

    // Enrichir le message avec le contexte véhicule si fourni
    let enrichedMessage = message;
    if (vehiculeContext) {
      enrichedMessage = `[CONTEXTE VÉHICULE]
Véhicule: ${vehiculeContext.marque} ${vehiculeContext.modele} ${vehiculeContext.annee}
Kilométrage: ${vehiculeContext.kilometrage} km
Statut: ${vehiculeContext.statut}
${vehiculeContext.prixVente ? 'Prix vente: ' + vehiculeContext.prixVente + ' DA' : ''}
${vehiculeContext.prixLocationJour ? 'Prix location/jour: ' + vehiculeContext.prixLocationJour + ' DA' : ''}
[FIN CONTEXTE]

${message}`;
    }

    // Convertir l'historique
    const geminiHistory = history
      .filter((m) => m.content?.trim())
      .map((m) => ({
        role:  m.role === 'user' ? 'user' : 'model',
        parts: [{ text: m.content }],
      }));

    const chat    = model.startChat({ history: geminiHistory });
    const result  = await chat.sendMessage(enrichedMessage);
    const text    = result.response.text();

    return NextResponse.json({ reply: text });
  } catch (err: any) {
    console.error('[POST /api/ai/chat]', err);
    return NextResponse.json({ error: err.message ?? 'Erreur IA' }, { status: 500 });
  }
}
