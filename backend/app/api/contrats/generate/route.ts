import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { supabaseAdmin } from '@/lib/supabase';
import { verifySupabaseToken } from '@/lib/auth';
import { renderToBuffer } from '@react-pdf/renderer';
import { ContratLocationPDF } from '@/components/pdf/ContratLocationPDF';
import { ContratVentePDF } from '@/components/pdf/ContratVentePDF';
import { ContratEchangePDF } from '@/components/pdf/ContratEchangePDF';
import { createElement } from 'react';

export async function POST(req: NextRequest) {
  try {
    // 1. Authentification
    const userId = await verifySupabaseToken(req);
    if (!userId) {
      return NextResponse.json({ error: 'Non autorisé' }, { status: 401 });
    }

    const body = await req.json();
    const { type, referenceId } = body as { type: string; referenceId: string };

    if (!type || !referenceId) {
      return NextResponse.json({ error: 'type et referenceId sont requis' }, { status: 400 });
    }

    // 2. Récupérer les paramètres du showroom
    const showroom = await prisma.showroomSettings.findFirst();

    // 3. Générer le PDF selon le type
    let pdfBytes: Uint8Array;
    let fileName: string;
    let folder: string;

    if (type === 'location') {
      const loc = await prisma.location.findUnique({
        where: { id: referenceId },
        include: { vehicule: true, client: true },
      });
      if (!loc) return NextResponse.json({ error: 'Location introuvable' }, { status: 404 });

      pdfBytes = await renderToBuffer(
        createElement(ContratLocationPDF, { location: loc as any, showroom })
      );
      fileName = `location-${referenceId.slice(0, 8)}-${Date.now()}.pdf`;
      folder   = 'locations';

      // Mettre à jour l'URL dans la DB
      const url = await _uploadAndGetUrl(pdfBytes, folder, fileName);
      await prisma.location.update({
        where: { id: referenceId },
        data:  { contratPdfUrl: url },
      });
      return NextResponse.json({ url });

    } else if (type === 'vente') {
      const vente = await prisma.vente.findUnique({
        where: { id: referenceId },
        include: { vehicule: true, client: true },
      });
      if (!vente) return NextResponse.json({ error: 'Vente introuvable' }, { status: 404 });

      pdfBytes = await renderToBuffer(
        createElement(ContratVentePDF, { vente: vente as any, showroom })
      );
      fileName = `vente-${referenceId.slice(0, 8)}-${Date.now()}.pdf`;
      folder   = 'ventes';

      const url = await _uploadAndGetUrl(pdfBytes, folder, fileName);
      await prisma.vente.update({
        where: { id: referenceId },
        data:  { contratPdfUrl: url },
      });
      return NextResponse.json({ url });

    } else if (type === 'echange') {
      const echange = await prisma.echange.findUnique({
        where: { id: referenceId },
        include: { vehiculeCede: true, client: true },
      });
      if (!echange) return NextResponse.json({ error: 'Échange introuvable' }, { status: 404 });

      pdfBytes = await renderToBuffer(
        createElement(ContratEchangePDF, { echange: echange as any, showroom })
      );
      fileName = `echange-${referenceId.slice(0, 8)}-${Date.now()}.pdf`;
      folder   = 'echanges';

      const url = await _uploadAndGetUrl(pdfBytes, folder, fileName);
      return NextResponse.json({ url });

    } else {
      return NextResponse.json({ error: `Type inconnu: ${type}` }, { status: 400 });
    }

  } catch (err: any) {
    console.error('[POST /api/contrats/generate]', err);
    return NextResponse.json({ error: err.message ?? 'Erreur serveur' }, { status: 500 });
  }
}

async function _uploadAndGetUrl(bytes: Uint8Array, folder: string, fileName: string): Promise<string> {
  const path = `${folder}/${fileName}`;
  const { error } = await supabaseAdmin.storage
    .from('contrats')
    .upload(path, bytes, { contentType: 'application/pdf', upsert: true });
  if (error) throw new Error(`Upload Supabase: ${error.message}`);
  const { data } = supabaseAdmin.storage.from('contrats').getPublicUrl(path);
  return data.publicUrl;
}
