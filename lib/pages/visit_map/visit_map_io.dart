import 'package:flutter/material.dart';

class VisitMap extends StatefulWidget {
  final String src;
  final String id;
  const VisitMap({super.key, required this.src, required this.id});

  @override
  State<VisitMap> createState() => _VisitMapState();
}

class _VisitMapState extends State<VisitMap> {
  @override
  Widget build(BuildContext context) {
    throw UnimplementedError('VisitMap is only supported on Web platform');
  }
}