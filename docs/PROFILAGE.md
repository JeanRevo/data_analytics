# Constats de profilage

Mesures faites sur les données brutes (`raw_*`), avant nettoyage. Chaque chiffre est un résultat de requête SQL reproductible. Les hypothèses sont étiquetées comme telles.

## Intégrité entre fichiers

- 251 codes articles distincts dans les trois premiers fichiers. Aucun orphelin dans `loss_rate`, `price` ni `transaction` vis-à-vis de `product`.
- `loss_rate.item_name` est identique à `product.item_name` pour les 251 articles (0 écart).

## product

- 4 libellés avec espaces de bord, 2 avec double espace (6 libellés modifiés au total par le nettoyage).
- 100 `category_name` contiennent une espace insécable U+00A0 (« Flower/Leaf Vegetables »).
- 4 libellés portés par 2 codes distincts : `Apricot Bao Mushroom (Bag)`, `Broccoli`, `Chinese Cabbage`, `Chinese Caterpillar Fungus Flowers (Bag)`. Produits distincts ou doublons : non tranchable.
- 5 articles sans aucune transaction.

## loss_rate

- Les 251 valeurs portent une espace finale.
- Min 0,00 ; max 29,25.
- 85 articles à 9,43. La moyenne des 166 autres valeurs vaut 9,425, soit 9,43 à l'arrondi. **Hypothèse** : valeur imputée par la moyenne, non mesurée. Non démontré.
- 22 articles à 0,00 : mesure réelle ou donnée manquante, non tranchable.

## price

- 55 982 lignes, 1 091 jours distincts sur une plage de 1 095 jours, 251 articles. Aucun doublon sur (date, article). Dates toutes au format ISO.
- Couverture très inégale : de 1 à 1 085 jours par article.
- Prix de 0,01 à 141,00 RMB/kg. 273 lignes sous 0,50 RMB/kg.
- Par rapport à la moyenne de l'article : 3 lignes à plus de 5 fois, 320 lignes à moins d'un cinquième. La moyenne étant sensible aux pics, c'est un indice et non une preuve d'erreur.

## transaction

- 878 503 lignes, aucune valeur vide, aucun doublon exact.
- 461 retours, tous en quantité négative ; les 878 042 ventes sont toutes en quantité positive.
- 18 841 heures sans trois décimales de millisecondes (132 sans fraction, 1 106 à une décimale, 17 603 à deux). Hypothèse retenue : zéros finaux supprimés à l'export. La valeur numérique est identique dans les deux lectures.
- 1 couple (date, heure, article) sur 2 lignes, quantités différentes (0,565 et 0,578) : deux ventes distinctes.
- 56 lignes à 10 kg ou plus ; maximum 160 kg d'un article à 5,9 RMB/kg.
- 12 651 ventes à un prix inférieur au prix de gros du même jour, dont 3 356 sans remise.
- 4 retours sans vente du même article le même jour.
- Remise : 47 366 « Yes », 831 137 « No ».
