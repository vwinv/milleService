import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:milleservices/providers/userProvider.dart';
import 'package:milleservices/services/notificationService.dart';
import 'package:milleservices/services/sizeConfig.dart';
import 'package:milleservices/services/utilities.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  bool _loading = true;
  bool _notificationsEnabled = true;
  List<dynamic> _notifications = [];

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: Utilities().baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // 1) Charger la préférence locale
      _notificationsEnabled =
          await NotificationService.isSystemPermissionGranted();

      // 2) Charger la liste des notifications
      final userProvider = context.read<UserProvider>();
      final token = userProvider.token;
      if (token != null && token.isNotEmpty) {
        final res = await _dio.get(
          '/notifications',
          options: Options(
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            validateStatus: (status) => status != null && status < 500,
          ),
        );
        final raw = res.data;
        if (res.statusCode == 200) {
          _notifications = raw is Map && raw['data'] is List
              ? List<dynamic>.from(raw['data'] as List)
              : (raw is List ? List<dynamic>.from(raw) : <dynamic>[]);
          // Marquer toutes les notifications comme lues côté backend
          await _markAllAsRead(token);
        } else {
          Utilities().showMesage(
            context,
            'error',
            raw is Map && raw['message'] is String
                ? raw['message'] as String
                : 'notif_load_error'.tr(),
          );
        }
      }
    } catch (_) {
      Utilities().showMesage(
        context,
        'error',
        'notif_load_failed'.tr(),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _markAllAsRead(String token) async {
    try {
      await _dio.patch(
        '/notifications/mark-read',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );
    } catch (_) {
      // On ignore les erreurs ici pour ne pas casser l'affichage
    }
  }

  Future<void> _onToggleNotifications(bool value) async {
    await NotificationService().setNotificationsEnabledWithContext(
      context,
      value,
    );
    if (mounted) {
      setState(() {
        _notificationsEnabled = value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          'notif_title'.tr(),
          style: TextStyle(
            color: Colors.black,
            fontSize: SizeConfig.fontSize(SizeConfig.blockSizeHorizontal * 4),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      backgroundColor: Colors.white,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: SizeConfig.blockSizeHorizontal * 5,
                    vertical: SizeConfig.blockSizeVertical * 2,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'notif_enable'.tr(),
                          style: TextStyle(
                            fontSize: SizeConfig.fontSize(
                              SizeConfig.blockSizeHorizontal * 3.5,
                            ),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Switch(
                        value: _notificationsEnabled,
                        activeColor: Utilities().colorBlueDark,
                        onChanged: _onToggleNotifications,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _notifications.isEmpty
                      ? Center(
                          child: Text(
                            'notif_empty'.tr(),
                            style: TextStyle(
                              color: Utilities().colorGreyDark,
                              fontSize: SizeConfig.fontSize(
                                SizeConfig.blockSizeHorizontal * 3.5,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.symmetric(
                            horizontal: SizeConfig.blockSizeHorizontal * 5,
                            vertical: SizeConfig.blockSizeVertical * 2,
                          ),
                          itemBuilder: (context, index) {
                            final n = _notifications[index];
                            final title = n is Map && n['title'] != null
                                ? n['title'].toString()
                                : '';
                            final body = n is Map && n['body'] != null
                                ? n['body'].toString()
                                : '';
                            final createdAt = n is Map && n['createdAt'] != null
                                ? DateTime.tryParse(
                                    n['createdAt'].toString(),
                                  )
                                : null;
                            final dateLabel = createdAt != null
                                ? '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}'
                                : '';
                            final isRead =
                                n is Map && n['lu'] == true;

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                title,
                                style: TextStyle(
                                  fontWeight: isRead
                                      ? FontWeight.w400
                                      : FontWeight.w600,
                                  color: isRead
                                      ? Colors.black87
                                      : Colors.black,
                                  fontSize: SizeConfig.fontSize(
                                    SizeConfig.blockSizeHorizontal * 3.5,
                                  ),
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (body.isNotEmpty)
                                    Text(
                                      body,
                                      style: TextStyle(
                                        fontSize: SizeConfig.fontSize(
                                          SizeConfig.blockSizeHorizontal * 3.2,
                                        ),
                                        color: isRead
                                            ? Colors.black54
                                            : Colors.black87,
                                      ),
                                    ),
                                  if (dateLabel.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        dateLabel,
                                        style: TextStyle(
                                          color: Utilities().colorGreyDark,
                                          fontSize: SizeConfig.fontSize(
                                            SizeConfig.blockSizeHorizontal *
                                                2.8,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                          separatorBuilder: (_, __) => Divider(
                            height: SizeConfig.blockSizeVertical * 2,
                          ),
                          itemCount: _notifications.length,
                        ),
                ),
              ],
            ),
    );
  }
}

