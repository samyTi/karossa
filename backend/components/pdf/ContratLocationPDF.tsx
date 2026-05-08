import React from 'react';
import { Document, Page, Text, View, StyleSheet, Font } from '@react-pdf/renderer';

Font.register({
  family: 'Helvetica',
  fonts: [{ src: 'Helvetica' }, { src: 'Helvetica-Bold', fontWeight: 'bold' }],
});

const PRIMARY = '#1a6ed8';

const styles = StyleSheet.create({
  page:      { padding: 40, fontFamily: 'Helvetica', fontSize: 10, color: '#222' },
  header:    { flexDirection: 'row', justifyContent: 'space-between', marginBottom: 20 },
  companyName: { fontSize: 18, fontWeight: 'bold', color: PRIMARY },
  title:     { fontSize: 14, fontWeight: 'bold', color: PRIMARY, textAlign: 'right' },
  divider:   { borderBottomWidth: 1.5, borderBottomColor: PRIMARY, marginBottom: 16 },
  section:   { marginBottom: 14 },
  sectionTitle: { fontSize: 11, fontWeight: 'bold', color: PRIMARY, marginBottom: 6, textTransform: 'uppercase' },
  row:       { flexDirection: 'row', marginBottom: 3 },
  label:     { width: 180, color: '#666' },
  value:     { flex: 1, fontWeight: 'bold' },
  totalBox:  { backgroundColor: '#f0f4ff', padding: 10, borderRadius: 4, marginTop: 16 },
  totalLabel:{ fontSize: 12, fontWeight: 'bold', color: PRIMARY },
  footer:    { position: 'absolute', bottom: 30, left: 40, right: 40, borderTopWidth: 1,
               borderTopColor: '#ddd', paddingTop: 8, fontSize: 8, color: '#999' },
  sigBox:    { flexDirection: 'row', justifyContent: 'space-between', marginTop: 30 },
  sigColumn: { width: '45%', borderTopWidth: 1, borderTopColor: '#aaa', paddingTop: 6 },
});

interface Props { location: any; showroom: any; }

export function ContratLocationPDF({ location: loc, showroom: sh }: Props) {
  const sh_ = sh ?? {};
  const dateDebut   = new Date(loc.dateDebut).toLocaleDateString('fr-DZ');
  const dateFin     = new Date(loc.dateFinPrevue).toLocaleDateString('fr-DZ');
  const nbJours     = loc.nbJours ?? Math.ceil((new Date(loc.dateFinPrevue).getTime() - new Date(loc.dateDebut).getTime()) / 86_400_000);
  const montant     = (loc.prixJour * nbJours).toLocaleString('fr-DZ');
  const contratNum  = loc.id.slice(0, 8).toUpperCase();

  return (
    <Document title={`Contrat Location N°${contratNum}`}>
      <Page size="A4" style={styles.page}>
        {/* En-tête */}
        <View style={styles.header}>
          <View>
            <Text style={styles.companyName}>{sh_.nom ?? 'Garage Auto'}</Text>
            {sh_.adresse && <Text>{sh_.adresse}</Text>}
            {sh_.tel && <Text>Tél : {sh_.tel}</Text>}
            {sh_.email && <Text>{sh_.email}</Text>}
            {sh_.rc && <Text>RC : {sh_.rc}</Text>}
          </View>
          <View>
            <Text style={styles.title}>CONTRAT DE LOCATION</Text>
            <Text style={{ textAlign: 'right' }}>N° {contratNum}</Text>
            <Text style={{ textAlign: 'right', color: '#666' }}>{new Date().toLocaleDateString('fr-DZ')}</Text>
          </View>
        </View>
        <View style={styles.divider} />

        {/* Client */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Locataire</Text>
          <View style={styles.row}><Text style={styles.label}>Nom & Prénom :</Text><Text style={styles.value}>{loc.client?.prenom} {loc.client?.nom}</Text></View>
          <View style={styles.row}><Text style={styles.label}>Téléphone :</Text><Text style={styles.value}>{loc.client?.telephone}</Text></View>
          {loc.client?.email && <View style={styles.row}><Text style={styles.label}>Email :</Text><Text style={styles.value}>{loc.client.email}</Text></View>}
          {loc.client?.numCni && <View style={styles.row}><Text style={styles.label}>N° CNI :</Text><Text style={styles.value}>{loc.client.numCni}</Text></View>}
          {loc.client?.numPermis && <View style={styles.row}><Text style={styles.label}>N° Permis :</Text><Text style={styles.value}>{loc.client.numPermis}</Text></View>}
        </View>

        {/* Véhicule */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Véhicule</Text>
          <View style={styles.row}><Text style={styles.label}>Marque / Modèle :</Text><Text style={styles.value}>{loc.vehicule?.marque} {loc.vehicule?.modele} {loc.vehicule?.annee}</Text></View>
          {loc.vehicule?.immatriculation && <View style={styles.row}><Text style={styles.label}>Immatriculation :</Text><Text style={styles.value}>{loc.vehicule.immatriculation}</Text></View>}
          <View style={styles.row}><Text style={styles.label}>Kilométrage départ :</Text><Text style={styles.value}>{loc.kmDepart?.toLocaleString('fr')} km</Text></View>
        </View>

        {/* Conditions */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Conditions de location</Text>
          <View style={styles.row}><Text style={styles.label}>Date de départ :</Text><Text style={styles.value}>{dateDebut}</Text></View>
          <View style={styles.row}><Text style={styles.label}>Date de retour prévue :</Text><Text style={styles.value}>{dateFin}</Text></View>
          <View style={styles.row}><Text style={styles.label}>Durée :</Text><Text style={styles.value}>{nbJours} jour(s)</Text></View>
          <View style={styles.row}><Text style={styles.label}>Prix / jour :</Text><Text style={styles.value}>{Number(loc.prixJour).toLocaleString('fr')} DA</Text></View>
          <View style={styles.row}><Text style={styles.label}>Caution :</Text><Text style={styles.value}>{Number(loc.caution).toLocaleString('fr')} DA</Text></View>
        </View>

        {/* Total */}
        <View style={styles.totalBox}>
          <Text style={styles.totalLabel}>Montant total : {montant} DA</Text>
          <Text style={{ color: '#666', marginTop: 2 }}>Caution : {Number(loc.caution).toLocaleString('fr')} DA (remboursable au retour)</Text>
        </View>

        {/* Notes */}
        {loc.notesDepart && (
          <View style={[styles.section, { marginTop: 12 }]}>
            <Text style={styles.sectionTitle}>Observations</Text>
            <Text>{loc.notesDepart}</Text>
          </View>
        )}

        {/* Signatures */}
        <View style={styles.sigBox}>
          <View style={styles.sigColumn}>
            <Text style={{ fontWeight: 'bold' }}>Le Loueur</Text>
            <Text style={{ color: '#888', marginTop: 4 }}>{sh_.nom}</Text>
          </View>
          <View style={styles.sigColumn}>
            <Text style={{ fontWeight: 'bold' }}>Le Locataire</Text>
            <Text style={{ color: '#888', marginTop: 4 }}>{loc.client?.prenom} {loc.client?.nom}</Text>
          </View>
        </View>

        {/* Footer */}
        <Text style={styles.footer} render={({ pageNumber, totalPages }) =>
          `${sh_.nom ?? 'Garage Auto'} — Contrat N°${contratNum} — Page ${pageNumber}/${totalPages}`
        } fixed />
      </Page>
    </Document>
  );
}
