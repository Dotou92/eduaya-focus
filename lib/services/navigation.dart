import 'package:flutter/material.dart';

/// Clé de navigation globale, utilisée pour naviguer depuis en dehors
/// de l'arbre de widgets (ex : réponse à une notification, §9).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
