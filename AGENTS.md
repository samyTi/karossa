<!-- AI_AGENT_INSTRUCTIONS_START -->
## 🤖 Règles Git & GitHub pour les Agents IA
Tu dois strictement respecter ces instructions pour toutes les opérations de contrôle de version :
- **Gestion des branches** : Ne committe jamais et ne push jamais directement sur `main` ou `master`. Vérifie toujours la branche actuelle. Si nécessaire, demande l'autorisation de créer une branche de fonctionnalité nommée `feature/agent-<sujet>`.
- **Format des commits** : Respecte le format "Conventional Commits" (ex: `feat(auth): add token validation` ou `fix(ui): resolve layout shift`). Les messages de commit doivent être concis et rédigés à l'impératif en anglais.
- **Granularité** : Fais des commits atomiques. Une seule modification logique par commit. Ne regroupe pas plusieurs fonctionnalités non liées dans un seul commit.
- **Protocole avant Push** : Exécute toujours `git pull --rebase origin <branche>` avant de push pour éviter les commits de fusion inutiles.
- **Sécurité et Secrets** : Inspecte obligatoirement le projet à la recherche de fichiers sensibles (`.env`, clés, certificats) avant le staging. Ne contourne jamais le fichier `.gitignore`.
<!-- AI_AGENT_INSTRUCTIONS_END -->
