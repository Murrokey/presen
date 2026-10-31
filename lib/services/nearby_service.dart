import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../models/attendance_session.dart';

class NearbyService extends ChangeNotifier {
  final Strategy strategy = Strategy.P2P_STAR;
  final String myDeviceId = Random().nextInt(100000000).toString();
  final String universalServiceId = 'com.presen.app.universal';

  bool isAdvertising = false;
  bool isDiscovering = false;

  String myName = '';
  String savedCourse = '';
  bool attendanceConfirmed = false;
  bool attendanceCanceled = false;
  String confirmedClassName = '';

  List<PendingClass> pendingClasses = [];
  bool get pendingConfirmation => pendingClasses.isNotEmpty;

  List<StudentData> presentStudents = [];
  String errorMessage = '';

  Future<bool> checkPermissions() async {
    errorMessage = '';

    int sdkInt = 0;
    if (Platform.isAndroid) {
      try {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        sdkInt = androidInfo.version.sdkInt;
      } catch (e) {
        if (kDebugMode) print('Error obteniendo version de Android: $e');
      }
    }

    List<Permission> permissionsToAsk = [Permission.location];

    if (sdkInt >= 31) {
      permissionsToAsk.addAll([
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
      ]);
    } else {
      permissionsToAsk.add(Permission.bluetooth);
    }

    if (sdkInt >= 33) {
      permissionsToAsk.add(Permission.nearbyWifiDevices);
    }

    bool allGranted = true;
    bool needsSettings = false;

    for (var perm in permissionsToAsk) {
      PermissionStatus status = await perm.request();
      if (!status.isGranted) {
        allGranted = false;
        errorMessage += '${perm.toString().split('.').last} denegado.\n';
        if (status.isPermanentlyDenied) {
          needsSettings = true;
        }
      }
    }

    if (allGranted) {
      ServiceStatus serviceStatus = await Permission.location.serviceStatus;
      if (serviceStatus != ServiceStatus.enabled) {
        allGranted = false;
        errorMessage = 'Debes encender la Ubicación (GPS).\n';
      }
    }

    if (!allGranted) {
      if (needsSettings) {
        errorMessage +=
            'Ve a Configuración de la app y otorga los permisos manualmente.';
        await openAppSettings();
      } else {
        errorMessage += 'Por favor, intenta nuevamente y acepta los permisos.';
      }
      notifyListeners();
    }

    return allGranted;
  }

  Future<void> startAdvertising(String name, String course) async {
    bool hasPermissions = await checkPermissions();
    if (!hasPermissions) return;

    myName = name;
    savedCourse = course;

    attendanceConfirmed = false;
    attendanceCanceled = false;
    confirmedClassName = '';
    pendingClasses.clear();

    try {
      bool a = await Nearby().startAdvertising(
        myName,
        strategy,
        onConnectionInitiated: (String id, ConnectionInfo info) async {
          await Nearby().acceptConnection(
            id,
            onPayLoadRecieved: (endId, payload) {
              if (payload.type == PayloadType.BYTES) {
                String str = String.fromCharCodes(payload.bytes!);

                if (str.startsWith('CANC|')) {
                  attendanceConfirmed = false;
                  attendanceCanceled = true;
                  notifyListeners();
                } else if (str.startsWith('REQ|')) {
                  final parts = str.split('|');
                  if (parts.length >= 5) {
                    String tFirstName = parts[1];
                    String tLastName = parts[2];
                    String cCourse = parts[3];
                    String cSubject = parts[4];

                    if (savedCourse.isEmpty) {
                      if (!pendingClasses.any((p) => p.endpointId == endId)) {
                        pendingClasses.add(
                          PendingClass(
                            teacherName: '$tFirstName $tLastName',
                            course: cCourse,
                            subject: cSubject,
                            endpointId: endId,
                          ),
                        );
                        notifyListeners();
                      }
                    } else if (savedCourse == cCourse) {
                      confirmedClassName = '$cCourse ($cSubject)';
                      attendanceConfirmed = true;
                      Nearby().sendBytesPayload(
                        endId,
                        Uint8List.fromList('ACK|$myName|$myDeviceId'.codeUnits),
                      );
                      notifyListeners();
                    } else {
                      Nearby().disconnectFromEndpoint(endId);
                    }
                  }
                }
              }
            },
          );
        },
        onConnectionResult: (String id, Status status) {},
        onDisconnected: (String id) {
          int initialLength = pendingClasses.length;
          pendingClasses.removeWhere((p) => p.endpointId == id);
          if (pendingClasses.length != initialLength) {
            notifyListeners();
          }
        },
        serviceId: universalServiceId,
      );
      isAdvertising = a;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error iniciando advertising: $e');
    }
  }

  void replyToAttendance(
    String endpointId,
    bool accept, {
    String? course,
    String? subject,
  }) {
    if (accept && course != null && subject != null) {
      savedCourse = course;
      confirmedClassName = '$course ($subject)';
      attendanceConfirmed = true;
      Nearby().sendBytesPayload(
        endpointId,
        Uint8List.fromList('ACK|$myName|$myDeviceId'.codeUnits),
      );

      for (var p in pendingClasses) {
        if (p.endpointId != endpointId) {
          Nearby().disconnectFromEndpoint(p.endpointId);
        }
      }
      pendingClasses.clear();
    } else {
      pendingClasses.removeWhere((p) => p.endpointId == endpointId);
      Nearby().disconnectFromEndpoint(endpointId);
    }
    notifyListeners();
  }

  Future<void> stopAdvertising() async {
    await Nearby().stopAdvertising();
    await Nearby().stopAllEndpoints();
    isAdvertising = false;
    attendanceConfirmed = false;
    attendanceCanceled = false;
    pendingClasses.clear();
    notifyListeners();
  }

  Future<void> startDiscovering({
    required String teacherFirstName,
    required String teacherLastName,
    required String course,
    required String subject,
  }) async {
    bool hasPermissions = await checkPermissions();
    if (!hasPermissions) return;

    presentStudents.clear();

    try {
      bool a = await Nearby().startDiscovery(
        'Profesor',
        strategy,
        onEndpointFound: (String id, String endpointName, String serviceId) async {
          await Nearby().requestConnection(
            'Profesor',
            id,
            onConnectionInitiated: (String id, ConnectionInfo info) async {
              await Nearby().acceptConnection(
                id,
                onPayLoadRecieved: (endId, payload) {
                  if (payload.type == PayloadType.BYTES) {
                    String str = String.fromCharCodes(payload.bytes!);

                    if (str.startsWith('ACK|')) {
                      List<String> parts = str.split('|');
                      if (parts.length >= 2) {
                        String studentName = parts[1];
                        String deviceId = parts.length > 2 ? parts[2] : endId;

                        if (!presentStudents.any((s) => s.id == deviceId)) {
                          presentStudents.add(
                            StudentData(
                              id: deviceId,
                              endpointId: endId,
                              name: studentName,
                              isPresent: true,
                            ),
                          );
                          notifyListeners();
                        }
                      }
                    }
                  }
                },
              );
            },
            onConnectionResult: (String id, Status status) {
              if (status == Status.CONNECTED) {
                Nearby().sendBytesPayload(
                  id,
                  Uint8List.fromList(
                    'REQ|$teacherFirstName|$teacherLastName|$course|$subject'
                        .codeUnits,
                  ),
                );
              }
            },
            onDisconnected: (String id) {},
          );
        },
        onEndpointLost: (String? id) {},
        serviceId: universalServiceId,
      );
      isDiscovering = a;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error iniciando discovery: $e');
    }
  }

  void addStudentManually(String name) {
    final fakeId = 'manual_${DateTime.now().millisecondsSinceEpoch}';
    presentStudents.add(
      StudentData(id: fakeId, endpointId: fakeId, name: name, isPresent: true),
    );
    notifyListeners();
  }

  Future<void> stopDiscovering() async {
    try {
      await Nearby().stopDiscovery();
      await Nearby().stopAllEndpoints();
      isDiscovering = false;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error deteniendo discovery: $e');
    }
  }

  Future<void> cancelDiscovery() async {
    try {
      for (var student in presentStudents) {
        if (!student.id.startsWith('manual_')) {
          Nearby().sendBytesPayload(
            student.endpointId,
            Uint8List.fromList('CANC|'.codeUnits),
          );
        }
      }

      await Future.delayed(const Duration(milliseconds: 500));

      await Nearby().stopDiscovery();
      await Nearby().stopAllEndpoints();
      isDiscovering = false;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error cancelando discovery: $e');
    }
  }
}
