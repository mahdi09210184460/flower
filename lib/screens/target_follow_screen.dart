import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/account_provider.dart';
import '../services/automation_queue_service.dart';

class TargetFollowScreen extends StatefulWidget {
  const TargetFollowScreen({super.key});

  @override
  State<TargetFollowScreen> createState() => _TargetFollowScreenState();
}

class _TargetFollowScreenState extends State<TargetFollowScreen> {
  final TextEditingController _targetController = TextEditingController();
  double _minDelay = 30;
  double _maxDelay = 90;

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountProvider = Provider.of<AccountProvider>(context);
    final queueService = Provider.of<AutomationQueueService>(context);
    final progress = queueService.progress;

    return Scaffold(
      appBar: AppBar(
        title: const Text('فالو پیج هدف'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Target Input Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'آیدی پیج هدف را وارد کنید:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _targetController,
                      decoration: const InputDecoration(
                        hintText: 'مثلاً cristiano یا @cristiano',
                        prefixIcon: Icon(Icons.alternate_email),
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      enabled: !queueService.isRunning,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Progress Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('اکانت‌های فعال آماده عملیات:'),
                        Text(
                          '${accountProvider.activeAccountsCount} اکانت',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Text(
                      progress.currentActionMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: progress.isRunning ? Colors.blue : Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: progress.percentage,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('انجام شده: ${progress.completedTasks}'),
                        Text('ناموفق: ${progress.failedTasks}'),
                        Text('کل: ${progress.totalTasks}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Delay Settings Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('تنظیم تاخیر تصادفی بین هر فالو (ثانیه):'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('حداقل: ${_minDelay.round()}s'),
                        Expanded(
                          child: Slider(
                            value: _minDelay,
                            min: 5,
                            max: 120,
                            divisions: 23,
                            onChanged: queueService.isRunning
                                ? null
                                : (val) {
                                    setState(() {
                                      _minDelay = val;
                                      if (_maxDelay < _minDelay) {
                                        _maxDelay = _minDelay;
                                      }
                                    });
                                  },
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text('حداکثر: ${_maxDelay.round()}s'),
                        Expanded(
                          child: Slider(
                            value: _maxDelay,
                            min: 10,
                            max: 300,
                            divisions: 29,
                            onChanged: queueService.isRunning
                                ? null
                                : (val) {
                                    setState(() {
                                      _maxDelay = val;
                                      if (_minDelay > _maxDelay) {
                                        _minDelay = _maxDelay;
                                      }
                                    });
                                  },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Start & Control Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor:
                          queueService.isRunning ? Colors.grey : Colors.deepOrange,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('شروع فالو همگانی پیج هدف'),
                    onPressed: queueService.isRunning
                        ? null
                        : () {
                            final target = _targetController.text.trim();
                            if (target.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('لطفا آیدی پیج هدف را وارد کنید.'),
                                ),
                              );
                              return;
                            }

                            queueService.startTargetFollow(
                              accounts: accountProvider.accounts,
                              targetUsername: target,
                              minDelaySec: _minDelay.round(),
                              maxDelaySec: _maxDelay.round(),
                              onAccountUpdated: (updated) {
                                accountProvider.addOrUpdateAccount(updated);
                              },
                            );
                          },
                  ),
                ),
                if (queueService.isRunning) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(queueService.isPaused
                        ? Icons.play_arrow
                        : Icons.pause),
                    color: Colors.orange,
                    tooltip: queueService.isPaused ? 'ادامه' : 'توقف موقت',
                    onPressed: () {
                      if (queueService.isPaused) {
                        queueService.resumeQueue();
                      } else {
                        queueService.pauseQueue();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.stop),
                    color: Colors.red,
                    tooltip: 'توقف کامل',
                    onPressed: () {
                      queueService.stopQueue();
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Live Console Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'کنسول لاگ زنده:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  label: const Text('پاکسازی لاگ'),
                  onPressed: () => queueService.clearLogs(),
                ),
              ],
            ),

            // Live Console View
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: queueService.logs.isEmpty
                  ? const Center(
                      child: Text(
                        'هیچ لاگی ثبت نشده است.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: queueService.logs.length,
                      itemBuilder: (context, index) {
                        final log = queueService.logs[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            log,
                            style: TextStyle(
                              color: log.contains('❌')
                                  ? Colors.redAccent
                                  : log.contains('✅')
                                      ? Colors.greenAccent
                                      : log.contains('⚠️')
                                          ? Colors.yellowAccent
                                          : Colors.white70,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
