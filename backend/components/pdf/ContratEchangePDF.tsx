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
  sectionTitle: { fontSize: 11, fontWeight: 'bold', color: PRIMARY, marginBottom: 6 },
  row:    { flexDirection: 'row', marginBottom: 3 },
  label:  { width: 180, color: '#666' },
  value:  { flex: 1, fontWeight: 'bold' },
  totalBox: { backgroundColor: '#f0f4ff', padding: 12, borderRadius: 4, marginTop: 16 },
  sigBox: { flexDirection: 'row', justifyContent: 'space-between', marginTop: 30 },
  sigCol: { width: '45%', borderTopWidth: 1, borderTopColor: '#aaa', paddingTop: 6 },
  footer: { position: 'absolute', bottom: 30, left: 40, right: 40, fontSize: 8, color: '#999', borderTopWidth: 1, borderTopColor: '#ddd', paddingTop: 6 },
});

interface Props { echange: any; showroom: any; }

export function ContratEchangePDF({ echange, showroom: sh }: Props) {
  const sh_ = sh ?? {};
  const contratNum = echange.id.slice(0, 8).toUpperCase();

  return (
    <Document title={`Contrat Échange N°${contratNum}`}>
      <Page size="A4" style={styles.page}>
        <View style={styles.header}>
          <View>
            <Text style={styles.companyName}>{sh_.nom ?? 'Garage Auto'}</Text>
            {sh_.tel && <Text>Tél : {sh_.tel}</Text>}
          </View>
          <View>
            <Text style={styles.title}>CONTRAT D'ÉCHANGE</Text>
            <Text style={{ textAlign: 'right' }}>N° {contratNum}</Text>
            <Text style={{ textAlign: 'right', color: '#666' }}>{new Date(echange.dateEchange).toLocaleDateString('fr-DZ')}</Text>
          </View>
        </View>
        <View style={styles.divider} />

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Client</Text>
          <View style={styles.row}><Text style={styles.label}>Nom & Prénom :</Text><Text style={styles.value}>{echange.client?.prenom} {echange.client?.nom}</Text></View>
          <View style={styles.row}><Text style={styles.label}>Téléphone :</Text><Text style={styles.value}>{echange.client?.telephone}</Text></View>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Véhicule Cédé (par le Showroom)</Text>
          <View style={styles.row}><Text style={styles.label}>Désignation :</Text><Text style={styles.value}>{echange.vehiculeCede?.marque} {echange.vehiculeCede?.modele} {echange.vehiculeCede?.annee}</Text></View>
          {echange.vehiculeCede?.immatriculation && <View style={styles.row}><Text style={styles.label}>Immatriculation :</Text><Text style={styles.value}>{echange.vehiculeCede.immatriculation}</Text></View>}
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Véhicule Repris (apporté par le Client)</Text>
          <View style={styles.row}><Text style={styles.label}>Désignation :</Text><Text style={styles.value}>{echange.vehiculeRepriseMarque} {echange.vehiculeRepriseModele} {echange.vehiculeRepriseAnnee}</Text></View>
          {echange.vehiculeRepriseImmat && <View style={styles.row}><Text style={styles.label}>Immatriculation :</Text><Text style={styles.value}>{echange.vehiculeRepriseImmat}</Text></View>}
          <View style={styles.row}><Text style={styles.label}>Kilométrage :</Text><Text style={styles.value}>{(echange.vehiculeRepriseKm ?? 0).toLocaleString('fr')} km</Text></View>
        </View>

        <View style={styles.totalBox}>
          <View style={styles.row}><Text style={styles.label}>Valeur reprise :</Text><Text style={styles.value}>{Number(echange.valeurReprise).toLocaleString('fr')} DA</Text></View>
          <View style={styles.row}><Text style={styles.label}>Complément client :</Text><Text style={styles.value}>{Number(echange.complementClient ?? 0).toLocaleString('fr')} DA</Text></View>
        </View>

        <View style={styles.sigBox}>
          <View style={styles.sigCol}><Text style={{ fontWeight: 'bold' }}>Le Showroom</Text><Text style={{ color: '#888', marginTop: 4 }}>{sh_.nom}</Text></View>
          <View style={styles.sigCol}><Text style={{ fontWeight: 'bold' }}>Le Client</Text><Text style={{ color: '#888', marginTop: 4 }}>{echange.client?.prenom} {echange.client?.nom}</Text></View>
        </View>

        <Text style={styles.footer} render={({ pageNumber, totalPages }) =>
          `${sh_.nom ?? 'Garage Auto'} — Échange N°${contratNum} — Page ${pageNumber}/${totalPages}`
        } fixed />
      </Page>
    </Document>
  );
}
