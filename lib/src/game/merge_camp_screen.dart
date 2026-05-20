import 'package:flutter/material.dart';
import 'dart:async';

import 'feedback_fx.dart';
import 'merge_camp_controller.dart';

class MergeCampScreen extends StatefulWidget {
  const MergeCampScreen({super.key});

  @override
  State<MergeCampScreen> createState() => _MergeCampScreenState();
}

class _MergeCampScreenState extends State<MergeCampScreen> {
  late final MergeCampController _controller;
  late final FeedbackFx _feedback;

  @override
  void initState() {
    super.initState();
    _feedback = FeedbackFx();
    unawaited(_feedback.initialize());
    _controller = MergeCampController()..addListener(_onChanged);
  }

  @override
  void dispose() {
    unawaited(_feedback.dispose());
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handlePlacement(int index) async {
    final result = _controller.place(index);
    switch (result.action) {
      case MergeAction.placed:
        await _feedback.tap();
      case MergeAction.merged:
        await _feedback.merge();
      case MergeAction.blocked:
      case MergeAction.gameOver:
        await _feedback.warning();
    }
  }

  @override
  Widget build(BuildContext context) {
    final board = _controller.board;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MergeCamp'),
        actions: [
          TextButton(
            onPressed: _controller.restart,
            child: const Text('Restart'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _StatsHeader(controller: _controller),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  itemCount: board.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemBuilder: (context, index) {
                    final tier = board[index];
                    return GestureDetector(
                      onTap: () => _handlePlacement(index),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: tier == null
                              ? const Color(0xFF243329)
                              : _tileColor(tier),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFF92DE7D),
                            width: tier == null ? 1 : 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            tier == null ? '+' : 'T$tier',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: tier == null
                                  ? const Color(0xFF7B9381)
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _controller.isGameOver
                    ? 'Board jammed. Restart for another run.'
                    : 'Build groups of 3 or more matching tiles to merge.',
                style: const TextStyle(
                  color: Color(0xFFD8E4D9),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_controller.isGameOver) ...[
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _controller.restart,
                  child: const Text('Restart Run'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _tileColor(int tier) {
    const palette = [
      Color(0xFFB4E197),
      Color(0xFF7DCF7B),
      Color(0xFFF4D06F),
      Color(0xFFF29E4C),
      Color(0xFFD96C75),
      Color(0xFFA275D1),
    ];
    return palette[(tier - 1).clamp(0, palette.length - 1)];
  }
}

class _StatsHeader extends StatelessWidget {
  const _StatsHeader({required this.controller});

  final MergeCampController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _StatCard(label: 'Score', value: '${controller.score}'),
            const SizedBox(width: 12),
            _StatCard(label: 'Moves', value: '${controller.placements}'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _BannerCard(
                title: 'Next Tile',
                value: 'T${controller.nextTier}',
                subtitle: 'Tier cap ${controller.currentTierCap}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BannerCard(
                title: 'Peak Merge',
                value: 'T${controller.highestTier}',
                subtitle: 'Pressure ${controller.pressureLabel}',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1B2B22),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFFA6BBA8))),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF314E39), Color(0xFF1C3225)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFFC7DCC9))),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Color(0xFFAAC1AC))),
        ],
      ),
    );
  }
}
