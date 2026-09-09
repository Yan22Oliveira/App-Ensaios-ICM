import 'entities.dart';

/// Pertencimento à estrutura do evento — mesma regra da chamada atual.
///
/// Maanaim: somente worshipLevel maanaim da região (ou todos os maanaim se regionId vazio).
/// Região: região ou maanaim da mesma região.
/// Área: área, região ou maanaim da mesma área.
/// Polo: qualquer nível do mesmo polo.
bool personBelongsToEventStructure(
  Person person, {
  required RehearsalLevel level,
  required String regionId,
  String? areaId,
  String? poloId,
}) {
  switch (level) {
    case RehearsalLevel.maanaim: {
      final rehearsalRegion = regionId.trim();
      return person.worshipLevel == RehearsalLevel.maanaim &&
          (rehearsalRegion.isEmpty || person.regionId == regionId);
    }
    case RehearsalLevel.region:
      return person.regionId == regionId &&
          (person.worshipLevel == RehearsalLevel.region ||
              person.worshipLevel == RehearsalLevel.maanaim);
    case RehearsalLevel.area:
      return person.areaId != null &&
          person.areaId == areaId &&
          (person.worshipLevel == RehearsalLevel.area ||
              person.worshipLevel == RehearsalLevel.region ||
              person.worshipLevel == RehearsalLevel.maanaim);
    case RehearsalLevel.polo:
      return person.poloId != null &&
          person.poloId == poloId &&
          (person.worshipLevel == RehearsalLevel.polo ||
              person.worshipLevel == RehearsalLevel.area ||
              person.worshipLevel == RehearsalLevel.region ||
              person.worshipLevel == RehearsalLevel.maanaim);
  }
}

bool personBelongsToRehearsal(Person person, Rehearsal event) =>
    personBelongsToEventStructure(
      person,
      level: event.level,
      regionId: event.regionId,
      areaId: event.areaId,
      poloId: event.poloId,
    );

/// Remove acentos para busca case-insensitive.
String foldSearch(String input) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
  const to = 'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN';
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    final i = from.indexOf(ch);
    buffer.write(i >= 0 ? to[i] : ch);
  }
  return buffer.toString().toLowerCase();
}
