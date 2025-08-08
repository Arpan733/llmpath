import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import '../widgets/title_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // AudioControls
  final _record = AudioRecorder();
  bool _isRecording = false;
  String? _filePath;

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();

    if (status != PermissionStatus.granted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Microphone permission denied')));
      return;
    }

    print("status $status");
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String path =
        '${appDocDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
    print("path: $path");
    await _record.start(const RecordConfig(), path: path);
    print("record: $_record");

    setState(() {
      _isRecording = true;
      _filePath = path;
    });
  }

  Future<void> _stopRecording() async {
    await _record.stop();
    setState(() {
      _isRecording = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Recording saved at $_filePath')));
  }

  void _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  // MapControls
  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  String? _errorMessage;

  final LatLng fallbackLocation = const LatLng(32.7333, -97.1133);

  @override
  void initState() {
    super.initState();
    determinePosition();
  }

  Future<void> determinePosition() async {
    setState(() {
      _errorMessage = null;
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

                  if (_errorMessage != null)
                    Positioned(
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
                    ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: determinePosition,
        tooltip: 'Refresh Location',
        child: const Icon(Icons.my_location),
      ),
      persistentFooterButtons: [
        FloatingActionButton(
          onPressed: _toggleRecording,
          tooltip: 'Record Audio',
          child: Icon(_isRecording ? Icons.stop : Icons.mic),
        ),
      ],
    );
  }
}
