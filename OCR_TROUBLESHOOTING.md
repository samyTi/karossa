# Guide de dépannage - OCR Carte Grise

## Problèmes courants et solutions

### 1. L'OCR ne fonctionne pas / retourne des données vides

#### Causes possibles :

**A. Problèmes de configuration Android**
- `minSdkVersion` trop basse (doit être >= 21)
- Permissions manquantes dans AndroidManifest.xml
- ProGuard qui bloque ML Kit

**B. Problèmes avec l'image**
- Image trop sombre ou trop claire
- Image floue
- Carte grise mal cadrée
- Résolution insuffisante

**C. Problèmes avec le modèle ML Kit**
- Modèle non téléchargé (premier lancement)
- Version incompatible de google_mlkit_text_recognition

---

## Vérifications à effectuer

### 1. Vérifier la configuration Android

**Fichier : `android/app/build.gradle.kts`**
```kotlin
defaultConfig {
    minSdk = 21  // DOIT être au moins 21 pour ML Kit
    // ...
}
```

**Fichier : `android/app/src/main/AndroidManifest.xml`**
```xml
<!-- Permissions nécessaires -->
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>

<!-- Fonctionnalités matérielles -->
<uses-feature android:name="android.hardware.camera" android:required="false"/>
<uses-feature android:name="android.hardware.camera.autofocus" android:required="false"/>
```

**Fichier : `android/app/proguard-rules.pro`**
```proguard
# Conserver les classes ML Kit
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.mlkit.**
```

### 2. Vérifier les dépendances

**Fichier : `pubspec.yaml`**
```yaml
dependencies:
  google_mlkit_text_recognition: ^0.12.0  # Version compatible
  image_picker: ^1.0.7
  permission_handler: ^11.3.0
```

Après modification, exécuter :
```bash
flutter clean
flutter pub get
flutter run
```

### 3. Tester l'OCR

**Mode debug activé** : Les logs détaillés sont affichés dans la console.

Exécutez l'application en mode debug et observez les logs :
```bash
flutter run --verbose
```

Les logs importants :
- `CarteGriseOcrService: Initialisé avec succès`
- `CarteGriseOcrService: Texte reconnu (X caractères)`
- `=== TEXTE OCR BRUT ===` (affiche le texte extrait)

### 4. Conseils pour une bonne capture

1. **Éclairage** : Prenez la photo dans un endroit bien éclairé
2. **Stabilité** : Tenez le téléphone stable
3. **Distance** : Ni trop près, ni trop loin (20-30 cm)
4. **Angle** : Photo bien droite, pas d'angle
5. **Qualité** : La carte grise doit être lisible à l'œil nu

### 5. Formats de carte grise supportés

L'OCR est optimisé pour :
- Cartes grises françaises (format européen)
- Champs : A.1 (immatriculation), D.1 (marque), D.2 (modèle), B.1 (date), etc.

### 6. Si l'OCR retourne toujours des données vides

**Option 1 : Tester avec une image de test**
```dart
// Dans vehicule_form_screen.dart, ajoutez un bouton de test
Future<void> _testOcr() async {
  final ocrService = CarteGriseOcrService();
  
  // Utiliser une image de test connue
  final testFile = File('/chemin/vers/image_test.jpg');
  
  try {
    final data = await ocrService.scanCarteGrise(testFile);
    print('Résultat OCR : $data');
  } catch (e) {
    print('Erreur OCR : $e');
  }
}
```

**Option 2 : Vérifier que ML Kit est initialisé**
```dart
// Dans main.dart ou au démarrage
Future<void> checkMlKit() async {
  try {
    final recognizer = TextRecognizer();
    print('ML Kit TextRecognizer: OK');
    recognizer.close();
  } catch (e) {
    print('ML Kit TextRecognizer: ERREUR - $e');
  }
}
```

### 7. Erreurs courantes et solutions

| Erreur | Cause | Solution |
|--------|-------|----------|
| `PlatformException` | Permission caméra refusée | Demander la permission dans les paramètres |
| `TextRecognizer failed` | ML Kit non disponible | Vérifier minSdkVersion et dépendances |
| Texte vide | Image de mauvaise qualité | Reprendre la photo avec meilleur éclairage |
| Données partielles | Format carte grise non standard | Compléter manuellement les champs manquants |

### 8. Alternative : Utiliser une API OCR externe

Si ML Kit ne fonctionne pas, envisagez d'utiliser une API cloud :
- Google Cloud Vision API
- Azure Computer Vision
- AWS Textract

Ces solutions nécessitent une connexion internet mais offrent une meilleure précision.

---

## Checklist de vérification rapide

- [ ] `minSdk = 21` dans `android/app/build.gradle.kts`
- [ ] Permissions caméra/stockage dans `AndroidManifest.xml`
- [ ] Règles ProGuard pour ML Kit dans `proguard-rules.pro`
- [ ] `google_mlkit_text_recognition: ^0.12.0` dans `pubspec.yaml`
- [ ] `flutter clean && flutter pub get` exécuté
- [ ] Application rebuild (`flutter run`)
- [ ] Logs debug vérifiés (`flutter run --verbose`)
- [ ] Photo prise dans de bonnes conditions (éclairage, stabilité)
- [ ] Permissions accordées sur le device

---

## Support

Si le problème persiste après avoir suivi ce guide :

1. Consultez les logs complets avec `flutter run --verbose`
2. Vérifiez la compatibilité de votre device (Android 5.0+)
3. Testez sur un autre device si possible
4. Ouvrez une issue GitHub avec :
   - Logs d'erreur complets
   - Version d'Android
   - Modèle du device
   - Captures d'écran des logs