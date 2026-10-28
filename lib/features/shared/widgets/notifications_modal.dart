import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/notification_client.dart';
import '../screens/api_screens.dart';

class NotificationsButton extends StatelessWidget {
  const NotificationsButton({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: NotificationClient.instance,
    builder: (_, _) => IconButton(
      tooltip: 'Notificações',
      onPressed: () => showNotificationsModal(context),
      icon: Badge(
        isLabelVisible: NotificationClient.instance.unreadCount > 0,
        label: Text('${NotificationClient.instance.unreadCount}'),
        child: const Icon(Icons.notifications_none),
      ),
    ),
  );
}

void showNotificationsModal(BuildContext context) {
  final client = NotificationClient.instance;
  Future<void> refresh() async {
    try {
      await client.refresh();
    } catch (_) {}
  }

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SizedBox(
      height: MediaQuery.sizeOf(context).height * .7,
      child: ListenableBuilder(
        listenable: client,
        builder: (_, _) => Column(
          children: [
            ListTile(
              title: const Text('Notificações'),
              subtitle: client.hasLoaded
                  ? Text('${client.unreadCount} não lidas')
                  : const Text('Avisos de novas mensagens'),
              trailing: IconButton(
                tooltip: 'Atualizar notificações',
                icon: const Icon(Icons.refresh),
                onPressed: client.loading ? null : refresh,
              ),
            ),
            if (client.loading && client.items.isNotEmpty)
              const LinearProgressIndicator(),
            if (client.loadError != null && client.items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Text(
                  '${client.loadError} As mensagens já carregadas continuam abaixo.',
                  textAlign: TextAlign.center,
                ),
              ),
            if (!client.connected &&
                client.hasLoaded &&
                !client.loading &&
                client.loadError == null)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Os avisos em tempo real estão pausados. Você pode atualizar esta lista.',
                  textAlign: TextAlign.center,
                ),
              ),
            Expanded(
              child: client.items.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: client.loading
                            ? const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text('Carregando notificações…'),
                                ],
                              )
                            : client.loadError != null || !client.hasLoaded
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.notifications_none,
                                    size: 36,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    client.loadError ?? 'Não foi possível carregar suas notificações.',
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton(
                                    onPressed: refresh,
                                    child: const Text('Tentar novamente'),
                                  ),
                                ],
                              )
                            : const Text(
                                'Você ainda não recebeu avisos.',
                                textAlign: TextAlign.center,
                              ),
                      ),
                    )
                  : ListView(
                      children: client.items
                          .map(
                            (item) => ListTile(
                              leading: Icon(
                                item['is_read'] == true
                                    ? Icons.chat_bubble_outline
                                    : Icons.mark_chat_unread,
                                color: item['is_read'] == true
                                    ? Colors.grey
                                    : const Color(0xFFB88600),
                              ),
                              title: Text(item['sender_name'] as String),
                              subtitle: Text(
                                item['body'] as String,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                unawaited(
                                  client
                                      .markRead(item['id'] as int)
                                      .catchError((Object _) {}),
                                );
                                Navigator.pop(sheetContext);
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        item['kind'] == 'request_event'
                                        ? LiveRequestDetails(
                                            requestId:
                                                item['request_id'] as int,
                                          )
                                        : LiveChatScreen(
                                            requestId:
                                                item['request_id'] as int,
                                            title:
                                                item['sender_name'] as String,
                                          ),
                                  ),
                                );
                              },
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    ),
  );
  refresh();
}
