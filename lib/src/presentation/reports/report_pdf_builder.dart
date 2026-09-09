import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../src.dart';

/// Paleta alinhada ao [AppTheme] para uso no pacote `pdf`.
abstract final class _PdfPalette {
  static final primary = PdfColor.fromInt(0xFF00759A);
  static final success = PdfColor.fromInt(0xFF00B894);
  static final warning = PdfColor.fromInt(0xFFF2C94C);
  static final accentPurple = PdfColor.fromInt(0xFF6C63FF);
  static final bgLight = PdfColor.fromInt(0xFFF9FAFB);
  static final textDark = PdfColor.fromInt(0xFF1F2937);
  static final textMuted = PdfColor.fromInt(0xFF6B7280);
  static final border = PdfColor.fromInt(0xFFE5E7EB);
  static final rowAlt = PdfColor.fromInt(0xFFF3F4F6);
}

class ReportPdfBuilder {
  final ReportsState state;
  final GeoNameResolver geo;
  final UserProfile? profile;
  /// Relatórios textuais dos eventos do período (anexo nas últimas páginas).
  final List<(Rehearsal, EventReport)> eventReports;

  const ReportPdfBuilder({
    required this.state,
    required this.geo,
    this.profile,
    this.eventReports = const [],
  });

  Future<Uint8List> build() async {
    final baseFont = await PdfGoogleFonts.interRegular();
    final boldFont = await PdfGoogleFonts.interBold();
    final theme = pw.ThemeData.withFont(base: baseFont, bold: boldFont);

    final generatedAt = DateTime.now();
    final doc = pw.Document(
      title: 'Relatório de Presença — Frequência ICM',
      author: profile?.displayName ?? 'Frequência ICM',
      creator: 'Frequência ICM',
      subject: 'Relatório de presença em eventos',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(22, 40, 22, 40),
        theme: theme,
        header: (ctx) => _pageHeader(ctx),
        footer: (ctx) => _pageFooter(ctx, generatedAt),
        build: (ctx) => _buildContent(),
      ),
    );

    return doc.save();
  }

  // ---------------------------------------------------------------------------
  // Cabeçalho / rodapé
  // ---------------------------------------------------------------------------

  pw.Widget _pageHeader(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            height: 3,
            decoration: pw.BoxDecoration(
              color: _PdfPalette.primary,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(2),
                topRight: pw.Radius.circular(2),
              ),
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: pw.BoxDecoration(
              color: _PdfPalette.primary,
              borderRadius: const pw.BorderRadius.only(
                bottomLeft: pw.Radius.circular(4),
                bottomRight: pw.Radius.circular(4),
              ),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                  width: 28,
                  height: 28,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'ICM',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _PdfPalette.primary,
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Frequência ICM',
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.Text(
                        'Relatório de Presença',
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColor(1, 1, 1, 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      _fmtDate(DateTime.now()),
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColor(1, 1, 1, 0.9),
                      ),
                    ),
                    if (profile != null)
                      pw.Text(
                        profile!.displayName,
                        style: pw.TextStyle(
                          fontSize: 7,
                          color: PdfColor(1, 1, 1, 0.75),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pageFooter(pw.Context context, DateTime generatedAt) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 6),
      padding: const pw.EdgeInsets.only(top: 5),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _PdfPalette.border, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Gerado em ${_fmtDate(generatedAt)} às ${_fmtTime(generatedAt)}',
                  style: pw.TextStyle(fontSize: 8, color: _PdfPalette.textMuted),
                ),
                pw.Text(
                  'Documento confidencial — uso interno',
                  style: pw.TextStyle(fontSize: 7, color: _PdfPalette.textMuted),
                ),
              ],
            ),
          ),
          pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: _PdfPalette.primary,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Conteúdo
  // ---------------------------------------------------------------------------

  List<pw.Widget> _buildContent() {
    final s = state;
    final filters = s.filters;

    final metaRows = <(String, String)>[
      if (filters.range != null)
        ('Período', '${_fmtDate(filters.range!.start)} a ${_fmtDate(filters.range!.end)}'),
      if (filters.eventType != null)
        ('Tipo de evento', filters.eventType!.label),
      if (filters.regionId != null)
        ('Região', geo.regionName(filters.regionId!) ?? filters.regionId!),
      if (filters.areaId != null)
        ('Área', geo.areaName(filters.areaId!) ?? filters.areaId!),
      if (filters.poloId != null)
        ('Polo', geo.poloName(filters.poloId!) ?? filters.poloId!),
      ('Registros', filters.onlyWithRecords ? 'Somente membros com registros' : 'Todos os membros'),
      if (profile != null)
        ('Emitido por', '${profile!.displayName} (${_roleLabel(profile!.role)})'),
    ];

    final headerReh = [
      'Data', 'Hora', 'Tipo', 'Local / Escopo',
      'Pres.', 'Falt.', 'Just.', '% Pres.',
    ];
    final rowsReh = s.byRehearsal.map((it) {
      final r = it.rehearsal;
      final loc = geo.locationLabel(r);
      return [
        _fmtDate(r.dateTime),
        _fmtTime(r.dateTime),
        r.eventType.label,
        '${r.place ?? '—'} • $loc',
        '${it.present}',
        '${it.unjustified}',
        '${it.justified}',
        _pct(it.attendanceRate),
      ];
    }).toList();

    final headerPer = ['Membros', 'Pres.', 'Falta', 'Just.', '% Pres.'];
    final rowsPer = s.byPerson.map((it) => [
      _abbreviateBrazilianName(it.person.fullName),
      '${it.present}',
      '${it.unjustified}',
      '${it.justified}',
      _pct(it.attendanceRate),
    ]).toList();

    return [
      _coverCard(metaRows),
      pw.SizedBox(height: 12),
      _sectionTitle('Visão Geral', 'Indicadores consolidados do período'),
      pw.SizedBox(height: 6),
      _kpiRow([
        _kpi('Eventos totais', '${s.totalRehearsals}', _PdfPalette.primary),
        _kpi('Presentes', _pct(s.attendanceRate), _PdfPalette.success),
        _kpi('Justificadas', _pct(s.justificationRate), _PdfPalette.warning),
        _kpi('Membros c/ registro', '${s.peopleCovered}', _PdfPalette.accentPurple),
      ]),
      pw.SizedBox(height: 14),
      _sectionTitle('Por Evento', '${s.byRehearsal.length} evento(s) no período'),
      pw.SizedBox(height: 5),
      if (rowsReh.isEmpty)
        _emptyState('Nenhum evento encontrado para os filtros selecionados.')
      else
        _table(headerReh, rowsReh),
      pw.SizedBox(height: 14),
      _sectionTitle('Por Membro', '${s.byPerson.length} membro(s) listado(s)'),
      pw.SizedBox(height: 5),
      if (rowsPer.isEmpty)
        _emptyState('Nenhum membro encontrado para os filtros selecionados.')
      else
        _table(headerPer, rowsPer,
          zebra: true,
          maxLinesByColumn: const {0: 1},
          columnWidths: const {
            0: pw.FlexColumnWidth(5),
            1: pw.FixedColumnWidth(32),
            2: pw.FixedColumnWidth(32),
            3: pw.FixedColumnWidth(32),
            4: pw.FixedColumnWidth(72),
          },
          centerColumns: const {1, 2, 3, 4},
        ),
      if (eventReports.isNotEmpty) ...[
        pw.NewPage(),
        _sectionTitle(
          'Relatórios dos Eventos',
          '${eventReports.length} relatório(s) textual(is) do período',
        ),
        pw.SizedBox(height: 8),
        for (var i = 0; i < eventReports.length; i++) ...[
          if (i > 0) pw.SizedBox(height: 14),
          _eventReportBlock(eventReports[i].$1, eventReports[i].$2),
        ],
      ],
    ];
  }

  pw.Widget _coverCard(List<(String, String)> rows) {
    final split = (rows.length / 2).ceil();
    final left = rows.sublist(0, split);
    final right = rows.sublist(split);

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        color: _PdfPalette.bgLight,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _PdfPalette.border),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Resumo do Relatório',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: _PdfPalette.textDark,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Parâmetros e escopo utilizados na geração deste documento.',
            style: pw.TextStyle(fontSize: 8, color: _PdfPalette.textMuted),
          ),
          pw.SizedBox(height: 8),
          pw.Container(height: 1, color: _PdfPalette.border),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: _metaColumn(left)),
              pw.SizedBox(width: 12),
              pw.Expanded(child: _metaColumn(right.isEmpty ? const [] : right)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _metaColumn(List<(String, String)> rows) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: rows.map((row) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 72,
              child: pw.Text(
                row.$1,
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: _PdfPalette.primary,
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                row.$2,
                style: pw.TextStyle(fontSize: 8, color: _PdfPalette.textDark),
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  pw.Widget _sectionTitle(String title, String subtitle) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 3,
          height: 24,
          decoration: pw.BoxDecoration(
            color: _PdfPalette.primary,
            borderRadius: pw.BorderRadius.circular(2),
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: _PdfPalette.textDark,
                ),
              ),
              pw.Text(
                subtitle,
                style: pw.TextStyle(fontSize: 7, color: _PdfPalette.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _kpi(String title, String value, PdfColor accent) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: _PdfPalette.border),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 20,
              height: 2,
              decoration: pw.BoxDecoration(
                color: accent,
                borderRadius: pw.BorderRadius.circular(2),
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              title,
              style: pw.TextStyle(fontSize: 7, color: _PdfPalette.textMuted),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: _PdfPalette.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _kpiRow(List<pw.Widget> items) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) pw.SizedBox(width: 6),
          items[i],
        ],
      ],
    );
  }

  pw.Widget _table(
    List<String> header,
    List<List<String>> rows, {
    bool zebra = false,
    Map<int, int>? maxLinesByColumn,
    Map<int, pw.TableColumnWidth>? columnWidths,
    Set<int>? centerColumns,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: _PdfPalette.border, width: 0.3),
      columnWidths: columnWidths ?? const {
        0: pw.FlexColumnWidth(1),
        1: pw.FixedColumnWidth(30),
        2: pw.FlexColumnWidth(0.7),
        3: pw.FlexColumnWidth(2.2),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _PdfPalette.primary),
          children: header.asMap().entries.map((e) => _tableCell(
            e.value,
            bold: true,
            color: PdfColors.white,
            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
            maxLines: maxLinesByColumn?[e.key],
            align: centerColumns?.contains(e.key) == true
                ? pw.Alignment.center
                : pw.Alignment.centerLeft,
          )).toList(),
        ),
        ...rows.asMap().entries.map((entry) {
          final i = entry.key;
          final row = entry.value;
          return pw.TableRow(
            decoration: zebra && i.isOdd
                ? pw.BoxDecoration(color: _PdfPalette.rowAlt)
                : null,
            children: row.asMap().entries.map((cell) => _tableCell(
              cell.value,
              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              maxLines: maxLinesByColumn?[cell.key],
              align: centerColumns?.contains(cell.key) == true
                  ? pw.Alignment.center
                  : pw.Alignment.centerLeft,
            )).toList(),
          );
        }),
      ],
    );
  }

  pw.Widget _tableCell(
    String text, {
    bool bold = false,
    PdfColor? color,
    pw.EdgeInsets padding = pw.EdgeInsets.zero,
    int? maxLines,
    pw.Alignment align = pw.Alignment.centerLeft,
  }) {
    final textColor = color ?? _PdfPalette.textDark;
    return pw.Padding(
      padding: padding,
      child: pw.Align(
        alignment: align,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: textColor,
          ),
          maxLines: maxLines ?? 3,
          overflow: pw.TextOverflow.clip,
          textAlign: align == pw.Alignment.center ? pw.TextAlign.center : pw.TextAlign.left,
        ),
      ),
    );
  }

  pw.Widget _emptyState(String message) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        color: _PdfPalette.bgLight,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _PdfPalette.border),
      ),
      child: pw.Text(
        message,
        style: pw.TextStyle(fontSize: 9, color: _PdfPalette.textMuted),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _eventReportBlock(Rehearsal event, EventReport report) {
    final place = [
      if ((event.place ?? '').trim().isNotEmpty) event.place!.trim(),
      geo.levelName(event),
    ].join(' • ');
    final title = report.title.trim().isEmpty ? event.displayTitle : report.title.trim();
    final updated =
        'Última atualização em ${_fmtDate(report.updatedAt)} às ${_fmtTime(report.updatedAt)}'
        '${(report.updatedByName ?? '').trim().isNotEmpty ? ' por ${report.updatedByName!.trim()}' : ''}';

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _PdfPalette.border),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: _PdfPalette.textDark,
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Text(
                report.status.label,
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: report.status == EventReportStatus.finalized
                      ? _PdfPalette.success
                      : _PdfPalette.warning,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '${event.eventType.label}  •  ${_fmtDate(event.dateTime)}  •  ${_fmtTime(event.dateTime)}',
            style: pw.TextStyle(fontSize: 8, color: _PdfPalette.textMuted),
          ),
          pw.Text(
            place,
            style: pw.TextStyle(fontSize: 8, color: _PdfPalette.textMuted),
          ),
          if ((report.responsible ?? '').trim().isNotEmpty) ...[
            pw.SizedBox(height: 4),
            _pdfMeta('Responsáveis', report.responsible!.trim()),
          ],
          if (report.overview.trim().isNotEmpty) ...[
            pw.SizedBox(height: 10),
            _pdfHeading('1. Panorama Geral'),
            pw.SizedBox(height: 4),
            _pdfBody(report.overview.trim()),
          ],
          if (report.conclusion.trim().isNotEmpty) ...[
            pw.SizedBox(height: 10),
            _pdfHeading('2. Conclusão'),
            pw.SizedBox(height: 4),
            _pdfBody(report.conclusion.trim()),
          ],
          if ((report.notes ?? '').trim().isNotEmpty) ...[
            pw.SizedBox(height: 10),
            _pdfHeading('Observações'),
            pw.SizedBox(height: 4),
            _pdfBody(report.notes!.trim()),
          ],
          pw.SizedBox(height: 8),
          pw.Text(
            updated,
            style: pw.TextStyle(fontSize: 7, color: _PdfPalette.textMuted),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfHeading(String text) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
        color: _PdfPalette.primary,
      ),
    );
  }

  pw.Widget _pdfBody(String text) {
    return pw.Text(
      text,
      style: pw.TextStyle(fontSize: 9, color: _PdfPalette.textDark, lineSpacing: 2),
    );
  }

  pw.Widget _pdfMeta(String label, String value) {
    return pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$label: ',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: _PdfPalette.textDark,
            ),
          ),
          pw.TextSpan(
            text: value,
            style: pw.TextStyle(fontSize: 8, color: _PdfPalette.textMuted),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Formatação
  // ---------------------------------------------------------------------------

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

  static const Set<String> _prepositions = {
    'de', 'da', 'do', 'das', 'dos', 'e',
  };

  /// Mesma regra da lista de membros: abrevia nomes do meio.
  static String _abbreviateBrazilianName(String fullName) {
    final raw = fullName.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (raw.isEmpty) return raw;

    final parts = raw.split(' ').where((w) => w.isNotEmpty).toList();
    if (parts.length <= 2) return raw;

    final first = _abbrFirst(parts.first.trim());
    final last = parts.last.trim();

    final middle = parts.sublist(1, parts.length - 1).map((w) {
      final word = w.trim();
      final lower = word.toLowerCase();
      if (_prepositions.contains(lower)) return word;
      if (word.isEmpty) return word;
      return '${word[0]}.';
    }).toList();

    return ([first, ...middle, last].join(' ')).replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _abbrFirst(String w) {
    final lower = w.toLowerCase();
    if (lower == 'maria') return 'Mª';
    if (lower == 'ana') return 'Aª';
    return w;
  }

  static String _roleLabel(UserRole r) => switch (r) {
    UserRole.admin => 'Administrador',
    UserRole.maanaim => 'Maanaim',
    UserRole.region => 'Região',
    UserRole.area => 'Área',
    UserRole.polo => 'Polo',
    UserRole.readonly => 'Somente leitura',
  };
}
