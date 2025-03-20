# **EXODEcola - Versions**
Ce dépôt sert à **stocker et gérer les différentes versions** de tes scripts **associés à portal.cfx** sous format **JSON**.

## 📌 **Objectif**
- Permettre **un suivi précis des versions** de tes scripts.
- Faciliter la **mise à jour et la gestion des versions** pour les utilisateurs.
- Automatiser le **stockage des versions** de chaque script sous forme de **fichiers JSON**.

## 📂 **Structure du dépôt**
```
versions/
│── script1.json
│── script2.json
│── script3.json
└── README.md
```
Chaque fichier JSON contient les informations de version du script correspondant.

---

## 🔧 **Format des fichiers JSON**
Chaque script a un fichier JSON avec les métadonnées suivantes :

```json
{
  "script_name": "nom_du_script",
  "version": "1.0.0",
  "release_date": "YYYY-MM-DD",
  "changelog": [
    "Ajout d'une nouvelle fonctionnalité",
    "Correction d'un bug de compatibilité",
    "Optimisation des performances"
  ],
  "download_url": "https://portal.cfx.re"
}
```

📌 **Explication des champs :**
- **`script_name`** → Nom du script.
- **`version`** → Version actuelle du script.
- **`release_date`** → Date de sortie de la version.
- **`changelog`** → Liste des modifications et améliorations.
- **`download_url`** → Lien pour télécharger la version sur **portal.cfx**.

---

## 🚀 **Utilisation**
1. **Ajouter une nouvelle version :**
   - Crée un **nouveau fichier JSON** pour chaque script.
   - Remplis les informations de version et de mise à jour.
   - Enregistre les fichiers dans le dossier **`versions/`**.

2. **Mettre à jour un script :**
   - Ouvre son fichier JSON.
   - Modifie la **version**, la **date de sortie**, et le **changelog**.
   - Pousse les modifications sur le dépôt.

3. **Automatiser les mises à jour :**
   - Intégrer un **système d’update checker** dans tes scripts pour récupérer la dernière version disponible.

---

## 🔗 **Liens utiles**
- 📌 [Portal CFX](https://portal.cfx.re/)
- 📜 [Discord]([https://www.json.org/json-fr.html](https://discord.gg/exode-developpement-fivem-869625490758070353))

---

## 💡 **Prochaines améliorations**
✅ Ajout d’un **système d’API REST** pour récupérer dynamiquement les versions.  
✅ Automatisation de la **création des fichiers JSON** via un script.  
✅ Intégration d’un **checker de version dans les scripts FiveM**.  

---

💬 **Si tu as des questions ou suggestions, n’hésite pas à contribuer !** 🚀
