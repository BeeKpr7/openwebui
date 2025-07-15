# 🔄 Mise à jour d'Open WebUI

## Pourquoi mon Open WebUI ne se met-il pas à jour ?

Pour mettre à jour votre installation Docker locale d'Open WebUI vers la dernière version disponible, vous pouvez effectuer la mise à jour manuellement. Suivez les étapes ci-dessous pour être guidé dans la mise à jour de votre image Open WebUI existante.

### Mise à jour manuelle

1. **Arrêter et supprimer le conteneur actuel** :
   Cela arrêtera le conteneur en cours d'exécution et le supprimera, mais ne supprimera pas les données stockées dans le volume Docker.

```bash
docker rm -f openwebui-production
```

2. **Télécharger la dernière image Docker** :
   Cela mettra à jour l'image Docker, mais ne mettra pas à jour le conteneur en cours d'exécution ou ses données.

```bash
docker pull ghcr.io/open-webui/open-webui:main
```

> **⚠️ ATTENTION - Suppression des données existantes (NON RECOMMANDÉ SAUF ABSOLUE NÉCESSITÉ !)**
> 
> Sautez cette étape entièrement si elle n'est pas nécessaire et passez à la dernière étape :
> 
> Si vous voulez repartir de zéro, vous pouvez supprimer les données existantes dans le volume Docker. Attention, cela supprimera tous vos historiques de chat et autres données.
> 
> Les données sont stockées dans un volume Docker nommé `open-webui`. Vous pouvez le supprimer avec la commande suivante :
> 
> ```bash
> docker volume rm open-webui
> ```

3. **Redémarrer le conteneur avec Docker Compose** :
   Utilisez la commande suivante pour redémarrer le conteneur avec l'image mise à jour et le volume existant attaché :

```bash
docker-compose up -d
```

## Problème de déconnexion après chaque mise à jour ?

Si vous vous trouvez déconnecté après chaque mise à jour, assurez-vous que `WEBUI_SECRET_KEY` est défini dans votre fichier `.env.local`. Sans cette clé définie de manière cohérente, vos sessions d'authentification peuvent être invalidées après les mises à jour.

Le fichier `.env.local` contient déjà cette configuration, vous n'avez donc pas besoin de la modifier.

## Données persistantes dans les volumes Docker

Les données sont stockées dans un volume Docker nommé `open-webui`. Le chemin vers le volume n'est pas directement accessible, mais vous pouvez inspecter le volume avec la commande suivante :

```bash
docker volume inspect open-webui
```

Cela vous montrera les détails du volume, y compris le point de montage, qui est généralement situé dans `/var/lib/docker/volumes/open-webui/_data`.

## Conseils supplémentaires

- **Sauvegardez vos données** : Avant toute mise à jour, il est recommandé de sauvegarder vos données importantes
- **Vérifiez les logs** : En cas de problème, consultez les logs du conteneur avec `docker logs openwebui-production`
- **Testez la mise à jour** : Après la mise à jour, vérifiez que tout fonctionne correctement

---

**Source** : [Documentation officielle Open WebUI](https://docs.openwebui.com/getting-started/updating/) 