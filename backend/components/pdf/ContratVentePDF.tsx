import React from 'react';
import { Document, Page, Text, View, StyleSheet } from '@react-pdf/renderer';

const PRIMARY = '#1a6ed8';
const styles = StyleSheet.create({
  page:   { padding: 40, fontFamily: 'Helvetica', fontSize: 10, color: '#222' },
  header: { flexDirection: 'row', justifyContent: 'space-between', marginBottom: 20 },
  companyName: { fontSize: 18, fontWeight: 'bold', color: PRIMARY },
  title:  { fontSize: 14, fontWeight: 'bold', color: PRIMARY, textAlign: 'right' },
  divider:{ borderBottomWidth: 1.5, borderBottomColor: PRIMARY, marginBottom: 16 },
  section:{ marginBottom: 14 },
  sectionTitle: { fontSize: 11, fontWeight: 'bold', color: PRIMARY, marginBottom: 6, textTransform: 'uppercase' },
  row:    { flexDirection: 'row', marginBottom: 3 },
  label:  { width: 180, color: '#666' },
  value:  { flex: 1, fontWeight: 'bold' },
  totalBox: { backgroundColor: '#f0f4ff', padding: 12, borderRadius: 4, marginTop: 16 },
  sigBox: { flexDirection: 'row', justifyContent: 'space-between', marginTop: 30 },
  sigCol: { width: '45%', borderTopWidth: 1, borderTopColor: '#aaa', paddingTop: 6 },
  footer: { position: 'absolute', bottom: 30, left: 40, right: 40, fontSize: 8, color: '#999', borderTopWidth: 1, borderTopColor: '#ddd', paddingTop: 6 },
});

interface Props { vente: any; showroom: any; }

export function ContratVentePDF({ vente, showroom: sh }: Props) {
  const sh_ = sh ?? {};
  const contratNum = vente.id.slice(0, 8).toUpperCase();
  const marge = vente.prixVente - (vente.vehicule?.prixAchat ?? 0);

  return (
    <Document title={`Bon de Vente N°${contratNum}`}>
      <Page size="A4" style={styles.page}>
        <View style={styles.header}>
          <View>
            <Text style={styles.companyName}>{sh_.nom ?? 'Garage Auto'}</Text>
            {sh_.adresse && <Text>{sh_.adresse}</Text>}
            {sh_.tel && <Text>Tél : {sh_.tel}</Text>}
            {sh_.rc && <Text>RC : {sh_.rc}</Text>}
          </View>
          <View>
            <Text style={styles.title}>BON DE VENTE</Text>
            <Text style={{ textAlign: 'right' }}>N° {contratNum}</Text>
            <Text style={{ textAlign: 'right', color: '#666' }}>{new Date(vente.dateVente).toLocaleDateString('fr-DZ')}</Text>
          </View>
        </View>
        <View style={styles.divider} />

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Acheteur</Text>
          <View style={styles.row}><Text style={styles.label}>Nom & Prénom :</Text><Text style={styles.value}>{vente.client?.prenom} {vente.client?.nom}</Text></View>
          <View style={styles.row}><Text style={styles.label}>Téléphone :</Text><Text style={styles.value}>{vente.client?.telephone}</Text></View>
          {vente.client?.numCni && <View style={styles.row}><Text style={styles.label}>N° CNI :</Text><Text style={styles.value}>{vente.client.numCni}</Text></View>}
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Véhicule vendu</Text>
          <View style={styles.row}><Text style={styles.label}>Désignation :</Text><Text style={styles.value}>{vente.vehicule?.marque} {vente.vehicule?.modele} {vente.vehicule?.annee}</Text></View>
          {vente.vehicule?.immatriculation && <View style={styles.row}><Text style={styles.label}>Immatriculation :</Text><Text style={styles.value}>{vente.vehicule.immatriculation}</Text></View>}
          {vente.vehicule?.numChassis && <View style={styles.row}><Text style={styles.label}>N° Châssis :</Text><Text style={styles.value}>{vente.vehicule.numChassis}</Text></View>}
          <View style={styles.row}><Text style={styles.label}>Kilométrage :</Text><Text style={styles.value}>{vente.vehicule?.kilometrage?.toLocaleString('fr')} km</Text></View>
        </View>

        <View style={styles.totalBox}>
          <View style={styles.row}><Text style={styles.label}>Prix de vente :</Text><Text style={[styles.value, { fontSize: 13 }]}>{Number(vente.prixVente).toLocaleString('fr')} DA</Text></View>
          <View style={styles.row}><Text style={styles.label}>Acompte versé :</Text><Text style={styles.value}>{Number(vente.acompte ?? 0).toLocaleString('fr')} DA</Text></View>
          <View style={styles.row}><Text style={styles.label}>Solde restant :</Text><Text style={styles.value}>{Number(vente.soldeRestant ?? 0).toLocaleString('fr')} DA</Text></View>
          <View style={styles.row}><Text style={styles.label}>Mode de paiement :</Text><Text style={styles.value}>{vente.modePaiement ?? '-'}</Text></View>
        </View>

        {vente.notes && <View style={[styles.section, { marginTop: 12 }]}>
          <Text style={styles.sectionTitle}>Notes</Text>
          <Text>{vente.notes}</Text>
        </View>}

        <View style={styles.sigBox}>
          <View style={styles.sigCol}><Text style={{ fontWeight: 'bold' }}>Le Vendeur</Text><Text style={{ color: '#888', marginTop: 4 }}>{sh_.nom}</Text></View>
          <View style={styles.sigCol}><Text style={{ fontWeight: 'bold' }}>L'Acheteur</Text><Text style={{ color: '#888', marginTop: 4 }}>{vente.client?.prenom} {vente.client?.nom}</Text></View>
        </View>

        <Text style={styles.footer} render={({ pageNumber, totalPages }) =>
          `${sh_.nom ?? 'Garage Auto'} — Bon de Vente N°${contratNum} — Page ${pageNumber}/${totalPages}`
        } fixed />
      </Page>
    </Document>
  );
}
