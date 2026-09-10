import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../src.dart';

class AccessHubView extends StatelessWidget {
  const AccessHubView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Acessos', style: TextStyle(fontWeight: FontWeight.w700)),
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            dividerColor: Colors.transparent,
            tabs: [
              Tab(
                child: StreamBuilder<int>(
                  stream: context.read<IAccessRequestRepository>().watchPendingCount(),
                  initialData: 0,
                  builder: (_, snap) {
                    final n = snap.data ?? 0;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Solicitações'),
                        if (n > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$n',
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
              const Tab(text: 'Usuários'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            AccessRequestsView(),
            AdminUsersView(),
          ],
        ),
      ),
    );
  }
}
