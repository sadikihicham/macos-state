#ifndef CIOHID_H
#define CIOHID_H

/// Lecture des capteurs thermiques via l'API IOHID privée (Apple Silicon).
/// Lecture seule. Ces fonctions n'ouvrent aucun socket : l'invariant zéro-réseau
/// du binaire reste vrai (vérifié par scripts/check-no-network.sh).

/// Moyenne (°C) des capteurs de température dont le nom (Product) contient
/// `token` (insensible à la casse). `token` NULL ou vide → moyenne de TOUS les
/// capteurs. Retourne -1.0 si aucun capteur exploitable.
double cihid_temperature_avg(const char *token);

/// Diagnostic : imprime sur stderr la liste "nom = valeur°C" de chaque capteur
/// de température détecté. Sert à identifier les capteurs réels d'une machine.
void cihid_dump_temperatures(void);

#endif /* CIOHID_H */
