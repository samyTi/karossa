//lib/features/vehicules/presentation/vehicule_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/carte_grise_ocr_service.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/services/notification_service.dart';
import '../../auth/domain/profile_model.dart';
import 'vehicules_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'package:garage_auto/core/extensions/l10n_extension.dart';

class VehiculeFormScreen extends ConsumerStatefulWidget {
  final String? vehiculeId;
  const VehiculeFormScreen({super.key, this.vehiculeId});
  @override
  ConsumerState<VehiculeFormScreen> createState() => _VehiculeFormState();
}

class _VehiculeFormState extends ConsumerState<VehiculeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading  = false;
  bool _uploading = false;

  final _marqueCtrl  = TextEditingController();
  final _modeleCtrl  = TextEditingController();
  final _anneeCtrl   = TextEditingController();
  final _couleurCtrl = TextEditingController();
  final _immatCtrl   = TextEditingController();
  final _chassisCtrl = TextEditingController();
  final _assuranceCtrl = TextEditingController();
  final _codeRadioCtrl = TextEditingController();
  final _kmCtrl      = TextEditingController(text: '0');
  final _prixVenteCtrl  = TextEditingController();
  final _prixLocCtrl    = TextEditingController();
  final _notesCtrl      = TextEditingController();
  final _etatVehiculeCtrl = TextEditingController();
  final _flespiDeviceIdCtrl = TextEditingController();

  String _carburant = 'essence';
  String _boite     = 'manuelle';
  String _statut    = 'disponible';

  // Contient l'ensemble des URLs issues de Supabase Storage (Upload direct et immédiat)
  final List<String> _photosUrls = [];

  // Propriétaires : {profileId -> pourcentage}
  final Map<String, double> _proprietes = {};
  final Map<String, String> _typeParticipation = {}; // 'proprietaire' | 'associe'
  List<Profile> _allProfiles = [];

  @override
  void initState() {
    super.initState();
    _loadProfiles();
    if (widget.vehiculeId != null) {
      _loadVehicule();
    }
  }

  @override
  void dispose() {
    _marqueCtrl.dispose();
    _modeleCtrl.dispose();
    _anneeCtrl.dispose();
    _couleurCtrl.dispose();
    _immatCtrl.dispose();
    _chassisCtrl.dispose();
    _assuranceCtrl.dispose();
    _codeRadioCtrl.dispose();
    _kmCtrl.dispose();
    _prixVenteCtrl.dispose();
    _prixLocCtrl.dispose();
    _notesCtrl.dispose();
    _etatVehiculeCtrl.dispose();
    _flespiDeviceIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    final data = await ref.read(supabaseClientProvider).from('profiles').select();
    setState(() {
      _allProfiles = data.map((j) => Profile.fromJson(j)).toList();
    });
  }

  Future<void> _loadVehicule() async {
    if (widget.vehiculeId == null) return;
    
    final data = await ref.read(supabaseClientProvider)
        .from('vehicules')
        .select()
        .eq('id', widget.vehiculeId!)
        .single();
    
    setState(() {
      _marqueCtrl.text = data['marque'] ?? '';
      _modeleCtrl.text = data['modele'] ?? '';
      _anneeCtrl.text = (data['annee'] ?? '').toString();
      _couleurCtrl.text = data['couleur'] ?? '';
      _immatCtrl.text = data['immatriculation'] ?? '';
      _chassisCtrl.text = data['num_chassis'] ?? '';
      _assuranceCtrl.text = data['assurance'] ?? '';
      _codeRadioCtrl.text = data['code_radio'] ?? '';
      _kmCtrl.text = (data['kilometrage'] ?? 0).toString();
      _prixVenteCtrl.text = (data['prix_vente'] ?? '').toString();
      _prixLocCtrl.text = (data['prix_location_jour'] ?? '').toString();
      _notesCtrl.text = data['notes'] ?? '';
      _etatVehiculeCtrl.text = data['etat_vehicule'] ?? '';
      _carburant = data['carburant'] ?? 'essence';
      _boite = data['boite'] ?? 'manuelle';
      _statut = data['statut'] ?? 'disponible';
      
      final flespiId = data['flespi_device_id'];
      _flespiDeviceIdCtrl.text = flespiId != null ? flespiId.toString() : '';
      
      final photos = data['photos'] as List<dynamic>?;
      if (photos != null) {
        _photosUrls.addAll(photos.map((p) => p.toString()));
      }
    });
    
    final proprietesData = await ref.read(supabaseClientProvider)
        .from('vehicule_proprietes')
        .select()
        .eq('vehicule_id', widget.vehiculeId!);
    
    setState(() {
      for (final prop in proprietesData) {
        _proprietes[prop['proprietaire_id']] = (prop['part_pct'] as num).toDouble();
        _typeParticipation[prop['proprietaire_id']] =
            (prop['type_participation'] as String?) ?? 'proprietaire';
      }
    });
  }

  double get _totalParts => _proprietes.values.fold(0.0, (s, v) => s + v);

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.vehiculeId != null;
    return Scaffold(
      appBar: CustomAppBar(
        title: isEdit ? 'Modifier vehicule' : 'Nouveau vehicule',
        showHomeButton: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Photos Section (Cloud avec CachedNetworkImage) ─────────────────
            const _SectionTitle('Photos'),
            SizedBox(
              height: 110,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ..._photosUrls.map((u) => _PhotoThumb(
                    child: CachedNetworkImage(
                      imageUrl: u,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      errorWidget: (context, url, error) => Icon(Icons.broken_image, color: Colors.red),
                    ),
                    onDelete: () => setState(() => _photosUrls.remove(u)),
                  )),
                  _AddPhotoBtn(
                    uploading: _uploading,
                    onTap: _pickPhoto,
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),

            // ── Infos générales ───────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _SectionTitle('Informations generales'),
                TextButton.icon(
                  icon: Icon(Icons.document_scanner, size: 18),
                  label: Text(context.l10n.scannerCarteGrise),
                  onPressed: _scanCarteGrise,
                ),
              ],
            ),
            Row(children: [
              Expanded(child: _Field(
                ctrl: _marqueCtrl, label: 'Marque',
                required: true)),
              SizedBox(width: 10),
              Expanded(child: _Field(
                ctrl: _modeleCtrl, label: 'Modele',
                required: true)),
            ]),
            SizedBox(height: 10),
            Row(children: [
              Expanded(child: _Field(
                ctrl: _anneeCtrl, label: 'Annee',
                type: TextInputType.number, required: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requis';
                  final y = int.tryParse(v);
                  if (y == null || y < 1950 || y > 2030) {
                    return context.l10n.anneeInvalideSimple;
                  }
                  return null;
                })),
              SizedBox(width: 10),
              Expanded(child: _Field(
                ctrl: _couleurCtrl, label: 'Couleur')),
            ]),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _Field(
                    ctrl: _immatCtrl,
                    label: context.l10n.immatriculation,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _Field(
                    ctrl: _chassisCtrl,
                    label: context.l10n.nChassis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            // ── Assurance / Code radio — utilisés sur le contrat de location ──
            Row(
              children: [
                Expanded(
                  child: _Field(
                    ctrl: _assuranceCtrl,
                    label: 'Assurance',
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _Field(
                    ctrl: _codeRadioCtrl,
                    label: 'Code radio',
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            _Field(
              ctrl: _flespiDeviceIdCtrl,
              label: context.l10n.flespiDeviceIdGps,
              type: TextInputType.number,
              validator: (v) {
                if (v != null && v.isNotEmpty && int.tryParse(v) == null) {
                  return context.l10n.idInvalide;
                }
                return null;
              },
            ),
            SizedBox(height: 10),
            _Field(
              ctrl: _kmCtrl, label: 'Kilometrage',
              type: TextInputType.number,
              suffix: 'km', required: true),
            SizedBox(height: 10),
            Row(children: [
              Expanded(child: _Dropdown(
                label: 'Carburant',
                value: _carburant,
                items: const {
                  'essence':    'Essence',
                  'diesel':     'Diesel',
                  'electrique': 'Electrique',
                  'hybride':    'Hybride',
                },
                onChanged: (v) => setState(() => _carburant = v!),
              )),
              SizedBox(width: 10),
              Expanded(child: _Dropdown(
                label: 'Boite',
                value: _boite,
                items: const {
                  'manuelle':    'Manuelle',
                  'automatique': 'Automatique',
                },
                onChanged: (v) => setState(() => _boite = v!),
              )),
            ]),
            SizedBox(height: 20),

            // ── Prix ─────────────────────────────────────────
            const _SectionTitle('Prix'),
            Row(children: [
              Expanded(child: _Field(
                ctrl: _prixLocCtrl,
                label: context.l10n.prixLocationJour,
                type: TextInputType.number,
                suffix: 'DA')),
              SizedBox(width: 10),
              Expanded(child: _Field(
                ctrl: _prixVenteCtrl,
                label: context.l10n.champPrixVente,
                type: TextInputType.number,
                suffix: 'DA')),
            ]),
            SizedBox(height: 20),

            // ── Statut ────────────────────────────────────────
            const _SectionTitle('Statut initial'),
            _Dropdown(
              label: context.l10n.champStatut,
              value: _statut,
              items: const {
                'disponible':   'Disponible',
                'reserve':      'Reserve',
                'reparation':   'En reparation',
                'loue':         'Loué',
                'vendu':        'Vendu',
                'maintenance':  'Maintenance',
              },
              onChanged: (v) => setState(() => _statut = v!),
            ),
            SizedBox(height: 20),

            // ── Propriétaires ────────────────────────────────
            const _SectionTitle('Proprietaire(s) et parts (%)'),
            if (_allProfiles.isEmpty)
              Center(child: CircularProgressIndicator())
            else
              ..._allProfiles
                .where((p) => p.role != UserRole.gerant)
                .map((p) => _ProprieteRow(
                  profile: p,
                  value: _proprietes[p.id],
                  typeParticipation: _typeParticipation[p.id] ?? 'proprietaire',
                  onChanged: (v) => setState(() {
                    if (v == null || v == 0) {
                      _proprietes.remove(p.id);
                      _typeParticipation.remove(p.id);
                    } else {
                      _proprietes[p.id] = v;
                      _typeParticipation.putIfAbsent(p.id, () => 'proprietaire');
                    }
                  }),
                  onTypeChanged: (t) => setState(() {
                    _typeParticipation[p.id] = t;
                  }),
                )),
            SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(context.l10n.totalPourcent(_totalParts.toInt().toString()),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _totalParts == 100
                      ? AppColors.secondary
                      : AppColors.retard,
                  )),
              ],
            ),
            if (_totalParts > 0 && _totalParts.round() != 100)
              Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(context.l10n.laSommeDesPartsDoitEtre, style: TextStyle(
                    color: AppColors.retard, fontSize: 12)),
              ),
            SizedBox(height: 20),

            // ── État du véhicule ────────────────────────────────
            const _SectionTitle('État du véhicule'),
            Text(
              'Décrivez tout ce qui ne fonctionne pas ou est endommagé (pannes, rayures, bosses…). '
              'Ces informations seront intégrées au contrat de location.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            SizedBox(height: 8),
            TextFormField(
              controller: _etatVehiculeCtrl,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: context.l10n.dommagesPannesAnomaliesOptionnel,
                hintText: context.l10n.exRayureSurAileAvantGauche,
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),

            // ── Notes internes ─────────────────────────────────
            const _SectionTitle('Notes internes'),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: context.l10n.notesInternesOptionnel,
                hintText: context.l10n.informationsInternesNonAfficheesDansLe,
              ),
            ),
            SizedBox(height: 24),

            // ── Bouton ────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                  ? SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                  : Icon(Icons.check),
                label: Text(_loading
                  ? 'Enregistrement...'
                  : isEdit ? 'Modifier' : 'Ajouter le vehicule'),
              ),
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  /// Scan OCR d'une carte grise
  /// CORRECTIF : utilise readAsBytes() (XFile) au lieu de File(dart:io)
  /// → compatible Flutter Web, Android et iOS
  Future<void> _scanCarteGrise() async {
    // Sur Web, la caméra native n'est pas disponible : on propose seulement la galerie
    final bool isWeb = kIsWeb;

    try {
      final picker = ImagePicker();

      ImageSource? source;
      if (isWeb) {
        // Sur Web : pas de caméra native, on passe directement à la galerie
        source = ImageSource.gallery;
      } else {
        source = await showModalBottomSheet<ImageSource>(
          context: context,
          builder: (ctx) => SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text(context.l10n.prendreEnPhotoLaCarteGrise),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text(context.l10n.choisirUnePhotoDeLaCarte),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ]),
          ),
        );
      }

      if (source == null) return;

      final xfile = await picker.pickImage(
          source: source, imageQuality: 85, maxWidth: 1600);
      if (xfile == null) return;

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(context.l10n.analyseDeLaCarteGrise),
                ],
              ),
            ),
          ),
        ),
      );

      // ── CORRECTIF PRINCIPAL ──────────────────────────────────────────────
      // Lire les bytes via XFile (pas dart:io File) → fonctionne sur Web
      final Uint8List imageBytes = await xfile.readAsBytes();

      // Récupérer la clé Gemini depuis showroom_settings (Supabase)
      final supabase = ref.read(supabaseClientProvider);
      final settingsRow = await supabase
          .from('showroom_settings')
          .select('gemini_api_key')
          .limit(1)
          .maybeSingle();
      final geminiKey = settingsRow?['gemini_api_key'] as String? ?? '';

      if (geminiKey.isEmpty) {
        if (mounted) Navigator.pop(context);
        if (mounted) {
          NotificationService().error(
              context.l10n.cleApiGeminiNonConfiguree);
        }
        return;
      }

      final mimeType = xfile.mimeType ?? 'image/jpeg';
      // Sur Web, la clé est obligatoire ; sur mobile, ML Kit fonctionne sans.
      if (kIsWeb && geminiKey.isEmpty) {
        if (mounted) Navigator.pop(context);
        if (mounted) {
          NotificationService().error(
              context.l10n.cleApiGeminiNonConfiguree);
        }
        return;
      }

      final ocrService = CarteGriseOcrService(
        geminiApiKey: geminiKey.isNotEmpty ? geminiKey : null,
      );
      final data = await ocrService.scanCarteGrise(imageBytes, mimeType: mimeType);
      // ── FIN CORRECTIF ────────────────────────────────────────────────────

      if (mounted) Navigator.pop(context);

      if (data.isValid) {
        setState(() {
          if (data.marque != null) _marqueCtrl.text = data.marque!;
          if (data.modele != null) _modeleCtrl.text = data.modele!;
          if (data.annee != null) _anneeCtrl.text = data.annee.toString();
          if (data.immatriculation != null) _immatCtrl.text = data.immatriculation!;
          if (data.numChassis != null) _chassisCtrl.text = data.numChassis!;

          if (data.energie != null) {
            final energie = data.energie!.toLowerCase();
            if (energie.contains('essence')) {
              _carburant = 'essence';
            } else if (energie.contains('diesel') || energie.contains('gas')) {
              _carburant = 'diesel';
            } else if (energie.contains('electrique') || energie.contains('elec')) {
              _carburant = 'electrique';
            } else if (energie.contains('hybride')) {
              _carburant = 'hybride';
            } else if (energie.contains('glp') || energie.contains('gaz')) {
              _carburant = 'glp';
            }
          }
        });

        if (mounted) {
          NotificationService().success(context.l10n.carteGriseAnalysee);
        }
      } else {
        if (mounted) {
          NotificationService().warning(
              context.l10n.analyseTermineeDonneesManquantes);
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        NotificationService().error('Erreur lors de l\'analyse OCR: ${e.toString()}');
      }
    }
  }

  /// Gestion hybride de la sélection et de l'upload immédiat vers Supabase Storage
  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image == null) return;

    setState(() => _uploading = true);

    try {
      final supabase = ref.read(supabaseClientProvider);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      final path = widget.vehiculeId != null 
          ? '${widget.vehiculeId}/$fileName' 
          : 'temp/$fileName';

      // Extraction sous forme binaire brute (Valide sous Android, iOS et Web)
      final Uint8List fileBytes = await image.readAsBytes();

      await supabase.storage.from('vehicules').uploadBinary(
            path,
            fileBytes,
            fileOptions: FileOptions(
              contentType: image.mimeType ?? 'image/jpeg',
              upsert: true,
            ),
          );

      final String publicUrl = supabase.storage.from('vehicules').getPublicUrl(path);

      setState(() {
        _photosUrls.add(publicUrl);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.photoAjouteeAvecSucces),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.erreurUploadPhoto(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_totalParts > 0 && _totalParts != 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.sommePartsDoit100),
          backgroundColor: AppColors.retard));
      return;
    }
    setState(() => _loading = true);
    try {
      final repo = ref.read(vehiculesRepositoryProvider);
      final vehiculeData = {
        'marque':              _marqueCtrl.text.trim(),
        'modele':              _modeleCtrl.text.trim(),
        'annee':               int.parse(_anneeCtrl.text),
        'couleur':             _couleurCtrl.text.trim().isEmpty ? null : _couleurCtrl.text.trim(),
        'immatriculation':     _immatCtrl.text.trim().isEmpty ? null : _immatCtrl.text.trim(),
        'num_chassis':         _chassisCtrl.text.trim().isEmpty ? null : _chassisCtrl.text.trim(),
        'assurance':           _assuranceCtrl.text.trim().isEmpty ? null : _assuranceCtrl.text.trim(),
        'code_radio':          _codeRadioCtrl.text.trim().isEmpty ? null : _codeRadioCtrl.text.trim(),
        'carburant':           _carburant,
        'boite':               _boite,
        'kilometrage':         int.tryParse(_kmCtrl.text) ?? 0,
        'prix_vente':          double.tryParse(_prixVenteCtrl.text),
        'prix_location_jour':  double.tryParse(_prixLocCtrl.text),
        'statut':              _statut,
        'photos':              _photosUrls, // Utilise directement les urls cloud collectées
        'notes':               _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'etat_vehicule':       _etatVehiculeCtrl.text.trim().isEmpty ? null : _etatVehiculeCtrl.text.trim(),
        'flespi_device_id':    _flespiDeviceIdCtrl.text.trim().isEmpty ? null : int.tryParse(_flespiDeviceIdCtrl.text.trim()),
        'created_by':          ref.read(supabaseClientProvider).auth.currentUser?.id,
      };
      
      final proprietesList = _proprietes.entries.map((e) => {
        'proprietaire_id': e.key,
        'part_pct':        e.value,
        'type_participation': _typeParticipation[e.key] ?? 'proprietaire',
      }).toList();

      if (widget.vehiculeId == null) {
        await repo.create(vehiculeData, proprietesList);
      } else {
        await repo.update(widget.vehiculeId!, vehiculeData);
      }
      
      ref.invalidate(vehiculesProvider);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.vehiculeId == null
            ? 'Vehicule ajoute avec succes'
            : 'Vehicule modifie avec succes')));
      }
    } catch (e, stackTrace) {
      String errorMessage = 'Erreur lors de l\'enregistrement';
      
      if (e.toString().contains('PostgresException')) {
        errorMessage = 'Erreur de base de données. Vérifiez que tous les champs obligatoires sont remplis et que les parts des propriétaires totalisent 100%.';
      } else if (e.toString().contains('StorageException')) {
        errorMessage = 'Erreur lors de l\'upload des photos. Vérifiez votre connexion.';
      } else if (e.toString().contains('network') || e.toString().contains('Socket')) {
        errorMessage = 'Problème de connexion. Vérifiez votre réseau.';
      } else {
        errorMessage = 'Erreur: ${e.toString().substring(0, e.toString().length > 100 ? 100 : e.toString().length)}';
      }
      
      if (mounted) {
        NotificationService().error(errorMessage);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(ctx.l10n.detailDeLErreur),
            content: SelectableText(
              'Type: ${e.runtimeType}\n\nMessage: $e\n\nStack: $stackTrace',
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.l10n.btnFermer),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ── Widgets helpers ───────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(title, style: AppTextStyles.heading3),
  );
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final TextInputType type;
  final String? suffix;
  final bool required;
  final String? Function(String?)? validator;
  const _Field({
    required this.ctrl, required this.label,
    this.type = TextInputType.text,
    this.suffix, this.required = false, this.validator,
  });
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: ctrl,
    keyboardType: type,
    decoration: InputDecoration(labelText: label, suffixText: suffix),
    validator: validator ?? (required
      ? (v) => (v == null || v.isEmpty) ? 'Requis' : null
      : null),
  );
}

class _Dropdown extends StatelessWidget {
  final String label, value;
  final Map<String, String> items;
  final void Function(String?) onChanged;
  const _Dropdown({
    required this.label, required this.value,
    required this.items, required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: items.entries.map((e) => DropdownMenuItem<String>(
      value: e.key, child: Text(e.value))).toList(),
    onChanged: onChanged,
  );
}

class _ProprieteRow extends StatelessWidget {
  final Profile profile;
  final double? value;
  final String typeParticipation;
  final void Function(double?) onChanged;
  final void Function(String) onTypeChanged;
  const _ProprieteRow({
    required this.profile,
    this.value,
    required this.typeParticipation,
    required this.onChanged,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ctrl = TextEditingController(
      text: value != null ? value!.toInt().toString() : '');
    final isActive = value != null && value! > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: profile.color.withValues(alpha: 0.15),
          child: Text(profile.initials,
            style: TextStyle(fontSize: 11,
              fontWeight: FontWeight.w600, color: profile.color)),
        ),
        SizedBox(width: 10),
        Expanded(child: Text(profile.fullName,
          style: AppTextStyles.body)),
        if (isActive) ...[
          SizedBox(
            width: 130,
            child: DropdownButtonFormField<String>(
              value: typeParticipation,
              isDense: true,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8, vertical: 10),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'proprietaire', child: Text('Propriétaire')),
                DropdownMenuItem(
                  value: 'associe', child: Text('Associé')),
              ],
              onChanged: (t) => onTypeChanged(t ?? 'proprietaire'),
            ),
          ),
          SizedBox(width: 10),
        ],
        SizedBox(
          width: 80,
          child: TextFormField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              suffixText: '%',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 8, vertical: 10)),
            onChanged: (v) => onChanged(double.tryParse(v)),
          ),
        ),
      ]),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  final Widget child;
  final VoidCallback onDelete;
  const _PhotoThumb({required this.child, required this.onDelete});
  @override
  Widget build(BuildContext context) => Container(
    width: 100, height: 100,
    margin: const EdgeInsets.only(right: 8),
    child: Stack(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(width: 100, height: 100, child: child),
      ),
      Positioned(top: 4, right: 4,
        child: GestureDetector(
          onTap: onDelete,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.retard,
              shape: BoxShape.circle),
            child: Icon(Icons.close,
              color: Colors.white, size: 16),
          ),
        )),
    ]),
  );
}

class _AddPhotoBtn extends StatelessWidget {
  final bool uploading;
  final VoidCallback onTap;
  const _AddPhotoBtn({required this.uploading, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: uploading ? null : onTap,
    child: Container(
      width: 100, height: 100,
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: uploading
        ? Center(child: CircularProgressIndicator())
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo_outlined,
                color: AppColors.textSecondary, size: 28),
              SizedBox(height: 4),
              Text(context.l10n.btnAjouter, style: TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
    ),
  );
}