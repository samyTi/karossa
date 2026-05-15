import 'dart:typed_data';

class ContratModel {
  final String id;
  final String type; // vente / location / echange
  final String clientNom;
  final String vehicule;
  final double prix;
  final Uint8List? pdfData;

  ContratModel({
    required this.id,
    required this.type,
    required this.clientNom,
    required this.vehicule,
    required this.prix,
    this.pdfData,
  });
}