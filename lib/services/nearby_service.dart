import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/attendance_session.dart';

class NearbyService extends ChangeNotifier {
  final Strategy strategy = Strategy.P2P_CLUSTER;
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

  final List<String> _connectionQueue = [];
  final Set<String> _processedEndpoints = {};
  final List<String> _activeStudentEndpoints = [];
  bool _isConnectingToEndpoint = false;

  String _activeTeacherFirst = '';
  String _activeTeacherLast = '';
  String _activeCourse = '';
  String _activeSubject = '';

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

    await Nearby().stopAdvertising();
    await Nearby().stopAllEndpoints();
    await Future.delayed(const Duration(milliseconds: 150));

    myName = name;
    savedCourse = course.trim();

    attendanceConfirmed = false;
    attendanceCanceled = false;
    confirmedClassName = '';
    pendingClasses.clear();

    try {
      final sessionToken = DateTime.now().millisecondsSinceEpoch % 10000;
      bool a = await Nearby().startAdvertising(
        '$myName#$sessionToken',
        strategy,
        onConnectionInitiated: (String id, ConnectionInfo info) async {
          await Nearby().acceptConnection(
            id,
            onPayLoadRecieved: (endId, payload) async {
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
                    String cCourse = parts[3].trim();
                    String cSubject = parts[4].trim();

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
                    } else if (savedCourse.toLowerCase() ==
                        cCourse.toLowerCase()) {
                      confirmedClassName = '$cCourse ($cSubject)';
                      attendanceConfirmed = true;
                      isAdvertising = false;
                      notifyListeners();

                      await Nearby().sendBytesPayload(
                        endId,
                        Uint8List.fromList('ACK|$myName|$myDeviceId'.codeUnits),
                      );
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
      isAdvertising = false;
      Nearby().sendBytesPayload(
        endpointId,
        Uint8List.fromList('ACK|$myName|$myDeviceId'.codeUnits),
      );
      Nearby().stopAdvertising();
      pendingClasses.clear();
    } else {
      pendingClasses.removeWhere((p) => p.endpointId == endpointId);
      Nearby().disconnectFromEndpoint(endpointId);
    }
    notifyListeners();
  }

  Future<void> stopAdvertising() async {
    await Nearby().stopDiscovery();
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

    await Nearby().stopDiscovery();
    await Nearby().stopAllEndpoints();
    await Future.delayed(const Duration(milliseconds: 150));

    presentStudents.clear();
    _connectionQueue.clear();
    _processedEndpoints.clear();
    _activeStudentEndpoints.clear();
    _isConnectingToEndpoint = false;

    _activeTeacherFirst = teacherFirstName;
    _activeTeacherLast = teacherLastName;
    _activeCourse = course.trim();
    _activeSubject = subject.trim();

    try {
      final sessionToken = DateTime.now().millisecondsSinceEpoch % 10000;
      bool a = await Nearby().startDiscovery(
        'Profesor#$sessionToken',
        strategy,
        onEndpointFound: (String id, String endpointName, String serviceId) {
          if (!_processedEndpoints.contains(id) &&
              !_connectionQueue.contains(id)) {
            _connectionQueue.add(id);
            _processNextInQueue();
          }
        },
        onEndpointLost: (String? id) {
          if (id != null) {
            _connectionQueue.remove(id);
          }
        },
        serviceId: universalServiceId,
      );
      isDiscovering = a;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error iniciando discovery: $e');
    }
  }

  Future<void> _processNextInQueue() async {
    if (_isConnectingToEndpoint || _connectionQueue.isEmpty || !isDiscovering) {
      return;
    }

    _isConnectingToEndpoint = true;
    final String targetId = _connectionQueue.removeAt(0);

    bool handled = false;
    void releaseAndContinue() {
      if (!handled) {
        handled = true;
        _isConnectingToEndpoint = false;
        _processNextInQueue();
      }
    }

    Future.delayed(const Duration(seconds: 4), () {
      if (!handled) {
        if (!_processedEndpoints.contains(targetId) &&
            !_connectionQueue.contains(targetId)) {
          _connectionQueue.add(targetId);
        }
        releaseAndContinue();
      }
    });

    try {
      final sessionToken = DateTime.now().millisecondsSinceEpoch % 10000;
      await Nearby().requestConnection(
        'Profesor#$sessionToken',
        targetId,
        onConnectionInitiated: (String id, ConnectionInfo info) async {
          await Nearby().acceptConnection(
            id,
            onPayLoadRecieved: (endId, payload) async {
              if (payload.type == PayloadType.BYTES) {
                String str = String.fromCharCodes(payload.bytes!);

                if (str.startsWith('ACK|')) {
                  List<String> parts = str.split('|');
                  if (parts.length >= 2) {
                    String studentName = parts[1];
                    String deviceId = parts.length > 2 ? parts[2] : endId;

                    _processedEndpoints.add(endId);
                    if (!_activeStudentEndpoints.contains(endId)) {
                      _activeStudentEndpoints.add(endId);
                    }

                    if (!presentStudents.any(
                      (s) =>
                          s.id == deviceId ||
                          s.name.toLowerCase() == studentName.toLowerCase(),
                    )) {
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

                    releaseAndContinue();
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
                'REQ|$_activeTeacherFirst|$_activeTeacherLast|$_activeCourse|$_activeSubject'
                    .codeUnits,
              ),
            );
          } else {
            releaseAndContinue();
          }
        },
        onDisconnected: (String id) {
          releaseAndContinue();
        },
      );
    } catch (_) {
      releaseAndContinue();
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
      _connectionQueue.clear();
      _processedEndpoints.clear();
      _activeStudentEndpoints.clear();
      _isConnectingToEndpoint = false;
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
      for (final endId in _activeStudentEndpoints) {
        try {
          await Nearby().sendBytesPayload(
            endId,
            Uint8List.fromList('CANC|'.codeUnits),
          );
        } catch (_) {}
      }

      await Future.delayed(const Duration(milliseconds: 300));

      _connectionQueue.clear();
      _processedEndpoints.clear();
      _activeStudentEndpoints.clear();
      _isConnectingToEndpoint = false;
      await Nearby().stopDiscovery();
      await Nearby().stopAllEndpoints();
      isDiscovering = false;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error cancelando discovery: $e');
    }
  }
}
