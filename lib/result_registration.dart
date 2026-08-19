import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const _endpoint =
    'https://qbtooistzfwgtqopsdri.supabase.co/rest/v1/rpc/submit_result';
const _publishableKey = 'sb_publishable__-21S-4jK5dGPr5pGabA7Q_oD5-CKIX';

String normalizePlayerName(String value) {
  final clean = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (clean.isEmpty || clean.length > 20) throw const FormatException();
  return clean;
}

Map<String, Object> buildResultPayload({
  required String gameId,
  required String playerName,
  required String metric,
  required int value,
}) => {
  'p_game_id': gameId,
  'p_player_name': normalizePlayerName(playerName),
  'p_value': value,
  'p_metric': metric,
};

Future<void> offerResultRegistration(
  BuildContext context, {
  required String gameId,
  required String metric,
  required int value,
  required String displayValue,
}) async {
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('기록을 등록할까요?'),
      content: Text('이번 기록: $displayValue'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('아니요'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('등록'),
        ),
      ],
    ),
  );
  if (accepted != true || !context.mounted) return;

  final controller = TextEditingController();
  String? error;
  final name = await showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('이름 입력'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: '이름', errorText: error),
          onSubmitted: (value) {
            final clean = value.trim().replaceAll(RegExp(r'\s+'), ' ');
            if (clean.isEmpty) {
              setState(() => error = '이름을 입력해 주세요.');
            } else {
              Navigator.pop(context, clean);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final clean = controller.text.trim().replaceAll(
                RegExp(r'\s+'),
                ' ',
              );
              if (clean.isEmpty) {
                setState(() => error = '이름을 입력해 주세요.');
              } else {
                Navigator.pop(context, clean);
              }
            },
            child: const Text('등록'),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  if (name == null || !context.mounted) return;

  try {
    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'apikey': _publishableKey,
        'Authorization': 'Bearer $_publishableKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(
        buildResultPayload(
          gameId: gameId,
          playerName: name,
          metric: metric,
          value: value,
        ),
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}');
    }
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('기록을 등록했어요.')));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('기록을 등록하지 못했어요. 다시 시도해 주세요.')),
      );
    }
  }
}
