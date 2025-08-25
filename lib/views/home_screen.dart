import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../widgets/title_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // AudioControls
  bool isRecording = false;
  html.MediaRecorder? _mediaRecorder;
  html.MediaStream? _mediaStream;
  final List<html.Blob> _chunks = [];

  void toggleRecording() async {
    if (isRecording) {
      // Stop recording
      _mediaRecorder?.stop();
      _mediaStream?.getTracks().forEach((track) => track.stop());
      setState(() => isRecording = false);
    } else {
      // Start recording
      final stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'audio': true,
      });

      _mediaStream = stream;
      _chunks.clear();
      _mediaRecorder = html.MediaRecorder(stream);

      _mediaRecorder!.addEventListener('dataavailable', (event) {
        final blobEvent = event as html.BlobEvent;
        _chunks.add(blobEvent.data!);
      });

      _mediaRecorder!.addEventListener('stop', (event) async {
        final blob = html.Blob(_chunks, 'audio/webm');
        await sendAudio(blob);
      });

      _mediaRecorder!.start();
      setState(() => isRecording = true);
    }
  }

  Future<Uint8List> blobToBytes(html.Blob blob) {
    final completer = Completer<Uint8List>();
    final reader = html.FileReader();

    reader.readAsArrayBuffer(blob);

    reader.onLoad.listen((event) {
      final result = reader.result;
      if (result is Uint8List) {
        completer.complete(result);
      } else if (result is ByteBuffer) {
        completer.complete(result.asUint8List());
      } else {
        completer.completeError('Unexpected result type');
      }
    });

    reader.onError.listen((event) {
      completer.completeError(reader.error ?? 'Error reading blob');
    });

    return completer.future;
  }

  Future<void> sendAudio(html.Blob audioBlob) async {
    final uri = Uri.parse('http://127.0.0.1:7860/speech-to-text');
    final bytes = await blobToBytes(audioBlob);

    try {
      final request = http.MultipartRequest('POST', uri)
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: 'audio.webm',
            contentType: MediaType('audio', 'webm'),
          ),
        );

      final response = await request.send();

      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        print('Server response: $respStr');
        final data = jsonDecode(respStr);
        _handleServerResponse(data['polyline']['polyline']);
      } else {
        print('Upload failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error uploading audio: $e');
    }
  }

  void _handleServerResponse(List<dynamic> respStr) {
    List<dynamic> coords = respStr;

    List<LatLng> polylineCoords = coords
        .map((point) => LatLng(point[0], point[1]))
        .toList();

    _showPolyline(polylineCoords);
  }

  LatLngBounds _getBounds(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (LatLng point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  void _showPolyline(List<LatLng> points) {
    final polyline = Polyline(
      polylineId: PolylineId("route"),
      color: Colors.blue,
      width: 5,
      points: points,
    );

    setState(() {
      _polylines.clear();
      _polylines.add(polyline);
    });

    if (_mapController != null && points.isNotEmpty) {
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(_getBounds(points), 50));
    }
  }

  // both
  @override
  void initState() {
    super.initState();

    determinePosition();
  }

  // MapControls
  GoogleMapController? _mapController;
  final Set<Polyline> _polylines = {};
  LatLng? _currentLocation;
  String? _errorMessage;

  final LatLng fallbackLocation = const LatLng(32.7333, -97.1133);

  Future<void> determinePosition() async {
    setState(() {
      _errorMessage = null;
      _polylines.clear();
    });

    try {
      if (!kIsWeb) {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          setState(() {
            _errorMessage = 'Location services are disabled.';
            _currentLocation = fallbackLocation;
          });
          return;
        }
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = 'Location permission denied.';
            _currentLocation = fallbackLocation;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage =
              'Location permission permanently denied. Please enable it in settings.';
          _currentLocation = fallbackLocation;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition();

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _errorMessage = null;
      });

      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_currentLocation!, 16));
    } catch (e) {
      setState(() {
        // _errorMessage = 'Error getting location: $e';
        _currentLocation = fallbackLocation;
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_currentLocation != null) {
      _mapController!.moveCamera(CameraUpdate.newLatLngZoom(_currentLocation!, 16));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const TitleBar(),
      body: Center(
        child: _currentLocation == null
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  GoogleMap(
                    zoomControlsEnabled: false,
                    compassEnabled: false,
                    myLocationButtonEnabled: false,
                    onMapCreated: _onMapCreated,
                    initialCameraPosition: CameraPosition(
                      target: _currentLocation!,
                      zoom: 16,
                    ),
                    polylines: _polylines,
                    markers: {
                      Marker(
                        markerId: const MarkerId('current_location'),
                        position: _currentLocation!,
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueBlue,
                        ),
                      ),
                    },
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: FloatingActionButton(
                        onPressed: toggleRecording,
                        tooltip: 'Record Audio',
                        child: Icon(isRecording ? Icons.stop : Icons.mic),
                      ),
                    ),
                  ),
                  _errorMessage != null
                      ? Positioned(
                          bottom: 20,
                          left: 20,
                          right: 20,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            color: Colors.redAccent,
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : Container(),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: determinePosition,
        tooltip: 'Refresh Location',
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
