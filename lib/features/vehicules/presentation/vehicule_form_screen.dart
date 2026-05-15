import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/carte_grise_ocr_service.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/services/notification_service.dart';
import '../../auth/domain/profile_model.dart';
import 'vehicules_provider.dart';

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
  final _kmCtrl      = TextEditingController(text: '0');
  final _prixVenteCtrl  = TextEditingController();
  final _prixLocCtrl    = TextEditingController();
  final _notesCtrl      = TextEditingController();
  final _etatVehiculeCtrl = TextEditingController();
  final _flespiDeviceIdCtrl = TextEditingController();

  String _carburant = 'essence';
  String _boite     = 'manuelle';
  String _statut    = 'disponible';

  final List<String> _photosUrls = [];
  final List<File>   _photosLocal = [];

  // Propriétaires : {profileId -> pourcentage}
  final Map<String, double> _proprietes = {};
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
    
    // Charger les données du véhicule
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
      
      // Charger les photos existantes
      final photos = data['photos'] as List<dynamic>?;
      if (photos != null) {
        _photosUrls.addAll(photos.map((p) => p.toString()));
      }
    });
    
    // Charger les propriétaires
    final proprietesData = await ref.read(supabaseClientProvider)
        .from('vehicule_proprietes')
        .select()
        .eq('vehicule_id', widget.vehiculeId!);
    
    setState(() {
      for (final prop in proprietesData) {
        _proprietes[prop['proprietaire_id']] = (prop['part_pct'] as num).toDouble();
      }
    });
      }

  double get _totalParts =>
    _proprietes.values.fold(0.0, (s, v) => s + v);

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
            // ── Photos ───────────────────────────────────────
            const _SectionTitle('Photos'),
            SizedBox(
              height: 110,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ..._photosLocal.map((f) => _PhotoThumb(
                    child: Image.file(f, fit: BoxFit.cover),
                    onDelete: () =>
                      setState(() => _photosLocal.remove(f)),
                  )),
                  ..._photosUrls.map((u) => _PhotoThumb(
                    child: Image.network(u, fit: BoxFit.cover),
                    onDelete: () =>
                      setState(() => _photosUrls.remove(u)),
                  )),
                  _AddPhotoBtn(
                    uploading: _uploading,
                    onTap: _pickPhoto,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Infos générales ───────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _SectionTitle('Informations generales'),
                TextButton.icon(
                  icon: const Icon(Icons.document_scanner, size: 18),
                  label: const Text('Scanner carte grise'),
                  onPressed: _scanCarteGrise,
                ),
              ],
            ),
            Row(children: [
              Expanded(child: _Field(
                ctrl: _marqueCtrl, label: 'Marque',
                required: true)),
              const SizedBox(width: 10),
              Expanded(child: _Field(
                ctrl: _modeleCtrl, label: 'Modele',
                required: true)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _Field(
                ctrl: _anneeCtrl, label: 'Annee',
                type: TextInputType.number, required: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requis';
                  final y = int.tryParse(v);
                  if (y == null || y < 1950 || y > 2030) {
                    return 'Annee invalide';
                  }
                  return null;
                })),
              const SizedBox(width: 10),
              Expanded(child: _Field(
                ctrl: _couleurCtrl, label: 'Couleur')),
            ]),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _Field(
                    ctrl: _immatCtrl,
                    label: 'Immatriculation',
                  ),
                ),
                const SizedBox(width: 10),

                Expanded(
                  child: _Field(
                    ctrl: _chassisCtrl,
                    label: 'N° Chassis',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            _Field(
              ctrl: _flespiDeviceIdCtrl,
              label: 'Flespi Device ID (GPS)',
              type: TextInputType.number,
              validator: (v) {
                if (v != null &&
                    v.isNotEmpty &&
                    int.tryParse(v) == null) {
                  return 'ID invalide';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            _Field(
              ctrl: _kmCtrl, label: 'Kilometrage',
              type: TextInputType.number,
              suffix: 'km', required: true),
            const SizedBox(height: 10),
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
              const SizedBox(width: 10),
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
            const SizedBox(height: 20),

            // ── Prix ─────────────────────────────────────────
            const _SectionTitle('Prix'),
            Row(children: [
              Expanded(child: _Field(
                ctrl: _prixLocCtrl,
                label: 'Prix location / jour',
                type: TextInputType.number,
                suffix: 'DA')),
              const SizedBox(width: 10),
              Expanded(child: _Field(
                ctrl: _prixVenteCtrl,
                label: 'Prix de vente',
                type: TextInputType.number,
                suffix: 'DA')),
            ]),
            const SizedBox(height: 20),

            // ── Statut ────────────────────────────────────────
            const _SectionTitle('Statut initial'),
            _Dropdown(
              label: 'Statut',
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
            const SizedBox(height: 20),

            // ── Propriétaires ────────────────────────────────
            const _SectionTitle('Proprietaire(s) et parts (%)'),
            if (_allProfiles.isEmpty)
              const Center(child: CircularProgressIndicator())
            else
              ..._allProfiles
                .where((p) => p.role != UserRole.gerant)
                .map((p) => _ProprieteRow(
                  profile: p,
                  value: _proprietes[p.id],
                  onChanged: (v) => setState(() {
                    if (v == null || v == 0) {
                      _proprietes.remove(p.id);
                    } else {
                      _proprietes[p.id] = v;
                    }
                  }),
                )),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Total : ${_totalParts.toInt()}%',
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
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'La somme des parts doit etre egale a 100%',
                  style: TextStyle(
                    color: AppColors.retard, fontSize: 12)),
              ),
            const SizedBox(height: 20),

            // ── État du véhicule ────────────────────────────────
            const _SectionTitle('État du véhicule'),
            const Text(
              'Décrivez tout ce qui ne fonctionne pas ou est endommagé (pannes, rayures, bosses…). '
              'Ces informations seront intégrées au contrat de location.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _etatVehiculeCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Dommages / pannes / anomalies (optionnel)',
                hintText: 'Ex : Rayure sur aile avant gauche, climatisation en panne, rétroviseur droit fissuré…',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // ── Notes internes ─────────────────────────────────
            const _SectionTitle('Notes internes'),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes internes (optionnel)',
                hintText: 'Informations internes non affichées dans le contrat',
              ),
            ),
            const SizedBox(height: 24),

            // ── Bouton ────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check),
                label: Text(_loading
                  ? 'Enregistrement...'
                  : isEdit ? 'Modifier' : 'Ajouter le vehicule'),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  /// Scan OCR d'une carte grise
  Future<void> _scanCarteGrise() async {
    try {
      // Ouvrir le sélecteur d'image
      final picker = ImagePicker();
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Prendre en photo la carte grise'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choisir une photo de la carte grise'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ]),
        ),
      );
      
      if (source == null) return;
      
      final xfile = await picker.pickImage(
        source: source, imageQuality: 85, maxWidth: 1600);
      if (xfile == null) return;
      
      // Afficher un indicateur de chargement
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Analyse de la carte grise...'),
                ],
              ),
            ),
          ),
        ),
      );
      
      // Traiter l'image avec l'OCR
      final ocrService = CarteGriseOcrService();
      final data = await ocrService.scanCarteGrise(File(xfile.path));
      
      // Fermer le dialog
      if (mounted) Navigator.pop(context);
      
      // Remplir les champs avec les données extraites
      if (data.isValid) {
        setState(() {
          if (data.marque != null) _marqueCtrl.text = data.marque!;
          if (data.modele != null) _modeleCtrl.text = data.modele!;
          if (data.annee != null) _anneeCtrl.text = data.annee.toString();
          if (data.immatriculation != null) _immatCtrl.text = data.immatriculation!;
          if (data.numChassis != null) _chassisCtrl.text = data.numChassis!;
          
          // Normaliser le type de carburant
          if (data.energie != null) {
            final energie = data.energie!.toLowerCase();
            if (energie.contains('essence')) {
              _carburant = 'essence';
            } else if (energie.contains('diesel') || energie.contains('gas')) _carburant = 'diesel';
            else if (energie.contains('electrique') || energie.contains('elec')) _carburant = 'electrique';
            else if (energie.contains('hybride')) _carburant = 'hybride';
            else if (energie.contains('glp') || energie.contains('gaz')) _carburant = 'glp';
          }
        });
        
        if (mounted) {
          NotificationService().success('Carte grise analysée avec succès !');
        }
      } else {
        if (mounted) {
          NotificationService().warning(
            'Analyse terminée mais certaines données sont manquantes. Veuillez compléter manuellement.');
        }
      }
    } catch (e) {
      // Fermer le dialog si ouvert
      if (mounted) Navigator.pop(context);
      
      if (mounted) {
        NotificationService().error('Erreur lors de l\'analyse OCR: ${e.toString()}');
      }
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Prendre une photo'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Choisir depuis la galerie'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (source == null) return;
    final xfile = await picker.pickImage(
      source: source, imageQuality: 75, maxWidth: 1200);
    if (xfile == null) return;
    setState(() => _photosLocal.add(File(xfile.path)));
  }

  Future<List<String>> _uploadPhotos() async {
    final urls = List<String>.from(_photosUrls);
    for (final file in _photosLocal) {
      setState(() => _uploading = true);
      final bytes    = await file.readAsBytes();
      final ext      = file.path.split('.').last;
      final fileName =
        '${DateTime.now().millisecondsSinceEpoch}.$ext';
      await ref.read(supabaseClientProvider).storage
        .from('vehicules-photos')
        .uploadBinary(fileName, bytes,
          fileOptions: FileOptions(contentType: 'image/$ext'));
      final url = ref.read(supabaseClientProvider).storage
        .from('vehicules-photos')
        .getPublicUrl(fileName);
      urls.add(url);
    }
    setState(() => _uploading = false);
    return urls;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_totalParts > 0 && _totalParts != 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La somme des parts doit etre 100%'),
          backgroundColor: AppColors.retard));
      return;
    }
    setState(() => _loading = true);
    try {
      final photoUrls = await _uploadPhotos();
      final repo = ref.read(vehiculesRepositoryProvider);
      final vehiculeData = {
        'marque':              _marqueCtrl.text.trim(),
        'modele':              _modeleCtrl.text.trim(),
        'annee':               int.parse(_anneeCtrl.text),
        'couleur':             _couleurCtrl.text.trim().isEmpty
                                 ? null : _couleurCtrl.text.trim(),
        'immatriculation':     _immatCtrl.text.trim().isEmpty
                                 ? null : _immatCtrl.text.trim(),
        'num_chassis':         _chassisCtrl.text.trim().isEmpty
                                 ? null : _chassisCtrl.text.trim(),
        'carburant':           _carburant,
        'boite':               _boite,
        'kilometrage':         int.tryParse(_kmCtrl.text) ?? 0,
        'prix_vente':          double.tryParse(_prixVenteCtrl.text),
        'prix_location_jour':  double.tryParse(_prixLocCtrl.text),
        'statut':              _statut,
        'photos':              photoUrls,
        'notes':               _notesCtrl.text.trim().isEmpty
                                 ? null : _notesCtrl.text.trim(),
        'etat_vehicule':       _etatVehiculeCtrl.text.trim().isEmpty
                                 ? null : _etatVehiculeCtrl.text.trim(),
        'flespi_device_id':   _flespiDeviceIdCtrl.text.trim().isEmpty
                                 ? null : int.tryParse(_flespiDeviceIdCtrl.text.trim()),
        'created_by':          ref.read(supabaseClientProvider).auth.currentUser?.id,
      };
      final proprietesList = _proprietes.entries.map((e) => {
        'proprietaire_id': e.key,
        'part_pct':        e.value,
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
      // Afficher un message d'erreur plus détaillé
      String errorMessage = 'Erreur lors de l\'enregistrement';
      
      // Vérifier le type d'erreur
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
        // Afficher le détail complet dans un dialog pour debugging
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Détail de l\'erreur'),
            content: SelectableText(
              'Type: ${e.runtimeType}\n\nMessage: $e\n\nStack: $stackTrace',
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fermer'),
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
  final void Function(double?) onChanged;
  const _ProprieteRow({
    required this.profile, this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final ctrl = TextEditingController(
      text: value != null ? value!.toInt().toString() : '');
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
        const SizedBox(width: 10),
        Expanded(child: Text(profile.fullName,
          style: AppTextStyles.body)),
        SizedBox(
          width: 80,
          child: TextFormField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
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
            child: const Icon(Icons.close,
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
        ? const Center(child: CircularProgressIndicator())
        : const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo_outlined,
                color: AppColors.textSecondary, size: 28),
              SizedBox(height: 4),
              Text('Ajouter', style: TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
    ),
  );
}